"""Tests for geographic data models and mappings."""

from src.models.geographic import (
    CONTINENT_COUNTRY_COUNTS,
    COUNTRY_CONTINENTS,
    COUNTRY_TIMEZONES,
    Continent,
    ContinentStats,
    ContinentStatsResponse,
    TimeZoneStats,
    get_country_continent,
    get_country_timezones,
)


class TestContinentMapping:
    """Tests for country to continent mappings."""

    def test_all_continents_have_countries(self):
        """Test that all continents (except Antarctica) have countries."""
        for continent in Continent:
            if continent != Continent.ANTARCTICA:
                countries = [
                    code
                    for code, cont in COUNTRY_CONTINENTS.items()
                    if cont == continent
                ]
                assert len(countries) > 0, f"No countries mapped to {continent}"

    def test_continent_counts_match_mappings(self):
        """Test that continent country counts match the actual mappings."""
        for continent in Continent:
            if continent == Continent.ANTARCTICA:
                continue
            mapped_count = sum(
                1 for cont in COUNTRY_CONTINENTS.values() if cont == continent
            )
            expected_count = CONTINENT_COUNTRY_COUNTS.get(continent, 0)
            assert mapped_count == expected_count, (
                f"Mismatch for {continent}: mapped={mapped_count}, expected={expected_count}"
            )

    def test_get_country_continent_europe(self):
        """Test getting continent for European countries."""
        assert get_country_continent("FR") == Continent.EUROPE
        assert get_country_continent("DE") == Continent.EUROPE
        assert get_country_continent("GB") == Continent.EUROPE
        assert get_country_continent("IT") == Continent.EUROPE

    def test_get_country_continent_asia(self):
        """Test getting continent for Asian countries."""
        assert get_country_continent("JP") == Continent.ASIA
        assert get_country_continent("CN") == Continent.ASIA
        assert get_country_continent("IN") == Continent.ASIA
        assert get_country_continent("KR") == Continent.ASIA

    def test_get_country_continent_africa(self):
        """Test getting continent for African countries."""
        assert get_country_continent("ZA") == Continent.AFRICA
        assert get_country_continent("EG") == Continent.AFRICA
        assert get_country_continent("NG") == Continent.AFRICA
        assert get_country_continent("KE") == Continent.AFRICA

    def test_get_country_continent_north_america(self):
        """Test getting continent for North American countries."""
        assert get_country_continent("US") == Continent.NORTH_AMERICA
        assert get_country_continent("CA") == Continent.NORTH_AMERICA
        assert get_country_continent("MX") == Continent.NORTH_AMERICA

    def test_get_country_continent_south_america(self):
        """Test getting continent for South American countries."""
        assert get_country_continent("BR") == Continent.SOUTH_AMERICA
        assert get_country_continent("AR") == Continent.SOUTH_AMERICA
        assert get_country_continent("CL") == Continent.SOUTH_AMERICA

    def test_get_country_continent_oceania(self):
        """Test getting continent for Oceania countries."""
        assert get_country_continent("AU") == Continent.OCEANIA
        assert get_country_continent("NZ") == Continent.OCEANIA
        assert get_country_continent("FJ") == Continent.OCEANIA

    def test_get_country_continent_invalid(self):
        """Test getting continent for invalid country code."""
        assert get_country_continent("XX") is None
        assert get_country_continent("") is None


class TestTimeZoneMapping:
    """Tests for country to timezone mappings."""

    def test_us_has_multiple_timezones(self):
        """Test that US has multiple time zones."""
        zones = get_country_timezones("US")
        assert len(zones) > 1
        assert -10 in zones  # Hawaii
        assert -5 in zones  # Eastern

    def test_russia_has_many_timezones(self):
        """Test that Russia has many time zones."""
        zones = get_country_timezones("RU")
        assert len(zones) >= 10  # Russia spans 11 zones

    def test_single_timezone_countries(self):
        """Test countries with single time zones."""
        assert get_country_timezones("GB") == [0]  # UTC+0
        assert get_country_timezones("JP") == [9]  # UTC+9
        assert get_country_timezones("SG") == [8]  # UTC+8

    def test_get_country_timezones_invalid(self):
        """Test getting timezones for invalid country code."""
        assert get_country_timezones("XX") == []
        assert get_country_timezones("") == []

    def test_timezone_range(self):
        """Test that all time zones are in valid range."""
        for zones in COUNTRY_TIMEZONES.values():
            for zone in zones:
                assert -12 <= zone <= 14, f"Invalid timezone: {zone}"


class TestContinentStatsModel:
    """Tests for ContinentStats Pydantic model."""

    def test_continent_stats_creation(self):
        """Test creating a ContinentStats model."""
        stats = ContinentStats(
            continent="Europe",
            countries_visited=5,
            countries_total=44,
            percentage=11.36,
            visited_countries=["FR", "DE", "IT", "ES", "PT"],
        )
        assert stats.continent == "Europe"
        assert stats.countries_visited == 5
        assert stats.countries_total == 44
        assert len(stats.visited_countries) == 5

    def test_continent_stats_defaults(self):
        """Test ContinentStats default values."""
        stats = ContinentStats(continent="Asia", countries_total=49)
        assert stats.countries_visited == 0
        assert stats.percentage == 0.0
        assert stats.visited_countries == []


class TestContinentStatsResponse:
    """Tests for ContinentStatsResponse Pydantic model."""

    def test_continent_stats_response(self):
        """Test creating a ContinentStatsResponse model."""
        europe_stats = ContinentStats(
            continent="Europe",
            countries_visited=5,
            countries_total=44,
            percentage=11.36,
        )
        asia_stats = ContinentStats(
            continent="Asia",
            countries_visited=2,
            countries_total=49,
            percentage=4.08,
        )

        response = ContinentStatsResponse(
            continents=[europe_stats, asia_stats],
            total_continents_visited=2,
        )
        assert len(response.continents) == 2
        assert response.total_continents_visited == 2


class TestTimeZoneStatsModel:
    """Tests for TimeZoneStats Pydantic model."""

    def test_timezone_stats_creation(self):
        """Test creating a TimeZoneStats model."""
        stats = TimeZoneStats(
            total_zones=24,
            zones_visited=8,
            percentage=33.33,
            zones=[
                {"offset": 0, "name": "UTC+0", "visited": True, "countries": ["GB"]},
                {
                    "offset": 1,
                    "name": "UTC+1",
                    "visited": True,
                    "countries": ["FR", "DE"],
                },
            ],
            farthest_east=9,
            farthest_west=-5,
        )
        assert stats.zones_visited == 8
        assert stats.farthest_east == 9
        assert stats.farthest_west == -5

    def test_timezone_stats_defaults(self):
        """Test TimeZoneStats default values."""
        stats = TimeZoneStats()
        assert stats.total_zones == 24
        assert stats.zones_visited == 0
        assert stats.percentage == 0.0
        assert stats.zones == []
        assert stats.farthest_east is None
        assert stats.farthest_west is None


class TestContinentEnum:
    """Tests for Continent enum."""

    def test_continent_values(self):
        """Test Continent enum values."""
        assert Continent.AFRICA.value == "Africa"
        assert Continent.ANTARCTICA.value == "Antarctica"
        assert Continent.ASIA.value == "Asia"
        assert Continent.EUROPE.value == "Europe"
        assert Continent.NORTH_AMERICA.value == "North America"
        assert Continent.OCEANIA.value == "Oceania"
        assert Continent.SOUTH_AMERICA.value == "South America"

    def test_all_continents_count(self):
        """Test that all 7 continents are defined."""
        assert len(Continent) == 7
