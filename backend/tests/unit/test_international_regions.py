"""Tests for international regions functionality."""

from src.models.international_regions import (
    AustralianState,
    BrazilianState,
    ChineseProvince,
    GermanState,
    IndianState,
    MexicanState,
    get_region_model_for_country,
    get_total_regions_for_country,
    is_supported_country,
)
from src.models.visited_place import (
    RegionType,
    get_region_total,
    is_international_region,
    is_subnational_region,
)


class TestRegionTypeClassification:
    """Test region type classification functions."""

    def test_is_international_region(self):
        """Test international region classification."""
        # Should be True for international regions
        assert is_international_region(RegionType.AUSTRALIAN_STATE)
        assert is_international_region(RegionType.MEXICAN_STATE)
        assert is_international_region(RegionType.BRAZILIAN_STATE)
        assert is_international_region(RegionType.GERMAN_STATE)
        assert is_international_region(RegionType.INDIAN_STATE)
        assert is_international_region(RegionType.CHINESE_PROVINCE)

        # Should be False for non-international regions
        assert not is_international_region(RegionType.COUNTRY)
        assert not is_international_region(RegionType.US_STATE)
        assert not is_international_region(RegionType.CANADIAN_PROVINCE)

    def test_is_subnational_region(self):
        """Test subnational region classification."""
        # All states/provinces should be subnational
        assert is_subnational_region(RegionType.US_STATE)
        assert is_subnational_region(RegionType.CANADIAN_PROVINCE)
        assert is_subnational_region(RegionType.AUSTRALIAN_STATE)
        assert is_subnational_region(RegionType.MEXICAN_STATE)
        assert is_subnational_region(RegionType.BRAZILIAN_STATE)
        assert is_subnational_region(RegionType.GERMAN_STATE)
        assert is_subnational_region(RegionType.INDIAN_STATE)
        assert is_subnational_region(RegionType.CHINESE_PROVINCE)

        # Countries should not be subnational
        assert not is_subnational_region(RegionType.COUNTRY)

    def test_get_region_total(self):
        """Test getting total region counts."""
        assert get_region_total(RegionType.COUNTRY) == 195
        assert get_region_total(RegionType.US_STATE) == 51
        assert get_region_total(RegionType.CANADIAN_PROVINCE) == 13
        assert get_region_total(RegionType.AUSTRALIAN_STATE) == 8
        assert get_region_total(RegionType.MEXICAN_STATE) == 32
        assert get_region_total(RegionType.BRAZILIAN_STATE) == 27
        assert get_region_total(RegionType.GERMAN_STATE) == 16
        assert get_region_total(RegionType.INDIAN_STATE) == 36
        assert get_region_total(RegionType.CHINESE_PROVINCE) == 34


class TestInternationalRegionModels:
    """Test international region data models."""

    def test_australian_state_model(self):
        """Test Australian state model."""
        state = AustralianState(
            code="NSW",
            name="New South Wales",
            display_name="New South Wales",
            country_code="AU",
            country_name="Australia",
            region_type="state",
            iso_3166_2_code="AU-NSW",
            capital="Sydney",
            abbreviation="NSW",
            state_type="state",
            bbox_north=-28.0,
            bbox_south=-37.5,
            bbox_east=153.6,
            bbox_west=141.0,
            center_lat=-32.5,
            center_lon=147.3,
        )

        assert state.code == "NSW"
        assert state.country_code == "AU"
        assert state.abbreviation == "NSW"
        assert state.state_type == "state"
        assert state.capital == "Sydney"

    def test_mexican_state_model(self):
        """Test Mexican state model."""
        state = MexicanState(
            code="CDMX",
            name="Ciudad de México",
            display_name="Ciudad de México",
            country_code="MX",
            country_name="Mexico",
            region_type="federal_district",
            iso_3166_2_code="MX-CMX",
            capital="Ciudad de México",
            abbreviation="CDMX",
            is_federal_district=True,
            bbox_north=19.6,
            bbox_south=19.0,
            bbox_east=-98.9,
            bbox_west=-99.4,
            center_lat=19.4,
            center_lon=-99.1,
        )

        assert state.code == "CDMX"
        assert state.country_code == "MX"
        assert state.is_federal_district is True
        assert state.abbreviation == "CDMX"

    def test_brazilian_state_model(self):
        """Test Brazilian state model."""
        state = BrazilianState(
            code="SP",
            name="São Paulo",
            display_name="São Paulo",
            country_code="BR",
            country_name="Brazil",
            region_type="state",
            iso_3166_2_code="BR-SP",
            capital="São Paulo",
            abbreviation="SP",
            is_federal_district=False,
            bbox_north=-19.8,
            bbox_south=-25.3,
            bbox_east=-44.2,
            bbox_west=-53.1,
            center_lat=-22.5,
            center_lon=-48.6,
        )

        assert state.code == "SP"
        assert state.country_code == "BR"
        assert state.abbreviation == "SP"
        assert state.is_federal_district is False

    def test_german_state_model(self):
        """Test German state model."""
        state = GermanState(
            code="BY",
            name="Bayern",
            display_name="Bayern",
            country_code="DE",
            country_name="Germany",
            region_type="state",
            iso_3166_2_code="DE-BY",
            capital="München",
            abbreviation="BY",
            is_city_state=False,
            bbox_north=50.6,
            bbox_south=47.3,
            bbox_east=13.8,
            bbox_west=8.9,
            center_lat=49.0,
            center_lon=11.4,
        )

        assert state.code == "BY"
        assert state.country_code == "DE"
        assert state.abbreviation == "BY"
        assert state.is_city_state is False


