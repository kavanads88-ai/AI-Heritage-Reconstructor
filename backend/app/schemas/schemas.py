"""Pydantic response schemas (they also drive the Swagger docs at /docs)."""
from __future__ import annotations

from typing import List, Optional

from pydantic import BaseModel, Field


class ErrorResponse(BaseModel):
    detail: str = Field(..., description="Human-readable error message")


class HealthResponse(BaseModel):
    status: str
    message: str
    model_loaded: bool
    model_status: str
    mock_identify_enabled: bool


class MonumentSummary(BaseModel):
    id: str
    name: str
    location: str
    thumbnail: Optional[str] = Field(None, description="Absolute thumbnail URL, null if no image is installed")


class Prediction(BaseModel):
    id: str
    confidence: float


class IdentifyResponse(BaseModel):
    monument_id: Optional[str] = Field(None, description="null when the result is 'Unknown Monument'")
    name: str
    confidence: Optional[float] = Field(None, description="Top-1 probability 0-1; null for mock data")
    is_unknown: bool
    top3: List[Prediction] = []
    threshold: float = Field(..., description="Confidence threshold the server applied")
    is_mock: bool = Field(False, description="True when NO trained model produced this result")
    message: Optional[str] = None


class DamageRegion(BaseModel):
    x: int
    y: int
    width: int
    height: int
    area_percent: float


class DamageResponse(BaseModel):
    annotated_image_base64: str = Field(..., description="JPEG, base64 (no data: prefix)")
    damage_area_percent: float
    regions_found: int
    message: str
    disclaimer: str
    regions: List[DamageRegion] = []
    image_width: int
    image_height: int


class ComparisonResponse(BaseModel):
    monument_id: str
    present_url: Optional[str] = None
    reconstruction_url: Optional[str] = None
    has_reconstruction: bool
    explanation: str
    disclaimer: str
