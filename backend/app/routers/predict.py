"""FastAPI router for /predict - handles MobileNetV2 recognition and OpenCV damage analysis."""
from __future__ import annotations

import base64
import hashlib
import json
from pathlib import Path
from typing import Any, Dict, List

import numpy as np
from fastapi import APIRouter, Depends, File, UploadFile
from PIL import Image

from ..config import MONUMENT_CLASSES, OTHER_CLASS, UNKNOWN_NAME, Settings, get_settings
from ..services import damage as damage_service
from ..services.image_validation import validate_upload

router = APIRouter(tags=["predict"])

_LOADED_MODEL = None
_MODEL_PATH_USED = None


def _get_model(backend_dir: Path) -> Any:
    """Lazy-loads stone_chariot_model.h5 or monument_model.keras if available."""
    global _LOADED_MODEL, _MODEL_PATH_USED
    candidates = [
        backend_dir / "stone_chariot_model.h5",
        backend_dir / "ai_models" / "stone_chariot_model.h5",
        backend_dir / "ai_models" / "monument_model.keras",
    ]
    model_path = next((p for p in candidates if p.is_file()), None)
    if not model_path:
        return None
    if _LOADED_MODEL is not None and _MODEL_PATH_USED == model_path:
        return _LOADED_MODEL

    try:
        import tensorflow as tf

        _LOADED_MODEL = tf.keras.models.load_model(str(model_path), compile=False)
        _MODEL_PATH_USED = model_path
        return _LOADED_MODEL
    except Exception:
        return None


def _get_class_names(backend_dir: Path) -> List[str]:
    """Gets class names matching TensorFlow's alphabetical folder sorting."""
    labels_file = backend_dir / "ai_models" / "class_names.json"
    if labels_file.is_file():
        try:
            labels = json.loads(labels_file.read_text(encoding="utf-8"))
            if isinstance(labels, list) and len(labels) > 0:
                return labels
        except Exception:
            pass
    # Alphabetical order matching Keras image_dataset_from_directory: ['other', 'stone_chariot']
    return ["other", "stone_chariot"]


@router.post(
    "/predict",
    summary="Predict monument class (MobileNetV2) and generate OpenCV damage indicators",
)
async def predict(
    file: UploadFile = File(..., description="Uploaded photograph of the monument"),
    settings: Settings = Depends(get_settings),
) -> Dict[str, Any]:
    # 1. Preprocess & Validate upload
    validated = await validate_upload(file, settings.max_upload_bytes, settings.max_image_pixels)
    pil_img = validated.image.convert("RGB")

    # 2. Model Inference
    backend_dir = settings.static_dir.parent
    model = _get_model(backend_dir)
    class_names = _get_class_names(backend_dir)

    if model is not None:
        try:
            # Resize image to 224x224
            resized = pil_img.resize((224, 224), Image.BILINEAR)
            img_array = np.asarray(resized, dtype=np.float32)

            # Rescale to [-1.0, 1.0] to match MobileNetV2 preprocessing pipeline
            img_array = (img_array / 127.5) - 1.0
            input_batch = np.expand_dims(img_array, axis=0)

            # Model inference
            predictions = model.predict(input_batch, verbose=0)[0]
            top_idx = int(np.argmax(predictions))
            raw_confidence = float(predictions[top_idx])
            raw_label = class_names[top_idx] if top_idx < len(class_names) else OTHER_CLASS
            is_mock = False

            # Debugging console output
            print("\n--- [PREDICT DEBUG] ---")
            print(f"File Name:          {file.filename}")
            print(f"Alphabetical Classes: {class_names}")
            print(f"Raw Probabilities:   {predictions.tolist()}")
            print(f"Predicted Index:     {top_idx} -> Label: '{raw_label}'")
            print(f"Confidence Score:    {raw_confidence:.4f} ({raw_confidence * 100:.2f}%)")
            print("-----------------------\n", flush=True)

        except Exception as exc:
            print(f"[PREDICT ERROR] Inference failed: {exc}", flush=True)
            raw_confidence, raw_label, is_mock = 0.88, "stone_chariot", True
    else:
        # Deterministic mock fallback if model is not loaded
        digest = hashlib.sha256(validated.raw).digest()
        idx = digest[0] % len(class_names)
        raw_confidence = 0.85 + (digest[1] % 12) / 100.0
        raw_label = class_names[idx]
        is_mock = True

        print("\n--- [PREDICT DEBUG (MOCK)] ---")
        print(f"File Name:          {file.filename}")
        print(f"Selected Mock Label: {raw_label}")
        print(f"Mock Confidence:     {raw_confidence:.4f}")
        print("------------------------------\n", flush=True)

    # 3. Fallback check: if confidence < 75% (0.75) or label is 'other', mark as Unknown Monument
    confidence_pct = round(raw_confidence * 100, 2)
    if raw_confidence < 0.75 or raw_label == OTHER_CLASS:
        predicted_label = UNKNOWN_NAME
        is_valid_monument = False
        is_unknown = True
    else:
        predicted_label = raw_label.replace("_", " ").title()
        is_valid_monument = True
        is_unknown = False

    # 4. OpenCV Damage Detection Pipeline
    damage_result = damage_service.analyze(pil_img)
    annotated_b64 = damage_service.to_base64(damage_result.annotated_jpeg)

    return {
        "status": "success",
        "prediction": predicted_label,
        "confidence": f"{confidence_pct}%",
        "confidence_score": round(raw_confidence, 4),
        "is_valid_monument": is_valid_monument,
        "predicted_label": predicted_label,
        "confidence_percentage": f"{confidence_pct}%",
        "is_unknown": is_unknown,
        "raw_class": raw_label,
        "is_mock": is_mock,
        "damage_analysis": {
            "damage_area_percent": damage_result.damage_area_percent,
            "regions_found": damage_result.regions_found,
            "annotated_image_base64": f"data:image/jpeg;base64,{annotated_b64}",
            "disclaimer": "Visual indicator only - not a structural engineering assessment.",
        },
    }
