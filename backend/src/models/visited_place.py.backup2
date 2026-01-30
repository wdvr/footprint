"""Visited place data models with extended region type support."""

from datetime import UTC, datetime
from enum import Enum

from pydantic import BaseModel, ConfigDict, Field


class RegionType(str, Enum):
    """Geographic region types with international support."""

    COUNTRY = "country"
    US_STATE = "us_state"
    CANADIAN_PROVINCE = "canadian_province"

    # International regions
    AUSTRALIAN_STATE = "australian_state"
    MEXICAN_STATE = "mexican_state"
    BRAZILIAN_STATE = "brazilian_state"
    GERMAN_STATE = "german_state"
    INDIAN_STATE = "indian_state"
    CHINESE_PROVINCE = "chinese_province"

    # Future expansion - cities and landmarks
    CITY = "city"
    UNESCO_SITE = "unesco_site"
    NATIONAL_PARK = "national_park"


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


# Helper functions for region type classification


def is_subnational_region(region_type: RegionType) -> bool:
    """Check if region type is a subnational division (state/province)."""
    return region_type in {
        RegionType.US_STATE,
        RegionType.CANADIAN_PROVINCE,
        RegionType.AUSTRALIAN_STATE,
        RegionType.MEXICAN_STATE,
        RegionType.BRAZILIAN_STATE,
        RegionType.GERMAN_STATE,
        RegionType.INDIAN_STATE,
        RegionType.CHINESE_PROVINCE,
    }


def is_international_region(region_type: RegionType) -> bool:
    """Check if region type is an international subnational region (non-US/Canada)."""
    return region_type in {
        RegionType.AUSTRALIAN_STATE,
        RegionType.MEXICAN_STATE,
        RegionType.BRAZILIAN_STATE,
        RegionType.GERMAN_STATE,
        RegionType.INDIAN_STATE,
        RegionType.CHINESE_PROVINCE,
    }


def is_landmark_region(region_type: RegionType) -> bool:
    """Check if region type is a landmark/point of interest."""
    return region_type in {
        RegionType.CITY,
        RegionType.UNESCO_SITE,
        RegionType.NATIONAL_PARK,
    }


def get_parent_country_code(region_type: RegionType, region_code: str) -> str | None:
    """Get the parent country code for a subnational region."""
    if region_type == RegionType.US_STATE:
        return "US"
    elif region_type == RegionType.CANADIAN_PROVINCE:
        return "CA"
    elif region_type == RegionType.AUSTRALIAN_STATE:
        return "AU"
    elif region_type == RegionType.MEXICAN_STATE:
        return "MX"
    elif region_type == RegionType.BRAZILIAN_STATE:
        return "BR"
    elif region_type == RegionType.GERMAN_STATE:
        return "DE"
    elif region_type == RegionType.INDIAN_STATE:
        return "IN"
    elif region_type == RegionType.CHINESE_PROVINCE:
        return "CN"
    elif region_type == RegionType.COUNTRY:
        return region_code
    else:
        return None


# Regional totals for statistics
REGION_TOTALS = {
    RegionType.COUNTRY: 195,
    RegionType.US_STATE: 51,  # 50 states + DC
    RegionType.CANADIAN_PROVINCE: 13,  # 10 provinces + 3 territories
    RegionType.AUSTRALIAN_STATE: 8,  # 6 states + 2 territories
    RegionType.MEXICAN_STATE: 32,  # 31 states + 1 federal district
    RegionType.BRAZILIAN_STATE: 27,  # 26 states + 1 federal district
    RegionType.GERMAN_STATE: 16,  # 16 Länder
    RegionType.INDIAN_STATE: 36,  # 28 states + 8 union territories
    RegionType.CHINESE_PROVINCE: 34,  # 22 provinces + 5 autonomous regions + 4 municipalities + 2 SARs + 1 disputed
}


def get_region_total(region_type: RegionType) -> int:
    """Get the total number of regions for a given region type."""
    return REGION_TOTALS.get(region_type, 0)
