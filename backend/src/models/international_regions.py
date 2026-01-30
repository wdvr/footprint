"""Extended geographic region models for international states/provinces."""

from enum import Enum

from pydantic import ConfigDict, Field

from src.models.geographic import GeographicRegion


class SubnationalRegionType(str, Enum):
    """Types of subnational regions."""

    STATE = "state"
    PROVINCE = "province"
    TERRITORY = "territory"
    REGION = "region"
    AUTONOMOUS_REGION = "autonomous_region"
    FEDERAL_DISTRICT = "federal_district"
    MUNICIPALITY = "municipality"
    LANDER = "lander"  # German states
    UNION_TERRITORY = "union_territory"  # Indian territories


class SubnationalRegion(GeographicRegion):
    """Base model for subnational regions (states, provinces, etc.)."""

    model_config = ConfigDict(from_attributes=True)

    # Parent country
    country_code: str = Field(..., description="ISO 3166-1 alpha-2 country code")
    country_name: str = Field(..., description="Country name")

    # Region classification
    region_type: SubnationalRegionType = Field(..., description="Type of region")
    iso_3166_2_code: str = Field(..., description="ISO 3166-2 subdivision code")

    # Geographic data
    capital: str | None = Field(
        None, description="Regional capital/administrative center"
    )
    population: int | None = Field(None, description="Population")
    area_km2: float | None = Field(None, description="Area in square kilometers")

    # Bounding box for map display
    bbox_north: float = Field(..., description="Northern latitude boundary")
    bbox_south: float = Field(..., description="Southern latitude boundary")
    bbox_east: float = Field(..., description="Eastern longitude boundary")
    bbox_west: float = Field(..., description="Western longitude boundary")

    # Center point for map focusing
    center_lat: float = Field(..., description="Center latitude")
    center_lon: float = Field(..., description="Center longitude")

    # Boundary data reference
    boundary_data_url: str | None = Field(
        None, description="S3 URL to boundary geometry"
    )
    boundary_simplified_url: str | None = Field(
        None, description="S3 URL to simplified boundary"
    )


class AustralianState(SubnationalRegion):
    """Australian state or territory."""

    abbreviation: str = Field(..., description="State abbreviation (NSW, VIC, etc.)")
    state_type: str = Field(..., description="'state' or 'territory'")


class MexicanState(SubnationalRegion):
    """Mexican state or federal district."""

    abbreviation: str = Field(..., description="State abbreviation")
    is_federal_district: bool = Field(default=False, description="True for Mexico City")


class BrazilianState(SubnationalRegion):
    """Brazilian state or federal district."""

    abbreviation: str = Field(..., description="State abbreviation (SP, RJ, etc.)")
    is_federal_district: bool = Field(default=False, description="True for Brasília")


class GermanState(SubnationalRegion):
    """German state (Land/Länder)."""

    abbreviation: str = Field(..., description="State abbreviation (BW, BY, etc.)")
    is_city_state: bool = Field(
        default=False, description="True for Berlin, Hamburg, Bremen"
    )


class IndianState(SubnationalRegion):
    """Indian state or union territory."""

    abbreviation: str | None = Field(
        None, description="State abbreviation if available"
    )
    is_union_territory: bool = Field(
        default=False, description="True for union territories"
    )


class ChineseProvince(SubnationalRegion):
    """Chinese province, autonomous region, or municipality."""

    abbreviation: str | None = Field(None, description="Province abbreviation")
    division_type: str = Field(
        ..., description="province, autonomous_region, municipality, or sar"
    )


# Mapping of countries to their specific region models
REGION_MODEL_MAP = {
    "AU": AustralianState,
    "MX": MexicanState,
    "BR": BrazilianState,
    "DE": GermanState,
    "IN": IndianState,
    "CN": ChineseProvince,
}


# Total counts for statistics
REGION_TOTALS = {
    "AU": 8,  # 6 states + 2 territories
    "MX": 32,  # 31 states + 1 federal district
    "BR": 27,  # 26 states + 1 federal district
    "DE": 16,  # 16 Länder
    "IN": 36,  # 28 states + 8 union territories
    "CN": 34,  # 22 provinces + 5 autonomous regions + 4 municipalities + 2 SARs + 1 disputed
}


def get_region_model_for_country(country_code: str) -> type[SubnationalRegion] | None:
    """Get the appropriate region model class for a country."""
    return REGION_MODEL_MAP.get(country_code)


def get_total_regions_for_country(country_code: str) -> int:
    """Get the total number of regions for a country."""
    return REGION_TOTALS.get(country_code, 0)


def is_supported_country(country_code: str) -> bool:
    """Check if a country is supported for subnational region tracking."""
    return country_code in REGION_MODEL_MAP
