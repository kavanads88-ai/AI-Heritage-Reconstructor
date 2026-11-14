from fastapi import APIRouter, Depends, Request
from fastapi.responses import RedirectResponse

from ..config import Settings, get_settings
from ..dependencies import get_classifier
from ..schemas import HealthResponse
from ..services.classifier import MonumentClassifier

router = APIRouter(tags=["health"])


@router.get("/", response_model=HealthResponse, summary="Health check")
def health(
    request: Request,
    settings: Settings = Depends(get_settings),
    classifier: MonumentClassifier = Depends(get_classifier),
):
    accept = request.headers.get("accept", "")
    web_dir = settings.static_dir.parent.parent / "mobile_app" / "build" / "web"
    if "text/html" in accept and web_dir.exists():
        return RedirectResponse(url="/app/")

    return HealthResponse(
        status="ok",
        message="Heritage API is running",
        model_loaded=classifier.is_available,
        model_status=classifier.status,
        mock_identify_enabled=settings.allow_mock_identify and not classifier.is_available,
    )
