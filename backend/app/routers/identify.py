import hashlib

from fastapi import APIRouter, Depends, File, HTTPException, UploadFile

from ..config import MONUMENT_CLASSES, UNKNOWN_NAME, Settings, get_settings
from ..dependencies import get_classifier
from ..schemas import IdentifyResponse, Prediction
from ..services import monument_store as store
from ..services.classifier import MonumentClassifier
from ..services.image_validation import validate_upload

router = APIRouter(tags=["recognition"])

MOCK_NOTICE = (
    "MOCK DATA: no trained model is installed on the server, so this is NOT an AI prediction. "
    "Train the model in Google Colab and copy it to backend/ai_models/ (see README)."
)


@router.post(
    "/identify",
    response_model=IdentifyResponse,
    summary="Identify a monument from a photograph",
    responses={400: {"description": "Invalid image"}, 413: {"description": "Too large"},
               415: {"description": "Unsupported format"}, 503: {"description": "No model installed"}},
)
async def identify(
    file: UploadFile = File(..., description="JPEG, PNG or WEBP photograph"),
    settings: Settings = Depends(get_settings),
    classifier: MonumentClassifier = Depends(get_classifier),
) -> IdentifyResponse:
    img = await validate_upload(file, settings.max_upload_bytes, settings.max_image_pixels)

    if not classifier.is_available:
        if not settings.allow_mock_identify:
            raise HTTPException(
                status_code=503,
                detail=f"Recognition model is not available ({classifier.detail})",
            )
        return _mock_response(img.raw, settings)

    try:
        names = {m["id"]: m["name"] for m in store.load_monuments(settings)}
    except HTTPException:
        names = {}
    try:
        result = classifier.classify(img.image, names)
    except Exception as exc:  # model/inference failure must not crash the API
        raise HTTPException(status_code=500, detail=f"Recognition failed: {exc}") from None

    return IdentifyResponse(
        monument_id=result.monument_id,
        name=result.name,
        confidence=round(result.confidence, 4),
        is_unknown=result.is_unknown,
        top3=[Prediction(id=i, confidence=round(c, 4)) for i, c in result.top3],
        threshold=settings.confidence_threshold,
        is_mock=False,
        message=(
            f"Confidence is below the {settings.confidence_threshold:.0%} threshold or the image "
            "does not look like one of the supported monuments."
            if result.is_unknown else None
        ),
    )


def _mock_response(raw: bytes, settings: Settings) -> IdentifyResponse:
    """Clearly labelled development-mode placeholder.  Not a prediction."""
    digest = hashlib.sha256(raw).digest()
    idx = digest[0] % len(MONUMENT_CLASSES)
    monument_id = MONUMENT_CLASSES[idx]
    try:
        names = {m["id"]: m["name"] for m in store.load_monuments(settings)}
    except HTTPException:
        names = {}
    return IdentifyResponse(
        monument_id=monument_id,
        name=names.get(monument_id, monument_id.replace("_", " ").title()),
        confidence=None,
        is_unknown=False,
        top3=[],
        threshold=settings.confidence_threshold,
        is_mock=True,
        message=MOCK_NOTICE,
    )
