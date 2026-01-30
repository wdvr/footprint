"""Tests for international places API functionality."""

from unittest.mock import patch

import pytest
from fastapi.testclient import TestClient

from src.api.main import app
from src.api.routes.auth import get_current_user
from src.models.visited_place import RegionType


@pytest.fixture
def mock_user():
    """Mock authenticated user."""
    return {
        "user_id": "test-user-123",
        "email": "test@example.com",
        "display_name": "Test User",
        "countries_visited": 5,
        "us_states_visited": 10,
        "canadian_provinces_visited": 2,
    }


@pytest.fixture
def mock_db_service():
    """Mock DynamoDB service."""
    with patch("src.api.routes.places.db_service") as mock:
        yield mock


@pytest.fixture
def client(mock_user):
    """Create test client with mocked auth."""
    app.dependency_overrides[get_current_user] = lambda: mock_user
    client = TestClient(app)
    yield client
    app.dependency_overrides.clear()


@pytest.fixture
def sample_international_places():
    """Sample international places data."""
    return [
        {
            "user_id": "test-user-123",
            "region_type": "australian_state",
            "region_code": "NSW",
            "region_name": "New South Wales",
            "status": "visited",
            "visit_type": "visited",
            "visited_date": "2023-06-15",
            "notes": "Amazing Sydney harbor",
            "marked_at": "2023-06-20T10:00:00Z",
            "sync_version": 1,
            "is_deleted": False,
        },
        {
            "user_id": "test-user-123",
            "region_type": "mexican_state",
            "region_code": "YUC",
            "region_name": "Yucatán",
            "status": "bucket_list",
            "visit_type": "visited",
            "notes": "Want to see Chichen Itza",
            "marked_at": "2023-07-01T15:30:00Z",
            "sync_version": 1,
            "is_deleted": False,
        },
        {
            "user_id": "test-user-123",
            "region_type": "brazilian_state",
            "region_code": "RJ",
            "region_name": "Rio de Janeiro",
            "status": "visited",
            "visit_type": "visited",
            "visited_date": "2023-08-10",
            "notes": "Layover in Rio",
            "marked_at": "2023-08-12T08:00:00Z",
            "sync_version": 1,
            "is_deleted": False,
        },
    ]


