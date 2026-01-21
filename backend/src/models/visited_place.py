"""Visited place data models."""

from datetime import datetime
from typing import Optional
from pydantic import BaseModel, Field, ConfigDict
from enum import Enum


class RegionType(str, Enum):
    """Geographic region types."""
    COUNTRY = "country"
    US_STATE = "us_state"
    CANADIAN_PROVINCE = "canadian_province"


class VisitedPlace(BaseModel):
    """Visited place model with full data."""
    model_config = ConfigDict(from_attributes=True)

    # Composite key: user_id + region_type + region_code
    user_id: str = Field(..., description="User identifier")
    region_type: RegionType = Field(..., description="Type of geographic region")
    region_code: str = Field(..., description="ISO code or standard identifier for the region")

    # Metadata
    region_name: str = Field(..., description="Human-readable region name")
    visited_date: Optional[datetime] = Field(None, description="When the user visited (optional)")
    notes: Optional[str] = Field(None, max_length=500, description="User notes about the visit")

    # Tracking metadata
    marked_at: datetime = Field(default_factory=datetime.utcnow, description="When user marked as visited")
    marked_from_device: Optional[str] = Field(None, description="Device type that marked the visit")

    # Sync metadata
    sync_version: int = Field(default=1, description="Version for conflict resolution")
    last_modified_at: datetime = Field(default_factory=datetime.utcnow, description="Last modification time")
    is_deleted: bool = Field(default=False, description="Soft delete flag for sync")


class VisitedPlaceCreate(BaseModel):
    """Model for creating a new visited place."""
    region_type: RegionType
    region_code: str
    region_name: str
    visited_date: Optional[datetime] = None
    notes: Optional[str] = None


class VisitedPlaceUpdate(BaseModel):
    """Model for updating an existing visited place."""
    visited_date: Optional[datetime] = None
    notes: Optional[str] = None


class VisitedPlaceBatch(BaseModel):
    """Model for batch operations on visited places."""
    places: list[VisitedPlaceCreate] = Field(..., max_items=100, description="Batch of places to create/update")
    operation: str = Field(..., description="Batch operation type: 'create', 'update', 'delete'")


class VisitedPlaceResponse(BaseModel):
    """Response model for visited place operations."""
    success: bool
    message: str
    place: Optional[VisitedPlace] = None
    conflicts: Optional[list[str]] = None