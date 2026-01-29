"""Visited place data models."""

from datetime import UTC, datetime
from enum import Enum

from pydantic import BaseModel, ConfigDict, Field


class RegionType(str, Enum):
    """Geographic region types."""

    COUNTRY = "country"
    US_STATE = "us_state"
    CANADIAN_PROVINCE = "canadian_province"


class PlaceStatus(str, Enum):
    """Status of a place - visited or on bucket list."""

    VISITED = "visited"
    BUCKET_LIST = "bucket_list"


class VisitType(str, Enum):
    """Type of visit - full visit or transit/layover."""

    VISITED = "visited"
    TRANSIT = "transit"


class VisitedPlace(BaseModel):
    """Visited place model with full data."""

    model_config = ConfigDict(from_attributes=True)

    # Composite key: user_id + region_type + region_code
    user_id: str = Field(..., description="User identifier")
    region_type: RegionType = Field(..., description="Type of geographic region")
    region_code: str = Field(
        ..., description="ISO code or standard identifier for the region"
    )

    # Metadata
    region_name: str = Field(..., description="Human-readable region name")
    status: PlaceStatus = Field(
        default=PlaceStatus.VISITED,
        description="Status of the place - visited or bucket list",
    )
    visit_type: VisitType = Field(
        default=VisitType.VISITED,
        description="Type of visit - full visit or transit/layover",
    )
    visited_date: datetime | None = Field(
        None, description="When the user visited (arrival date)"
    )
    departure_date: datetime | None = Field(
        None, description="When the user departed (optional)"
    )
    notes: str | None = Field(
        None, max_length=500, description="User notes about the visit"
    )

    # Tracking metadata
    marked_at: datetime = Field(
        default_factory=lambda: datetime.now(UTC),
        description="When user marked as visited",
    )
    marked_from_device: str | None = Field(
        None, description="Device type that marked the visit"
    )

    # Sync metadata
    sync_version: int = Field(default=1, description="Version for conflict resolution")
    last_modified_at: datetime = Field(
        default_factory=lambda: datetime.now(UTC), description="Last modification time"
    )
    is_deleted: bool = Field(default=False, description="Soft delete flag for sync")


class VisitedPlaceCreate(BaseModel):
    """Model for creating a new visited place."""

    region_type: RegionType
    region_code: str
    region_name: str
    status: PlaceStatus = PlaceStatus.VISITED
    visit_type: VisitType = VisitType.VISITED
    visited_date: datetime | None = None
    departure_date: datetime | None = None
    notes: str | None = None


class VisitedPlaceUpdate(BaseModel):
    """Model for updating an existing visited place."""

    status: PlaceStatus | None = None
    visit_type: VisitType | None = None
    visited_date: datetime | None = None
    departure_date: datetime | None = None
    notes: str | None = None


class VisitedPlaceBatch(BaseModel):
    """Model for batch operations on visited places."""

    places: list[VisitedPlaceCreate] = Field(
        ..., max_length=100, description="Batch of places to create/update"
    )
    operation: str = Field(
        ..., description="Batch operation type: 'create', 'update', 'delete'"
    )


class VisitedPlaceResponse(BaseModel):
    """Response model for visited place operations."""

    success: bool
    message: str
    place: VisitedPlace | None = None
    conflicts: list[str] | None = None