class TestInternationalPlacesAPI:
    """Test international places API endpoints."""

    def test_list_places_with_international_regions(
        self, client, mock_db_service, sample_international_places
    ):
        """Test listing places including international regions."""
        mock_db_service.get_user_visited_places.return_value = (
            sample_international_places
        )

        response = client.get("/places/")

        assert response.status_code == 200
        data = response.json()
        assert len(data["places"]) == 3

        # Check international region types are present
        region_types = {place["region_type"] for place in data["places"]}
        expected_types = {"australian_state", "mexican_state", "brazilian_state"}
        assert expected_types.issubset(region_types)

    def test_create_australian_state(self, client, mock_db_service):
        """Test creating an Australian state visit."""
        mock_db_service.get_visited_place.return_value = None  # Doesn't exist
        mock_db_service.create_visited_place.return_value = {
            "user_id": "test-user-123",
            "region_type": "australian_state",
            "region_code": "VIC",
            "region_name": "Victoria",
            "status": "visited",
            "visit_type": "visited",
            "visited_date": "2023-09-15",
            "notes": "Great Ocean Road trip",
            "marked_at": "2023-09-20T12:00:00Z",
            "sync_version": 1,
            "is_deleted": False,
        }

        place_data = {
            "region_type": "australian_state",
            "region_code": "VIC",
            "region_name": "Victoria",
            "status": "visited",
            "visit_type": "visited",
            "visited_date": "2023-09-15",
            "notes": "Great Ocean Road trip",
        }

        response = client.post("/places/", json=place_data)

        assert response.status_code == 201
        data = response.json()
        assert data["region_type"] == "australian_state"
        assert data["region_code"] == "VIC"
        assert data["region_name"] == "Victoria"

    def test_create_mexican_state(self, client, mock_db_service):
        """Test creating a Mexican state visit."""
        mock_db_service.get_visited_place.return_value = None
        mock_db_service.create_visited_place.return_value = {
            "user_id": "test-user-123",
            "region_type": "mexican_state",
            "region_code": "CDMX",
            "region_name": "Ciudad de México",
            "status": "visited",
            "visit_type": "visited",
            "visited_date": "2023-10-05",
            "notes": "Amazing food and culture",
            "marked_at": "2023-10-10T09:30:00Z",
            "sync_version": 1,
            "is_deleted": False,
        }

        place_data = {
            "region_type": "mexican_state",
            "region_code": "CDMX",
            "region_name": "Ciudad de México",
            "status": "visited",
            "visit_type": "visited",
            "visited_date": "2023-10-05",
            "notes": "Amazing food and culture",
        }

        response = client.post("/places/", json=place_data)

        assert response.status_code == 201
        data = response.json()
        assert data["region_type"] == "mexican_state"
        assert data["region_code"] == "CDMX"

    def test_batch_create_international_places(self, client, mock_db_service):
        """Test batch creating international places."""
        mock_db_service.get_visited_place.return_value = None  # None exist

        # Mock batch creation returns
        mock_db_service.create_visited_place.side_effect = [
            {
                "user_id": "test-user-123",
                "region_type": "australian_state",
                "region_code": "QLD",
                "region_name": "Queensland",
                "status": "visited",
                "visit_type": "visited",
                "visited_date": "2023-11-01",
                "notes": "Great Barrier Reef",
                "marked_at": "2023-11-05T14:00:00Z",
                "sync_version": 1,
                "is_deleted": False,
            },
            {
                "user_id": "test-user-123",
                "region_type": "mexican_state",
                "region_code": "JAL",
                "region_name": "Jalisco",
                "status": "visited",
                "visit_type": "visited",
                "visited_date": "2023-11-10",
                "notes": "Guadalajara and tequila",
                "marked_at": "2023-11-15T16:30:00Z",
                "sync_version": 1,
                "is_deleted": False,
            },
        ]

        places_data = {
            "places": [
                {
                    "region_type": "australian_state",
                    "region_code": "QLD",
                    "region_name": "Queensland",
                    "status": "visited",
                    "visit_type": "visited",
                    "visited_date": "2023-11-01",
                    "notes": "Great Barrier Reef",
                },
                {
                    "region_type": "mexican_state",
                    "region_code": "JAL",
                    "region_name": "Jalisco",
                    "status": "visited",
                    "visit_type": "visited",
                    "visited_date": "2023-11-10",
                    "notes": "Guadalajara and tequila",
                },
            ]
        }

        response = client.post("/places/batch", json=places_data)

        assert response.status_code == 200
        data = response.json()
        assert data["created"] == 2
        assert len(data["places"]) == 2

    def test_get_extended_stats_with_international_regions(
        self, client, mock_db_service, sample_international_places
    ):
        """Test getting extended statistics including international regions."""
        mock_db_service.get_user_visited_places.return_value = (
            sample_international_places
        )

        response = client.get("/places/stats")

        assert response.status_code == 200
        data = response.json()

        # Check that international region stats are included
        assert "australian_states_visited" in data
        assert "mexican_states_visited" in data
        assert "brazilian_states_visited" in data
        assert "total_international_regions_visited" in data

        assert data["australian_states_visited"] == 1  # NSW visited
        assert data["mexican_states_visited"] == 0  # YUC is bucket list
        assert data["brazilian_states_visited"] == 1  # RJ visited
        assert data["total_international_regions_visited"] == 2

    def test_filter_by_international_region_type(
        self, client, mock_db_service, sample_international_places
    ):
        """Test filtering places by international region type."""
        # Filter should only return Australian states
        australian_places = [
            p
            for p in sample_international_places
            if p["region_type"] == "australian_state"
        ]
        mock_db_service.get_user_visited_places.return_value = australian_places

        response = client.get("/places/?region_type=australian_state")

        assert response.status_code == 200
        data = response.json()
        assert data["total"] == 1
        assert data["places"][0]["region_type"] == "australian_state"
        assert data["places"][0]["region_code"] == "NSW"

    def test_get_specific_international_place(
        self, client, mock_db_service, sample_international_places
    ):
        """Test getting a specific international place."""
        mock_db_service.get_visited_place.return_value = sample_international_places[
            0
        ]  # NSW

        response = client.get("/places/australian_state/NSW")

        assert response.status_code == 200
        data = response.json()
        assert data["region_type"] == "australian_state"
        assert data["region_code"] == "NSW"
        assert data["region_name"] == "New South Wales"

    def test_update_international_place(
        self, client, mock_db_service, sample_international_places
    ):
        """Test updating an international place."""
        # Original place
        original_place = sample_international_places[1].copy()  # YUC bucket list
        mock_db_service.get_visited_place.return_value = original_place

        # Updated place
        updated_place = original_place.copy()
        updated_place["status"] = "visited"
        updated_place["notes"] = "Want to see Chichen Itza - Actually went!"
        mock_db_service.update_visited_place.return_value = updated_place

        update_data = {
            "status": "visited",
            "notes": "Want to see Chichen Itza - Actually went!",
        }

        response = client.patch("/places/mexican_state/YUC", json=update_data)

        assert response.status_code == 200
        data = response.json()
        assert data["status"] == "visited"
        assert "Chichen Itza" in data["notes"]

    def test_delete_international_place(
        self, client, mock_db_service, sample_international_places
    ):
        """Test deleting an international place."""
        mock_db_service.get_visited_place.return_value = sample_international_places[
            0
        ]  # NSW
        mock_db_service.delete_visited_place.return_value = None

        response = client.delete("/places/australian_state/NSW")

        assert response.status_code == 204
        mock_db_service.delete_visited_place.assert_called_once()


class TestInternationalRegionValidation:
    """Test validation for international region data."""

    def test_invalid_region_type(self, client, mock_db_service):
        """Test creating place with invalid region type."""
        place_data = {
            "region_type": "invalid_region",  # Invalid
            "region_code": "TEST",
            "region_name": "Test Region",
            "status": "visited",
            "visit_type": "visited",
            "visited_date": "2023-12-01",
        }

        response = client.post("/places/", json=place_data)

        assert response.status_code == 422
        data = response.json()
        assert "detail" in data
        # Should contain validation error about invalid region type

    def test_region_type_enum_values(self):
        """Test that RegionType enum contains expected international values."""
        region_types = [rt.value for rt in RegionType]

        # Check that international region types are included
        expected_international = {
            "australian_state",
            "mexican_state",
            "brazilian_state",
        }

        for region_type in expected_international:
            assert region_type in region_types
