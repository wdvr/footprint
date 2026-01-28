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


class Continent(str, Enum):
    """Continent classification."""

    AFRICA = "Africa"
    ANTARCTICA = "Antarctica"
    ASIA = "Asia"
    EUROPE = "Europe"
    NORTH_AMERICA = "North America"
    OCEANIA = "Oceania"
    SOUTH_AMERICA = "South America"


# Country to continent mapping (ISO alpha-2 codes)
COUNTRY_CONTINENTS: dict[str, Continent] = {
    # Africa (54 countries)
    "DZ": Continent.AFRICA,
    "AO": Continent.AFRICA,
    "BJ": Continent.AFRICA,
    "BW": Continent.AFRICA,
    "BF": Continent.AFRICA,
    "BI": Continent.AFRICA,
    "CV": Continent.AFRICA,
    "CM": Continent.AFRICA,
    "CF": Continent.AFRICA,
    "TD": Continent.AFRICA,
    "KM": Continent.AFRICA,
    "CG": Continent.AFRICA,
    "CD": Continent.AFRICA,
    "CI": Continent.AFRICA,
    "DJ": Continent.AFRICA,
    "EG": Continent.AFRICA,
    "GQ": Continent.AFRICA,
    "ER": Continent.AFRICA,
    "SZ": Continent.AFRICA,
    "ET": Continent.AFRICA,
    "GA": Continent.AFRICA,
    "GM": Continent.AFRICA,
    "GH": Continent.AFRICA,
    "GN": Continent.AFRICA,
    "GW": Continent.AFRICA,
    "KE": Continent.AFRICA,
    "LS": Continent.AFRICA,
    "LR": Continent.AFRICA,
    "LY": Continent.AFRICA,
    "MG": Continent.AFRICA,
    "MW": Continent.AFRICA,
    "ML": Continent.AFRICA,
    "MR": Continent.AFRICA,
    "MU": Continent.AFRICA,
    "MA": Continent.AFRICA,
    "MZ": Continent.AFRICA,
    "NA": Continent.AFRICA,
    "NE": Continent.AFRICA,
    "NG": Continent.AFRICA,
    "RW": Continent.AFRICA,
    "ST": Continent.AFRICA,
    "SN": Continent.AFRICA,
    "SC": Continent.AFRICA,
    "SL": Continent.AFRICA,
    "SO": Continent.AFRICA,
    "ZA": Continent.AFRICA,
    "SS": Continent.AFRICA,
    "SD": Continent.AFRICA,
    "TZ": Continent.AFRICA,
    "TG": Continent.AFRICA,
    "TN": Continent.AFRICA,
    "UG": Continent.AFRICA,
    "ZM": Continent.AFRICA,
    "ZW": Continent.AFRICA,
    # Asia (49 countries)
    "AF": Continent.ASIA,
    "AM": Continent.ASIA,
    "AZ": Continent.ASIA,
    "BH": Continent.ASIA,
    "BD": Continent.ASIA,
    "BT": Continent.ASIA,
    "BN": Continent.ASIA,
    "KH": Continent.ASIA,
    "CN": Continent.ASIA,
    "CY": Continent.ASIA,
    "GE": Continent.ASIA,
    "IN": Continent.ASIA,
    "ID": Continent.ASIA,
    "IR": Continent.ASIA,
    "IQ": Continent.ASIA,
    "IL": Continent.ASIA,
    "JP": Continent.ASIA,
    "JO": Continent.ASIA,
    "KZ": Continent.ASIA,
    "KW": Continent.ASIA,
    "KG": Continent.ASIA,
    "LA": Continent.ASIA,
    "LB": Continent.ASIA,
    "MY": Continent.ASIA,
    "MV": Continent.ASIA,
    "MN": Continent.ASIA,
    "MM": Continent.ASIA,
    "NP": Continent.ASIA,
    "KP": Continent.ASIA,
    "OM": Continent.ASIA,
    "PK": Continent.ASIA,
    "PS": Continent.ASIA,
    "PH": Continent.ASIA,
    "QA": Continent.ASIA,
    "SA": Continent.ASIA,
    "SG": Continent.ASIA,
    "KR": Continent.ASIA,
    "LK": Continent.ASIA,
    "SY": Continent.ASIA,
    "TW": Continent.ASIA,
    "TJ": Continent.ASIA,
    "TH": Continent.ASIA,
    "TL": Continent.ASIA,
    "TR": Continent.ASIA,
    "TM": Continent.ASIA,
    "AE": Continent.ASIA,
    "UZ": Continent.ASIA,
    "VN": Continent.ASIA,
    "YE": Continent.ASIA,
    # Europe (44 countries)
    "AL": Continent.EUROPE,
    "AD": Continent.EUROPE,
    "AT": Continent.EUROPE,
    "BY": Continent.EUROPE,
    "BE": Continent.EUROPE,
    "BA": Continent.EUROPE,
    "BG": Continent.EUROPE,
    "HR": Continent.EUROPE,
    "CZ": Continent.EUROPE,
    "DK": Continent.EUROPE,
    "EE": Continent.EUROPE,
    "FI": Continent.EUROPE,
    "FR": Continent.EUROPE,
    "DE": Continent.EUROPE,
    "GR": Continent.EUROPE,
    "HU": Continent.EUROPE,
    "IS": Continent.EUROPE,
    "IE": Continent.EUROPE,
    "IT": Continent.EUROPE,
    "LV": Continent.EUROPE,
    "LI": Continent.EUROPE,
    "LT": Continent.EUROPE,
    "LU": Continent.EUROPE,
    "MT": Continent.EUROPE,
    "MD": Continent.EUROPE,
    "MC": Continent.EUROPE,
    "ME": Continent.EUROPE,
    "NL": Continent.EUROPE,
    "MK": Continent.EUROPE,
    "NO": Continent.EUROPE,
    "PL": Continent.EUROPE,
    "PT": Continent.EUROPE,
    "RO": Continent.EUROPE,
    "RU": Continent.EUROPE,
    "SM": Continent.EUROPE,
    "RS": Continent.EUROPE,
    "SK": Continent.EUROPE,
    "SI": Continent.EUROPE,
    "ES": Continent.EUROPE,
    "SE": Continent.EUROPE,
    "CH": Continent.EUROPE,
    "UA": Continent.EUROPE,
    "GB": Continent.EUROPE,
    "VA": Continent.EUROPE,
    # North America (23 countries)
    "AG": Continent.NORTH_AMERICA,
    "BS": Continent.NORTH_AMERICA,
    "BB": Continent.NORTH_AMERICA,
    "BZ": Continent.NORTH_AMERICA,
    "CA": Continent.NORTH_AMERICA,
    "CR": Continent.NORTH_AMERICA,
    "CU": Continent.NORTH_AMERICA,
    "DM": Continent.NORTH_AMERICA,
    "DO": Continent.NORTH_AMERICA,
    "SV": Continent.NORTH_AMERICA,
    "GD": Continent.NORTH_AMERICA,
    "GT": Continent.NORTH_AMERICA,
    "HT": Continent.NORTH_AMERICA,
    "HN": Continent.NORTH_AMERICA,
    "JM": Continent.NORTH_AMERICA,
    "MX": Continent.NORTH_AMERICA,
    "NI": Continent.NORTH_AMERICA,
    "PA": Continent.NORTH_AMERICA,
    "KN": Continent.NORTH_AMERICA,
    "LC": Continent.NORTH_AMERICA,
    "VC": Continent.NORTH_AMERICA,
    "TT": Continent.NORTH_AMERICA,
    "US": Continent.NORTH_AMERICA,
    # Oceania (14 countries)
    "AU": Continent.OCEANIA,
    "FJ": Continent.OCEANIA,
    "KI": Continent.OCEANIA,
    "MH": Continent.OCEANIA,
    "FM": Continent.OCEANIA,
    "NR": Continent.OCEANIA,
    "NZ": Continent.OCEANIA,
    "PW": Continent.OCEANIA,
    "PG": Continent.OCEANIA,
    "WS": Continent.OCEANIA,
    "SB": Continent.OCEANIA,
    "TO": Continent.OCEANIA,
    "TV": Continent.OCEANIA,
    "VU": Continent.OCEANIA,
    # South America (12 countries)
    "AR": Continent.SOUTH_AMERICA,
    "BO": Continent.SOUTH_AMERICA,
    "BR": Continent.SOUTH_AMERICA,
    "CL": Continent.SOUTH_AMERICA,
    "CO": Continent.SOUTH_AMERICA,
    "EC": Continent.SOUTH_AMERICA,
    "GY": Continent.SOUTH_AMERICA,
    "PY": Continent.SOUTH_AMERICA,
    "PE": Continent.SOUTH_AMERICA,
    "SR": Continent.SOUTH_AMERICA,
    "UY": Continent.SOUTH_AMERICA,
    "VE": Continent.SOUTH_AMERICA,
}

