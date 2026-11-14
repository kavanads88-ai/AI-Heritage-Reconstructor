import json

import numpy as np
import pytest
from PIL import Image

from app.services.classifier import MonumentClassifier, decide, preprocess

LABELS = ["lotus_mahal", "other", "stone_chariot", "vittala_temple"]


def test_preprocess_shape_and_raw_pixel_range():
    img = Image.new("RGB", (300, 120), (255, 0, 128))
    out = preprocess(img, 224)
    assert out.shape == (1, 224, 224, 3)
    assert out.dtype == np.float32
    assert out.max() <= 255 and out.min() >= 0  # raw pixels: scaling is inside the model
    assert tuple(out[0, 0, 0]) == (255.0, 0.0, 128.0)


def test_decide_top3_sorted_descending():
    res = decide([0.1, 0.05, 0.7, 0.15], LABELS, 0.6)
    assert [i for i, _ in res.top3] == ["stone_chariot", "vittala_temple", "lotus_mahal"]
    assert not res.is_unknown


def test_decide_threshold_boundary():
    assert decide([0, 0, 0.6, 0.4], LABELS, 0.6).is_unknown is False  # equal passes
    assert decide([0, 0, 0.59, 0.41], LABELS, 0.6).is_unknown is True


def test_missing_model_file_does_not_raise(tmp_path):
    clf = MonumentClassifier(tmp_path / "nope.keras", tmp_path / "labels.json", 0.6)
    assert clf.is_available is False
    assert clf.status == "model_missing"
    with pytest.raises(RuntimeError):
        clf.classify(Image.new("RGB", (8, 8)))


def test_missing_labels_file(tmp_path):
    (tmp_path / "m.keras").write_bytes(b"x")
    clf = MonumentClassifier(tmp_path / "m.keras", tmp_path / "labels.json", 0.6)
    assert clf.status == "labels_missing"


def test_invalid_labels_file(tmp_path):
    (tmp_path / "m.keras").write_bytes(b"x")
    (tmp_path / "labels.json").write_text(json.dumps({"not": "a list"}))
    clf = MonumentClassifier(tmp_path / "m.keras", tmp_path / "labels.json", 0.6)
    assert clf.status == "labels_invalid"


def test_corrupt_model_file_reports_failure_not_crash(tmp_path):
    (tmp_path / "m.keras").write_bytes(b"this is not a keras model")
    (tmp_path / "labels.json").write_text(json.dumps(LABELS))
    clf = MonumentClassifier(tmp_path / "m.keras", tmp_path / "labels.json", 0.6)
    assert clf.is_available is False
    assert clf.status in {"load_failed", "tensorflow_missing"}
