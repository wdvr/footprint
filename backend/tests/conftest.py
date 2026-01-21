"""Pytest configuration and fixtures."""

from datetime import datetime
from typing import Any

import boto3
import pytest
from moto import mock_aws

from src.models.geographic import ContinentCode, Country, USState
from src.models.user import AuthProvider, User
from src.models.visited_place import RegionType, VisitedPlace


@pytest.fixture
def mock_aws_services():
    """Mock AWS services for testing."""
    with mock_aws():
        yield


@pytest.fixture
def sample_user() -> User:
    """Create a sample user for testing."""
    return User(
        user_id="test-user-123",
        auth_provider=AuthProvider.APPLE,
        auth_provider_id="apple-user-456",
        email="test@example.com",
        display_name="Test User",
        countries_visited=5,
        us_states_visited=10,
        canadian_provinces_visited=2,
        created_at=datetime(2024, 1, 15, 10, 0, 0),
        updated_at=datetime(2024, 1, 20, 15, 30, 0),
    )


@pytest.fixture
def sample_visited_places() -> list[VisitedPlace]:
    """Create sample visited places for testing."""
    return [
        VisitedPlace(
            user_id="test-user-123",
            region_type=RegionType.COUNTRY,
            region_code="US",
            region_name="United States",
            visited_date=datetime(2023, 6, 15),
            notes="Amazing road trip across the country",
        ),
        VisitedPlace(
            user_id="test-user-123",
            region_type=RegionType.US_STATE,
            region_code="CA",
            region_name="California",
            visited_date=datetime(2023, 7, 4),
            notes="San Francisco and Los Angeles",
        ),
        VisitedPlace(
            user_id="test-user-123",
            region_type=RegionType.CANADIAN_PROVINCE,
            region_code="BC",
            region_name="British Columbia",
            visited_date=datetime(2024, 1, 10),
            notes="Beautiful Vancouver and Whistler",
        ),
    ]


@pytest.fixture
def sample_countries() -> list[Country]:
    """Create sample countries for testing."""
    return [
        Country(
            code="US",
            name="United States of America",
            display_name="United States",
            iso_alpha_2="US",
            iso_alpha_3="USA",
            iso_numeric="840",
            continent_code=ContinentCode.NA,
            capital="Washington, D.C.",
            population=331900000,
            area_km2=9833520,
            bbox_north=71.5388,
            bbox_south=18.7763,
            bbox_east=-66.885444,
            bbox_west=170.5957,
            center_lat=39.8283,
            center_lon=-98.5795,
        ),
        Country(
            code="CA",
            name="Canada",
            display_name="Canada",
            iso_alpha_2="CA",
            iso_alpha_3="CAN",
            iso_numeric="124",
            continent_code=ContinentCode.NA,
            capital="Ottawa",
            population=38000000,
            area_km2=9984670,
            bbox_north=83.23324,
            bbox_south=41.67598,
            bbox_east=-52.63637,
            bbox_west=-141.003,
            center_lat=56.130366,
            center_lon=-106.346771,
        ),
    ]


@pytest.fixture
def sample_us_states() -> list[USState]:
    """Create sample US states for testing."""
    return [
        USState(
            code="CA",
            name="California",
            display_name="California",
            fips_code="06",
            abbreviation="CA",
            capital="Sacramento",
            population=39538223,
            area_km2=423970,
            bbox_north=42.009518,
            bbox_south=32.534156,
            bbox_east=-114.131211,
            bbox_west=-124.409591,
            center_lat=36.116203,
            center_lon=-119.681564,
        ),
        USState(
            code="NY",
            name="New York",
            display_name="New York",
            fips_code="36",
            abbreviation="NY",
            capital="Albany",
            population=19453561,
            area_km2=141297,
            bbox_north=45.015865,
            bbox_south=40.477399,
            bbox_east=-71.777491,
            bbox_west=-79.762152,
            center_lat=42.165726,
            center_lon=-74.948051,
        ),
    ]


@pytest.fixture
def dynamodb_table_config() -> dict[str, Any]:
    """DynamoDB table configuration for testing."""
    return {
        "TableName": "test-table",
        "KeySchema": [
            {"AttributeName": "pk", "KeyType": "HASH"},
            {"AttributeName": "sk", "KeyType": "RANGE"},
        ],
        "AttributeDefinitions": [
            {"AttributeName": "pk", "AttributeType": "S"},
            {"AttributeName": "sk", "AttributeType": "S"},
        ],
        "BillingMode": "PAY_PER_REQUEST",
    }


@pytest.fixture
def dynamodb_client(mock_aws_services):
    """Create a mocked DynamoDB client."""
    return boto3.client("dynamodb", region_name="us-east-1")


@pytest.fixture
def dynamodb_resource(mock_aws_services):
    """Create a mocked DynamoDB resource."""
    return boto3.resource("dynamodb", region_name="us-east-1")


@pytest.fixture
def s3_client(mock_aws_services):
    """Create a mocked S3 client."""
    return boto3.client("s3", region_name="us-east-1")


@pytest.fixture
def test_bucket_name() -> str:
    """Test S3 bucket name."""
    return "test-skratch-bucket"


# Test data constants
TEST_USER_ID = "test-user-123"
TEST_APPLE_ID = "apple-user-456"
TEST_EMAIL = "test@example.com"

# Geographic test data
TEST_COUNTRIES = ["US", "CA", "GB", "FR", "DE", "JP", "AU"]
TEST_US_STATES = ["CA", "NY", "TX", "FL", "WA", "IL", "PA"]
TEST_CANADIAN_PROVINCES = ["BC", "ON", "QC", "AB", "NS", "MB", "SK"]