# Continent totals
CONTINENT_COUNTRY_COUNTS: dict[Continent, int] = {
    Continent.AFRICA: 54,
    Continent.ANTARCTICA: 0,
    Continent.ASIA: 49,
    Continent.EUROPE: 44,
    Continent.NORTH_AMERICA: 23,
    Continent.OCEANIA: 14,
    Continent.SOUTH_AMERICA: 12,
}

# Country to primary time zones (UTC offset in hours)
# For countries with multiple time zones, listing all
COUNTRY_TIMEZONES: dict[str, list[int]] = {
    # Multi-zone countries
    "US": [-10, -9, -8, -7, -6, -5],
    "CA": [-8, -7, -6, -5, -4, -3],
    "MX": [-8, -7, -6],
    "BR": [-5, -4, -3],
    "RU": [2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12],
    "AU": [8, 9, 10, 11],
    "ID": [7, 8, 9],
    "CL": [-4, -3],
    "CD": [1, 2],
    "KZ": [5, 6],
    "PT": [0, 1],
    "FM": [10, 11],
    "KI": [12, 13, 14],
    "NZ": [12, 13],
    # UTC-6 to UTC-5
    "GT": [-6],
    "HN": [-6],
    "SV": [-6],
    "NI": [-6],
    "CR": [-6],
    "BZ": [-6],
    "PA": [-5],
    "CO": [-5],
    "EC": [-5],
    "PE": [-5],
    "CU": [-5],
    "JM": [-5],
    "HT": [-5],
    "BS": [-5],
    # UTC-4
    "VE": [-4],
    "BO": [-4],
    "PY": [-4],
    "BB": [-4],
    "TT": [-4],
    "GY": [-4],
    "DO": [-4],
    "AG": [-4],
    "DM": [-4],
    "GD": [-4],
    "KN": [-4],
    "LC": [-4],
    "VC": [-4],
    # UTC-3
    "AR": [-3],
    "UY": [-3],
    "SR": [-3],
    # UTC-1 to UTC+0
    "CV": [-1],
    "GB": [0],
    "IE": [0],
    "IS": [0],
    "MA": [0],
    "SN": [0],
    "GM": [0],
    "GN": [0],
    "GW": [0],
    "ML": [0],
    "MR": [0],
    "SL": [0],
    "LR": [0],
    "CI": [0],
    "BF": [0],
    "GH": [0],
    "TG": [0],
    # UTC+1
    "FR": [1],
    "ES": [1],
    "DE": [1],
    "IT": [1],
    "NL": [1],
    "BE": [1],
    "AT": [1],
    "CH": [1],
    "PL": [1],
    "CZ": [1],
    "SK": [1],
    "HU": [1],
    "SI": [1],
    "HR": [1],
    "BA": [1],
    "RS": [1],
    "ME": [1],
    "MK": [1],
    "AL": [1],
    "DK": [1],
    "NO": [1],
    "SE": [1],
    "LU": [1],
    "LI": [1],
    "MC": [1],
    "AD": [1],
    "SM": [1],
    "VA": [1],
    "MT": [1],
    "TN": [1],
    "DZ": [1],
    "NG": [1],
    "CM": [1],
    "TD": [1],
    "CF": [1],
    "CG": [1],
    "GA": [1],
    "GQ": [1],
    "BJ": [1],
    "NE": [1],
    "AO": [1],
    # UTC+2
    "FI": [2],
    "EE": [2],
    "LV": [2],
    "LT": [2],
    "UA": [2],
    "MD": [2],
    "RO": [2],
    "BG": [2],
    "GR": [2],
    "CY": [2],
    "IL": [2],
    "PS": [2],
    "LB": [2],
    "SY": [2],
    "JO": [2],
    "EG": [2],
    "LY": [2],
    "SD": [2],
    "SS": [2],
    "ZA": [2],
    "BW": [2],
    "ZW": [2],
    "ZM": [2],
    "MW": [2],
    "MZ": [2],
    "SZ": [2],
    "LS": [2],
    "NA": [2],
    "RW": [2],
    "BI": [2],
    # UTC+3
    "TR": [3],
    "BY": [3],
    "SA": [3],
    "IQ": [3],
    "KW": [3],
    "BH": [3],
    "QA": [3],
    "YE": [3],
    "ER": [3],
    "DJ": [3],
    "SO": [3],
    "ET": [3],
    "KE": [3],
    "UG": [3],
    "TZ": [3],
    "KM": [3],
    "MG": [3],
    "IR": [3],
    # UTC+4
    "AE": [4],
    "OM": [4],
    "AZ": [4],
    "AM": [4],
    "GE": [4],
    "MU": [4],
    "SC": [4],
    "AF": [4],
    # UTC+5
    "PK": [5],
    "UZ": [5],
    "TJ": [5],
    "TM": [5],
    "MV": [5],
    "IN": [5],
    "LK": [5],
    "NP": [5],
    # UTC+6
    "BD": [6],
    "BT": [6],
    "KG": [6],
    "MM": [6],
    # UTC+7
    "TH": [7],
    "VN": [7],
    "KH": [7],
    "LA": [7],
    # UTC+8
    "CN": [8],
    "TW": [8],
    "SG": [8],
    "MY": [8],
    "BN": [8],
    "PH": [8],
    "MN": [8],
    # UTC+9
    "JP": [9],
    "KR": [9],
    "KP": [9],
    "TL": [9],
    "PW": [9],
    # UTC+10+
    "PG": [10],
    "SB": [11],
    "VU": [11],
    "FJ": [12],
    "NR": [12],
    "TV": [12],
    "MH": [12],
    "TO": [13],
    "WS": [13],
}


