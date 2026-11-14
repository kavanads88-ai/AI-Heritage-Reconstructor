from fastapi import APIRouter, Depends, HTTPException, Request
from fastapi.responses import FileResponse

from ..config import DISCLAIMER_RECONSTRUCTION, Settings, get_settings
from ..schemas import ComparisonResponse
from ..services import monument_store as store

router = APIRouter(tags=["assets"])


@router.get(
    "/models/{monument_id}",
    summary="Download the GLB 3D model",
    response_class=FileResponse,
    responses={200: {"content": {"model/gltf-binary": {}}}, 404: {"description": "No model installed"}},
)
def get_model(monument_id: str, settings: Settings = Depends(get_settings)):
    monument = store.get_monument(settings, monument_id)
    model_file = monument.get("model_file")
    path = store.model_path(settings, model_file)
    if path is None:
        raise HTTPException(
            status_code=404,
            detail=(
                f"No 3D model is installed for {monument['name']} yet. "
                f"Place '{model_file or monument_id + '.glb'}' in backend/static/models/."
            ),
        )
    return FileResponse(path, media_type="model/gltf-binary", filename=path.name)


@router.get(
    "/comparison/{monument_id}",
    response_model=ComparisonResponse,
    summary="Present-day vs reconstruction images",
)
def get_comparison(monument_id: str, request: Request, settings: Settings = Depends(get_settings)):
    monument = store.get_monument(settings, monument_id)
    assets = store.describe_assets(settings, str(request.base_url), monument)
    has_recon = bool(assets["has_reconstruction_image"])
    explanation = monument.get("reconstruction_explanation") or (
        "No reconstruction explanation has been written for this monument yet."
    )
    if not has_recon:
        explanation = (
            "The reconstruction image for this monument has not been added yet, so no comparison "
            "can be shown. " + explanation
        )
    return ComparisonResponse(
        monument_id=monument_id,
        present_url=assets["present_image_url"],
        reconstruction_url=assets["reconstruction_image_url"],
        has_reconstruction=has_recon,
        explanation=explanation,
        disclaimer=DISCLAIMER_RECONSTRUCTION,
    )
