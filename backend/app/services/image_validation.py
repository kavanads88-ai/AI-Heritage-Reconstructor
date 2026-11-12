"""Validation and decoding of uploaded images."""
from __future__ import annotations

import io
from dataclasses import dataclass

from fastapi import HTTPException, UploadFile
from PIL import Image, ImageOps, UnidentifiedImageError

ALLOWED_FORMATS = {"JPEG", "PNG", "WEBP"}


@dataclass
class ValidatedImage:
    image: Image.Image  # RGB, EXIF-rotated
    raw: bytes
    format: str


async def read_limited(upload: UploadFile, max_bytes: int) -> bytes:
    """Read an upload, refusing to buffer more than ``max_bytes``."""
    chunks: list[bytes] = []
    total = 0
    while True:
        chunk = await upload.read(1024 * 1024)
        if not chunk:
            break
        total += len(chunk)
        if total > max_bytes:
            raise HTTPException(
                status_code=413,
                detail=f"Image is too large. Maximum allowed size is {max_bytes // (1024 * 1024)} MB.",
            )
        chunks.append(chunk)
    return b"".join(chunks)


def decode_image(raw: bytes, max_pixels: int) -> ValidatedImage:
    """Validate bytes as a supported image and return an RGB PIL image."""
    if not raw:
        raise HTTPException(status_code=400, detail="The uploaded file is empty.")
    try:
        probe = Image.open(io.BytesIO(raw))
        fmt = (probe.format or "").upper()
        width, height = probe.size
    except (UnidentifiedImageError, OSError, ValueError):
        raise HTTPException(
            status_code=400, detail="The uploaded file is not a valid image."
        ) from None

    if fmt not in ALLOWED_FORMATS:
        raise HTTPException(
            status_code=415,
            detail=f"Unsupported image format '{fmt or 'unknown'}'. Use JPEG, PNG or WEBP.",
        )
    if width * height > max_pixels:
        raise HTTPException(
            status_code=400,
            detail="Image resolution is too large. Please use a smaller photograph.",
        )
    try:
        probe.verify()  # integrity check; invalidates the object
        image = Image.open(io.BytesIO(raw))
        image = ImageOps.exif_transpose(image).convert("RGB")
    except (UnidentifiedImageError, OSError, ValueError, SyntaxError):
        raise HTTPException(
            status_code=400, detail="The image file is corrupted and could not be read."
        ) from None
    return ValidatedImage(image=image, raw=raw, format=fmt)


async def validate_upload(upload: UploadFile, max_bytes: int, max_pixels: int) -> ValidatedImage:
    raw = await read_limited(upload, max_bytes)
    return decode_image(raw, max_pixels)