class ContinentStats(BaseModel):
    """Statistics for a single continent."""

    continent: str = Field(..., description="Continent name")
    countries_visited: int = Field(default=0, description="Countries visited")
    countries_total: int = Field(..., description="Total countries in continent")
    percentage: float = Field(default=0.0, description="Percentage visited")
    visited_countries: list[str] = Field(
        default_factory=list, description="List of visited country codes"
    )


class ContinentStatsResponse(BaseModel):
    """Response model for continent statistics."""

    continents: list[ContinentStats] = Field(..., description="Stats by continent")
    total_continents_visited: int = Field(
        default=0, description="Number of continents with at least one country visited"
    )


class TimeZoneStats(BaseModel):
    """Statistics for time zone coverage."""

    total_zones: int = Field(default=24, description="Total number of time zones")
    zones_visited: int = Field(default=0, description="Time zones visited")
    percentage: float = Field(default=0.0, description="Percentage of zones visited")
    zones: list[dict] = Field(
        default_factory=list,
        description="List of zones with visited status and countries",
    )
    farthest_east: int | None = Field(
        None, description="Easternmost time zone visited (UTC+)"
    )
    farthest_west: int | None = Field(
        None, description="Westernmost time zone visited (UTC-)"
    )


def get_country_continent(country_code: str) -> Continent | None:
    """Get the continent for a country code."""
    return COUNTRY_CONTINENTS.get(country_code)


def get_country_timezones(country_code: str) -> list[int]:
    """Get the time zones for a country code."""
    return COUNTRY_TIMEZONES.get(country_code, [])
