"""FastAPI dependencies (overridable in tests)."""
from __future__ import annotations

import threading
from typing import Optional

from fastapi import Depends

from .config import Settings, get_settings
from .services.classifier import MonumentClassifier

_lock = threading.Lock()
_cache: dict[tuple, MonumentClassifier] = {}


def get_classifier(settings: Settings = Depends(get_settings)) -> MonumentClassifier:
    """One classifier per (model path, labels path, threshold) - loaded lazily once."""
    key = (str(settings.model_path), str(settings.labels_path), settings.confidence_threshold, settings.input_size)
    with _lock:
        clf: Optional[MonumentClassifier] = _cache.get(key)
        if clf is None:
            clf = MonumentClassifier(
                settings.model_path,
                settings.labels_path,
                settings.confidence_threshold,
                settings.input_size,
            )
            _cache[key] = clf
    return clf
