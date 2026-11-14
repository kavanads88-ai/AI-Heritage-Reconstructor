"""Loads monument metadata from historical_data/monuments.json and resolves assets."""
from __future__ import annotations

import json
from pathlib import Path
from typing import Any, Optional

from fastapi import HTTPException

from ..config import Settings


def load_monuments(settings: Settings) -> list[dict[str, Any]]:
    path = settings.data_file
    if not path.exists():
        raise HTTPException(status_code=500, detail="Monument data file (monuments.json) was not found on the server.")
    try:
        with open(path, "r", encoding="utf-8") as f:
            data = json.load(f)
    except (OSError, json.JSONDecodeError):
        raise HTTPException(status_code=500, detail="Monument data file is unreadable or contains invalid JSON.") from None
    if not isinstance(data, list):
        raise HTTPException(status_code=500, detail="Monument data file has an unexpected structure.")
    return data


def get_monument(settings: Settings, monument_id: str) -> dict[str, Any]:
    for m in load_monuments(settings):
        if m.get("id") == monument_id:
            return m
    raise HTTPException(status_code=404, detail=f"Monument '{monument_id}' was not found.")


def _safe_file(base: Path, name: Optional[str]) -> Optional[Path]:
    """Return ``base/name`` only if it exists and stays inside ``base``."""
    if not name:
        return None
    try:
        base_resolved = base.resolve()
        candidate = (base / name).resolve()
        candidate.relative_to(base_resolved)
    except (ValueError, OSError):
        return None
    return candidate if candidate.is_file() else None


def image_path(settings: Settings, name: Optional[str]) -> Optional[Path]:
    return _safe_file(settings.static_dir / "images", name)


def model_path(settings: Settings, name: Optional[str]) -> Optional[Path]:
    return _safe_file(settings.static_dir / "models", name)


def image_url(settings: Settings, base_url: str, name: Optional[str]) -> Optional[str]:
    if image_path(settings, name) is None:
        return None
    return f"{base_url.rstrip('/')}/static/images/{name}"


def describe_assets(settings: Settings, base_url: str, monument: dict[str, Any]) -> dict[str, Any]:
    """Real, file-system-checked asset availability for one monument."""
    images = monument.get("images") or {}
    present = image_url(settings, base_url, images.get("present"))
    recon = image_url(settings, base_url, images.get("reconstruction"))
    thumb_name = images.get("thumbnail") or images.get("present")
    model_name = monument.get("model_file")
    has_model = model_path(settings, model_name) is not None
    return {
        "thumbnail_url": image_url(settings, base_url, thumb_name),
        "present_image_url": present,
        "reconstruction_image_url": recon,
        "has_present_image": present is not None,
        "has_reconstruction_image": recon is not None,
        "has_model": has_model,
        "model_url": f"{base_url.rstrip('/')}/models/{monument['id']}" if has_model else None,
    }
