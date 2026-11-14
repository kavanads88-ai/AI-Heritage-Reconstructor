import io
import json
import shutil
import sys
from pathlib import Path

import numpy as np
import pytest
from fastapi.testclient import TestClient
from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from app.config import Settings, get_settings  # noqa: E402
from app.dependencies import get_classifier  # noqa: E402
from app.main import create_app  # noqa: E402
from app.services.classifier import MonumentClassifier  # noqa: E402

REPO_ROOT = Path(__file__).resolve().parents[2]
LABELS = ["lotus_mahal", "other", "stone_chariot", "vittala_temple"]


def make_png(size=(64, 64), color=(200, 190, 170)) -> bytes:
    buf = io.BytesIO()
    Image.new("RGB", size, color).save(buf, format="PNG")
    return buf.getvalue()


def make_crack_image() -> bytes:
    """Light textured wall with a dark jagged crack - should trigger indicators."""
    rng = np.random.default_rng(0)
    arr = np.full((300, 400, 3), 200, dtype=np.uint8)
    arr = np.clip(arr + rng.integers(-6, 6, arr.shape), 0, 255).astype(np.uint8)
    pts = [(50, 20), (90, 90), (70, 150), (130, 210), (110, 280)]
    import cv2

    cv2.polylines(arr, [np.array(pts, dtype=np.int32)], False, (20, 20, 20), 6)
    buf = io.BytesIO()
    Image.fromarray(arr).save(buf, format="PNG")
    return buf.getvalue()


@pytest.fixture()
def tmp_settings(tmp_path) -> Settings:
    static = tmp_path / "static"
    (static / "images").mkdir(parents=True)
    (static / "models").mkdir(parents=True)
    return Settings(
        data_file=REPO_ROOT / "historical_data" / "monuments.json",
        static_dir=static,
        model_path=tmp_path / "missing_model.keras",
        labels_path=tmp_path / "missing_labels.json",
        confidence_threshold=0.60,
        max_upload_bytes=1 * 1024 * 1024,
        max_image_pixels=4_000_000,
        allow_mock_identify=True,
        cors_origins=("http://localhost",),
    )


@pytest.fixture()
def make_client(tmp_settings):
    def _make(settings=None, classifier=None):
        app = create_app()
        s = settings or tmp_settings
        app.dependency_overrides[get_settings] = lambda: s
        clf = classifier or MonumentClassifier(s.model_path, s.labels_path, s.confidence_threshold)
        app.dependency_overrides[get_classifier] = lambda: clf
        return TestClient(app, raise_server_exceptions=False)

    return _make


@pytest.fixture()
def client(make_client):
    return make_client()


def fake_classifier(probs, threshold=0.60):
    return MonumentClassifier(
        Path("unused"), Path("unused"), threshold,
        predict_fn=lambda batch: np.asarray(probs, dtype=np.float32), labels=LABELS,
    )


@pytest.fixture()
def png_bytes():
    return make_png()
