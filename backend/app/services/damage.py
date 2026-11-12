"""Basic OpenCV image processing that highlights POSSIBLE damage indicators.

This is a classical computer-vision heuristic, NOT a trained damage-detection
model and NOT a structural assessment.  It highlights crack-like, locally dark
edge structures.  Shadows, carvings, moss, joints between blocks and
vegetation will also be highlighted, and real damage may be missed.

Pipeline (all numbers are computed from the processed image):
  1. Resize so the longest side is <= 1024 px (speed, consistent parameters)
  2. Grayscale conversion
  3. Gaussian blur (noise reduction)
  4. Canny edge detection (thresholds derived from the median intensity)
  5. Adaptive thresholding to find locally dark pixels (crack-like shadows)
  6. Intersect edges with dark pixels, then morphological close + open
  7. Contour extraction; tiny contours are discarded
  8. ``damage_area_percent`` = filled pixels of kept contours / image pixels
"""
from __future__ import annotations

import base64
from dataclasses import dataclass, field

import cv2
import numpy as np
from PIL import Image

MAX_SIDE = 1024
MIN_REGION_FRACTION = 0.0004  # ignore regions smaller than 0.04 % of the image
MAX_REGIONS_REPORTED = 25
HIGHLIGHT_BGR = (59, 82, 181)  # terracotta #B5523B in BGR


@dataclass
class DamageAnalysis:
    annotated_jpeg: bytes
    damage_area_percent: float
    regions: list[dict] = field(default_factory=list)
    regions_found: int = 0
    width: int = 0
    height: int = 0


def _resize(bgr: np.ndarray) -> np.ndarray:
    h, w = bgr.shape[:2]
    scale = MAX_SIDE / max(h, w)
    if scale < 1.0:
        bgr = cv2.resize(bgr, (int(w * scale), int(h * scale)), interpolation=cv2.INTER_AREA)
    return bgr


def analyze(image: Image.Image) -> DamageAnalysis:
    rgb = np.asarray(image.convert("RGB"))
    bgr = _resize(cv2.cvtColor(rgb, cv2.COLOR_RGB2BGR))
    h, w = bgr.shape[:2]
    total_pixels = float(h * w)

    gray = cv2.cvtColor(bgr, cv2.COLOR_BGR2GRAY)
    blur = cv2.GaussianBlur(gray, (5, 5), 0)

    median = float(np.median(blur))
    lower = int(max(0, 0.66 * median))
    upper = int(min(255, 1.33 * median))
    if upper <= lower:  # e.g. an almost black or flat image
        lower, upper = 30, 90
    edges = cv2.Canny(blur, lower, upper)

    dark = cv2.adaptiveThreshold(
        blur, 255, cv2.ADAPTIVE_THRESH_GAUSSIAN_C, cv2.THRESH_BINARY_INV, 35, 10
    )
    dark = cv2.dilate(dark, cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (3, 3)))

    candidate = cv2.bitwise_and(edges, dark)
    kernel = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (5, 5))
    candidate = cv2.morphologyEx(candidate, cv2.MORPH_CLOSE, kernel, iterations=2)
    candidate = cv2.morphologyEx(candidate, cv2.MORPH_OPEN, cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (3, 3)))

    contours, _ = cv2.findContours(candidate, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
    min_area = MIN_REGION_FRACTION * total_pixels
    kept = [c for c in contours if cv2.contourArea(c) >= min_area]
    kept.sort(key=cv2.contourArea, reverse=True)

    mask = np.zeros((h, w), dtype=np.uint8)
    cv2.drawContours(mask, kept, -1, 255, thickness=cv2.FILLED)
    damage_percent = float(np.count_nonzero(mask)) / total_pixels * 100.0

    annotated = bgr.copy()
    overlay = annotated.copy()
    cv2.drawContours(overlay, kept, -1, HIGHLIGHT_BGR, thickness=cv2.FILLED)
    annotated = cv2.addWeighted(overlay, 0.35, annotated, 0.65, 0)
    cv2.drawContours(annotated, kept, -1, HIGHLIGHT_BGR, thickness=2)

    regions: list[dict] = []
    for c in kept[:MAX_REGIONS_REPORTED]:
        x, y, bw, bh = cv2.boundingRect(c)
        cv2.rectangle(annotated, (x, y), (x + bw, y + bh), (255, 255, 255), 1)
        regions.append(
            {
                "x": int(x),
                "y": int(y),
                "width": int(bw),
                "height": int(bh),
                "area_percent": round(cv2.contourArea(c) / total_pixels * 100.0, 3),
            }
        )

    ok, buf = cv2.imencode(".jpg", annotated, [int(cv2.IMWRITE_JPEG_QUALITY), 85])
    if not ok:
        raise RuntimeError("Could not encode the annotated image.")
    return DamageAnalysis(
        annotated_jpeg=buf.tobytes(),
        damage_area_percent=round(damage_percent, 2),
        regions=regions,
        regions_found=len(kept),
        width=w,
        height=h,
    )


def to_base64(jpeg: bytes) -> str:
    return base64.b64encode(jpeg).decode("ascii")


def summary_message(result: DamageAnalysis) -> str:
    if result.regions_found == 0:
        return (
            "No crack-like regions were highlighted by the image-processing filters. "
            "This does not mean the monument is undamaged."
        )
    return (
        f"{result.regions_found} possible region(s) highlighted, covering about "
        f"{result.damage_area_percent:.2f}% of the image. These are visual indicators only "
        "(shadows, carvings, joints and vegetation can also be highlighted). "
        "This is not a structural assessment."
    )