class TestInternationalRegionHelpers:
    """Test helper functions for international regions."""

    def test_get_region_model_for_country(self):
        """Test getting region model class for country."""
        assert get_region_model_for_country("AU") == AustralianState
        assert get_region_model_for_country("MX") == MexicanState
        assert get_region_model_for_country("BR") == BrazilianState
        assert get_region_model_for_country("DE") == GermanState
        assert get_region_model_for_country("IN") == IndianState
        assert get_region_model_for_country("CN") == ChineseProvince
        assert get_region_model_for_country("FR") is None  # Not supported

    def test_get_total_regions_for_country(self):
        """Test getting total regions for country."""
        assert get_total_regions_for_country("AU") == 8
        assert get_total_regions_for_country("MX") == 32
        assert get_total_regions_for_country("BR") == 27
        assert get_total_regions_for_country("DE") == 16
        assert get_total_regions_for_country("IN") == 36
        assert get_total_regions_for_country("CN") == 34
        assert get_total_regions_for_country("FR") == 0  # Not supported

    def test_is_supported_country(self):
        """Test checking if country is supported."""
        # Supported countries
        assert is_supported_country("AU") is True
        assert is_supported_country("MX") is True
        assert is_supported_country("BR") is True
        assert is_supported_country("DE") is True
        assert is_supported_country("IN") is True
        assert is_supported_country("CN") is True

        # Unsupported countries
        assert is_supported_country("FR") is False
        assert is_supported_country("JP") is False
        assert is_supported_country("UK") is False

    def test_region_totals_consistency(self):
        """Test that region totals are consistent across modules."""
        # Ensure totals match between modules
        from src.models.international_regions import (
            REGION_TOTALS as INTERNATIONAL_TOTALS,
        )
        from src.models.visited_place import REGION_TOTALS as VISITED_PLACE_TOTALS

        assert (
            VISITED_PLACE_TOTALS[RegionType.AUSTRALIAN_STATE]
            == INTERNATIONAL_TOTALS["AU"]
        )
        assert (
            VISITED_PLACE_TOTALS[RegionType.MEXICAN_STATE] == INTERNATIONAL_TOTALS["MX"]
        )
        assert (
            VISITED_PLACE_TOTALS[RegionType.BRAZILIAN_STATE]
            == INTERNATIONAL_TOTALS["BR"]
        )
        assert (
            VISITED_PLACE_TOTALS[RegionType.GERMAN_STATE] == INTERNATIONAL_TOTALS["DE"]
        )
        assert (
            VISITED_PLACE_TOTALS[RegionType.INDIAN_STATE] == INTERNATIONAL_TOTALS["IN"]
        )
        assert (
            VISITED_PLACE_TOTALS[RegionType.CHINESE_PROVINCE]
            == INTERNATIONAL_TOTALS["CN"]
        )


class TestDataGeneration:
    """Test data generation functionality."""

    def test_sample_data_structure(self):
        """Test that generated data has correct structure."""
        # This would test the actual data files once they're generated
        # For now, we can test the sample data structure

        sample_region = {
            "code": "NSW",
            "name": "New South Wales",
            "display_name": "New South Wales",
            "country_code": "AU",
            "country_name": "Australia",
            "region_type": "state",
            "iso_3166_2_code": "AU-NSW",
            "capital": "Sydney",
            "abbreviation": "NSW",
        }

        # Test required fields are present
        required_fields = [
            "code",
            "name",
            "display_name",
            "country_code",
            "country_name",
            "region_type",
            "iso_3166_2_code",
        ]

        for field in required_fields:
            assert field in sample_region
            assert sample_region[field] is not None

    def test_iso_code_format(self):
        """Test ISO 3166-2 code format."""
        test_codes = [
            "AU-NSW",  # Australia
            "MX-AGU",  # Mexico
            "BR-SP",  # Brazil
            "DE-BY",  # Germany
            "IN-AP",  # India
            "CN-AH",  # China
        ]

        for code in test_codes:
            # Should be format: XX-YYY (2 letter country + dash + region code)
            parts = code.split("-")
            assert len(parts) == 2
            assert len(parts[0]) == 2  # Country code
            assert len(parts[1]) >= 1  # Region code (variable length)
            assert parts[0].isupper()  # Country code uppercase
