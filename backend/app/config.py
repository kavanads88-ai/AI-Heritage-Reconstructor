"""Central, environment-driven configuration for the backend.

Every value can be overridden with an environment variable so the same code
runs on a laptop, in tests and (carefully) on a server.  Settings are read on
every call to ``get_settings`` which keeps tests simple (monkeypatch env, or
override the FastAPI dependency).
"""
from __future__ import annotations

import os
from dataclasses import dataclass
from pathlib import Path

BACKEND_DIR = Path(__file__).resolve().parent.parent
REPO_ROOT = BACKEND_DIR.parent

# Class names the training notebook produces.  The *order* is read from
# ai_models/class_names.json, never assumed.
OTHER_CLASS = "other"
MONUMENT_CLASSES = ("stone_chariot", "vittala_temple", "lotus_mahal")
UNKNOWN_NAME = "Unknown Monument"

DISCLAIMER_RECONSTRUCTION = (
    "Historically informed hypothetical visualisation — not an exact depiction of the original."
)
DISCLAIMER_DAMAGE = (
    "Possible damage indicators from image processing — not a structural assessment."
)


def _env_bool(name: str, default: bool) -> bool:
    raw = os.getenv(name)
    if raw is None:
        return default
    return raw.strip().lower() in {"1", "true", "yes", "on"}


def _env_float(name: str, default: float) -> float:
    try:
        return float(os.getenv(name, default))
    except ValueError:
        return default


def _env_int(name: str, default: int) -> int:
    try:
        return int(os.getenv(name, default))
    except ValueError:
        return default


@dataclass(frozen=True)
class Settings:
    data_file: Path
    static_dir: Path
    model_path: Path
    labels_path: Path
    confidence_threshold: float
    max_upload_bytes: int
    max_image_pixels: int
    allow_mock_identify: bool
    cors_origins: tuple[str, ...]
    input_size: int = 224


def get_settings() -> Settings:
    """Build settings from the environment (with safe local defaults)."""
    origins_raw = os.getenv(
        "HERITAGE_CORS_ORIGINS",
        # Browser-based dev tools (Swagger UI, Flutter web debug) only.  The
        # Android app does not use CORS at all.  Set to "*" explicitly if you
        # really want it open; see backend/README.md before doing so.
        "http://localhost,http://127.0.0.1,http://localhost:8000,http://127.0.0.1:8000",
    )
    origins = tuple(o.strip() for o in origins_raw.split(",") if o.strip())
    return Settings(
        data_file=Path(
            os.getenv("HERITAGE_DATA_FILE", REPO_ROOT / "historical_data" / "monuments.json")
        ),
        static_dir=Path(os.getenv("HERITAGE_STATIC_DIR", BACKEND_DIR / "static")),
        model_path=Path(
            os.getenv("HERITAGE_MODEL_PATH", BACKEND_DIR / "ai_models" / "monument_model.keras")
        ),
        labels_path=Path(
            os.getenv("HERITAGE_LABELS_PATH", BACKEND_DIR / "ai_models" / "class_names.json")
        ),
        confidence_threshold=_env_float("HERITAGE_CONFIDENCE_THRESHOLD", 0.60),
        max_upload_bytes=_env_int("HERITAGE_MAX_UPLOAD_MB", 8) * 1024 * 1024,
        max_image_pixels=_env_int("HERITAGE_MAX_IMAGE_MEGAPIXELS", 40) * 1_000_000,
        allow_mock_identify=_env_bool("HERITAGE_ALLOW_MOCK", True),
        cors_origins=origins,
    )
