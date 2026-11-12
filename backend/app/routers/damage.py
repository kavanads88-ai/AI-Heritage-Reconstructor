import asyncio

from fastapi import APIRouter, Depends, File, HTTPException, UploadFile

from ..config import DISCLAIMER_DAMAGE, Settings, get_settings
from ..schemas import DamageRegion, DamageResponse
from ..services import damage as damage_service
from ..services.image_validation import validate_upload

router = APIRouter(tags=["damage"])


@router.post(
    "/analyze-damage",
    response_model=DamageResponse,
    summary="Highlight possible damage indicators (OpenCV, not an AI model)",
)
async def analyze_damage(
    file: UploadFile = File(..., description="JPEG, PNG or WEBP photograph"),
    settings: Settings = Depends(get_settings),
) -> DamageResponse:
    img = await validate_upload(file, settings.max_upload_bytes, settings.max_image_pixels)
    try:
        result = await asyncio.to_thread(damage_service.analyze, img.image)
    except Exception as exc:
        raise HTTPException(status_code=500, detail=f"Image analysis failed: {exc}") from None
    return DamageResponse(
        annotated_image_base64=damage_service.to_base64(result.annotated_jpeg),
        damage_area_percent=result.damage_area_percent,
        regions_found=result.regions_found,
        message=damage_service.summary_message(result),
        disclaimer=DISCLAIMER_DAMAGE,
        regions=[DamageRegion(**r) for r in result.regions],
        image_width=result.width,
        image_height=result.height,
    )
