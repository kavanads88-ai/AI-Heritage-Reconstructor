"""MobileNetV2 monument classifier (inference only).

Design notes
------------
* Classification logic lives here, never in the route handlers.
* TensorFlow is imported lazily, so the API still starts (and the other
  endpoints still work) if TensorFlow is not installed or the model file does
  not exist yet.  ``status`` explains exactly why the model is unavailable.
* Preprocessing: the training notebook builds the model with a
  ``Rescaling(1/127.5, offset=-1)`` layer *inside* the model.  The backend
  therefore feeds RAW 0-255 RGB pixels resized to 224x224 (bilinear).  Do not
  rescale here or you will double-scale.
"""
from __future__ import annotations

import json
import threading
from dataclasses import dataclass, field
from pathlib import Path
from typing import Callable, Optional, Sequence

import numpy as np
from PIL import Image

from ..config import OTHER_CLASS, UNKNOWN_NAME


@dataclass
class ClassificationResult:
    monument_id: Optional[str]
    name: str
    confidence: float
    is_unknown: bool
    top3: list[tuple[str, float]] = field(default_factory=list)


def preprocess(image: Image.Image, size: int = 224) -> np.ndarray:
    """RGB PIL image -> float32 batch (1, size, size, 3) with raw 0-255 values."""
    resized = image.convert("RGB").resize((size, size), Image.BILINEAR)
    arr = np.asarray(resized, dtype=np.float32)
    return arr[np.newaxis, ...]


def decide(
    probs: Sequence[float],
    labels: Sequence[str],
    threshold: float,
    names: Optional[dict[str, str]] = None,
) -> ClassificationResult:
    """Turn a probability vector into a result, applying the unknown rules."""
    probs_arr = np.asarray(probs, dtype=np.float64)
    if probs_arr.shape[0] != len(labels):
        raise ValueError(
            f"Model outputs {probs_arr.shape[0]} classes but class_names.json lists {len(labels)}."
        )
    order = np.argsort(-probs_arr)
    top3 = [(labels[i], float(probs_arr[i])) for i in order[:3]]
    best_id, best_conf = top3[0]
    unknown = best_id == OTHER_CLASS or best_conf < threshold
    if unknown:
        return ClassificationResult(None, UNKNOWN_NAME, best_conf, True, top3)
    name = (names or {}).get(best_id, best_id.replace("_", " ").title())
    return ClassificationResult(best_id, name, best_conf, False, top3)


class MonumentClassifier:
    """Lazy-loading wrapper around the trained Keras model."""

    def __init__(
        self,
        model_path: Path,
        labels_path: Path,
        threshold: float,
        input_size: int = 224,
        predict_fn: Optional[Callable[[np.ndarray], np.ndarray]] = None,
        labels: Optional[list[str]] = None,
    ) -> None:
        self.model_path = Path(model_path)
        self.labels_path = Path(labels_path)
        self.threshold = threshold
        self.input_size = input_size
        self._lock = threading.Lock()
        self._model = None
        self._predict_fn = predict_fn
        self._labels = labels
        self._status = "not_loaded"
        self._detail = "Model has not been loaded yet."
        self._attempted = predict_fn is not None and labels is not None
        if self._attempted:
            self._status, self._detail = "ready", "Injected predictor (tests)."

    # ------------------------------------------------------------------ status
    @property
    def status(self) -> str:
        self.load()
        return self._status

    @property
    def detail(self) -> str:
        self.load()
        return self._detail

    @property
    def is_available(self) -> bool:
        return self.status == "ready"

    # ----------------------------------------------------------------- loading
    def load(self) -> bool:
        """Try to load the model once.  Never raises."""
        if self._attempted:
            return self._status == "ready"
        with self._lock:
            if self._attempted:
                return self._status == "ready"
            self._attempted = True
            if not self.model_path.is_file():
                self._status = "model_missing"
                self._detail = f"No trained model found at {self.model_path}."
                return False
            if not self.labels_path.is_file():
                self._status = "labels_missing"
                self._detail = f"Class label file not found at {self.labels_path}."
                return False
            try:
                labels = json.loads(self.labels_path.read_text(encoding="utf-8"))
                if not isinstance(labels, list) or not all(isinstance(x, str) for x in labels):
                    raise ValueError("class_names.json must be a JSON list of strings")
            except (OSError, ValueError) as exc:
                self._status = "labels_invalid"
                self._detail = f"Could not read class labels: {exc}"
                return False
            try:
                import tensorflow as tf  # noqa: WPS433 (lazy import on purpose)
            except Exception as exc:  # ImportError or broken install
                self._status = "tensorflow_missing"
                self._detail = f"TensorFlow could not be imported: {exc}"
                return False
            try:
                self._model = tf.keras.models.load_model(str(self.model_path), compile=False)
                self._labels = labels
                self._predict_fn = lambda batch: self._model.predict(batch, verbose=0)[0]
                self._status, self._detail = "ready", "Model loaded."
                return True
            except Exception as exc:
                self._status = "load_failed"
                self._detail = f"Model file could not be loaded: {exc}"
                return False

    # --------------------------------------------------------------- inference
    def classify(self, image: Image.Image, names: Optional[dict[str, str]] = None) -> ClassificationResult:
        if not self.load() or self._predict_fn is None or self._labels is None:
            raise RuntimeError(self._detail)
        probs = self._predict_fn(preprocess(image, self.input_size))
        probs = np.asarray(probs).reshape(-1)
        return decide(probs, self._labels, self.threshold, names)
