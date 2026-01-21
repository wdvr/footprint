"""Geographic region data models."""

from enum import Enum

from pydantic import BaseModel, ConfigDict, Field


class ContinentCode(str, Enum):
    """Continent codes."""

    AF = "AF"  # Africa
    AS = "AS"  # Asia
    EU = "EU"  # Europe
    NA = "NA"  # North America
    OC = "OC"  # Oceania
    SA = "SA"  # South America
    AN = "AN"  # Antarctica


class GeographicRegion(BaseModel):
    """Base geographic region model."""

    model_config = ConfigDict(from_attributes=True)

    code: str = Field(..., description="Standard code (ISO 3166, FIPS, etc.)")
    name: str = Field(..., description="Official name")
    display_name: str = Field(..., description="Display name for UI")


class Country(GeographicRegion):
    """Country model with ISO 3166 data."""

    iso_alpha_2: str = Field(..., description="ISO 3166-1 alpha-2 code")
    iso_alpha_3: str = Field(..., description="ISO 3166-1 alpha-3 code")
    iso_numeric: str = Field(..., description="ISO 3166-1 numeric code")
    continent_code: ContinentCode = Field(..., description="Continent code")

    # Geographic data
    capital: str | None = Field(None, description="Capital city")
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


class USState(GeographicRegion):
    """US State model with FIPS codes."""

    fips_code: str = Field(..., description="FIPS state code")
    abbreviation: str = Field(..., description="State abbreviation (e.g., CA, NY)")
    state_type: str = Field(
        default="state", description="Type: state, district, territory"
    )

    # Geographic data
    capital: str = Field(..., description="State capital")
    population: int | None = Field(None, description="Population")
    area_km2: float | None = Field(None, description="Area in square kilometers")

    # Bounding box
    bbox_north: float = Field(..., description="Northern latitude boundary")
    bbox_south: float = Field(..., description="Southern latitude boundary")
    bbox_east: float = Field(..., description="Eastern longitude boundary")
    bbox_west: float = Field(..., description="Western longitude boundary")

    # Center point
    center_lat: float = Field(..., description="Center latitude")
    center_lon: float = Field(..., description="Center longitude")

    # Boundary data reference
    boundary_data_url: str | None = Field(
        None, description="S3 URL to boundary geometry"
    )
    boundary_simplified_url: str | None = Field(
        None, description="S3 URL to simplified boundary"
    )


class CanadianProvince(GeographicRegion):
    """Canadian Province/Territory model."""

    abbreviation: str = Field(..., description="Province abbreviation (e.g., ON, BC)")
    province_type: str = Field(..., description="Type: province or territory")

    # Geographic data
    capital: str = Field(..., description="Provincial capital")
    population: int | None = Field(None, description="Population")
    area_km2: float | None = Field(None, description="Area in square kilometers")

    # Bounding box
    bbox_north: float = Field(..., description="Northern latitude boundary")
    bbox_south: float = Field(..., description="Southern latitude boundary")
    bbox_east: float = Field(..., description="Eastern longitude boundary")
    bbox_west: float = Field(..., description="Western longitude boundary")

    # Center point
    center_lat: float = Field(..., description="Center latitude")
    center_lon: float = Field(..., description="Center longitude")

    # Boundary data reference
    boundary_data_url: str | None = Field(
        None, description="S3 URL to boundary geometry"
    )
    boundary_simplified_url: str | None = Field(
        None, description="S3 URL to simplified boundary"
    )


class GeographicBounds(BaseModel):
    """Geographic bounding box."""

    north: float
    south: float
    east: float
    west: float

    @property
    def center(self) -> tuple[float, float]:
        """Get center point as (lat, lon)."""
        lat = (self.north + self.south) / 2
        lon = (self.east + self.west) / 2
        return lat, lon


class RegionSearchResult(BaseModel):
    """Result from geographic region search."""

    region_type: str
    code: str
    name: str
    display_name: str
    center_lat: float
    center_lon: float
    bounds: GeographicBounds
    relevance_score: float = Field(ge=0, le=1, description="Search relevance (0-1)")


class GeographicStats(BaseModel):
    """Statistics about geographic regions."""

    total_countries: int = 195
    total_us_states: int = 51  # 50 states + DC
    total_canadian_provinces: int = 13  # 10 provinces + 3 territories
    total_regions: int = 259
