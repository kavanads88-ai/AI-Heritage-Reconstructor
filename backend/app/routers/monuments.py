from typing import Any

from fastapi import APIRouter, Depends, Request

from ..config import Settings, get_settings
from ..schemas import MonumentSummary
from ..services import monument_store as store

router = APIRouter(tags=["monuments"])


def _base(request: Request) -> str:
    return str(request.base_url).rstrip("/")


@router.get("/monuments", response_model=list[MonumentSummary], summary="List monuments")
def list_monuments(request: Request, settings: Settings = Depends(get_settings)):
    base = _base(request)
    out = []
    for m in store.load_monuments(settings):
        images = m.get("images") or {}
        thumb = images.get("thumbnail") or images.get("present")
        out.append(
            MonumentSummary(
                id=m["id"],
                name=m["name"],
                location=m.get("location", ""),
                thumbnail=store.image_url(settings, base, thumb),
            )
        )
    return out


@router.get("/monuments/{monument_id}", summary="Full monument record")
def monument_detail(monument_id: str, request: Request, settings: Settings = Depends(get_settings)) -> dict[str, Any]:
    monument = dict(store.get_monument(settings, monument_id))
    monument["assets"] = store.describe_assets(settings, _base(request), monument)
    return monument
