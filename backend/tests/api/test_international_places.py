"""Tests for international places API functionality."""

from unittest.mock import patch

import pytest
from fastapi.testclient import TestClient

from src.api.main import app
from src.models.visited_place import RegionType

client = TestClient(app)


@pytest.fixture
def mock_user():
    """Mock authenticated user."""
    return "test-user-123"


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
            "visit_type": "transit",
            "visited_date": "2023-08-10",
            "notes": "Layover in Rio",
            "marked_at": "2023-08-12T08:00:00Z",
            "sync_version": 1,
            "is_deleted": False,
        },
    ]


class TestInternationalPlacesAPI:
    """Test international places API endpoints."""

    @patch("src.api.routes.places.get_current_user")
    @patch("src.api.routes.places.db_service")
    def test_list_places_with_international_regions(
        self, mock_db, mock_auth, sample_international_places
    ):
        """Test listing places including international regions."""
        mock_auth.return_value = "test-user-123"
        mock_db.get_user_visited_places.return_value = sample_international_places

        response = client.get("/places/")

        assert response.status_code == 200
        data = response.json()
        assert data["total"] == 3
        assert len(data["places"]) == 3

        # Check international region types are present
        region_types = {place["region_type"] for place in data["places"]}
        expected_types = {"australian_state", "mexican_state", "brazilian_state"}
        assert expected_types.issubset(region_types)

    @patch("src.api.routes.places.get_current_user")
    @patch("src.api.routes.places.db_service")
    def test_create_australian_state(self, mock_db, mock_auth):
        """Test creating an Australian state visit."""
        mock_auth.return_value = "test-user-123"
        mock_db.get_visited_place.return_value = None  # Doesn't exist
        mock_db.create_visited_place.return_value = {
            "user_id": "test-user-123",
            "region_type": "australian_state",
            "region_code": "VIC",
            "region_name": "Victoria",
            "status": "visited",
            "visit_type": "visited",
            "marked_at": "2023-09-01T12:00:00Z",
            "sync_version": 1,
            "is_deleted": False,
        }

        place_data = {
            "region_type": "australian_state",
            "region_code": "VIC",
            "region_name": "Victoria",
            "status": "visited",
            "visit_type": "visited",
            "notes": "Melbourne coffee culture is amazing",
        }

        response = client.post("/places/", json=place_data)

        assert response.status_code == 201
        data = response.json()
        assert data["region_type"] == "australian_state"
        assert data["region_code"] == "VIC"
        assert data["region_name"] == "Victoria"

    @patch("src.api.routes.places.get_current_user")
    @patch("src.api.routes.places.db_service")
    def test_create_mexican_state(self, mock_db, mock_auth):
        """Test creating a Mexican state visit."""
        mock_auth.return_value = "test-user-123"
        mock_db.get_visited_place.return_value = None
        mock_db.create_visited_place.return_value = {
            "user_id": "test-user-123",
            "region_type": "mexican_state",
            "region_code": "CDMX",
            "region_name": "Ciudad de México",
            "status": "visited",
            "visit_type": "visited",
            "marked_at": "2023-09-15T14:30:00Z",
            "sync_version": 1,
            "is_deleted": False,
        }

        place_data = {
            "region_type": "mexican_state",
            "region_code": "CDMX",
            "region_name": "Ciudad de México",
            "status": "visited",
            "visit_type": "visited",
        }

        response = client.post("/places/", json=place_data)

        assert response.status_code == 201
        data = response.json()
        assert data["region_type"] == "mexican_state"
        assert data["region_code"] == "CDMX"

    @patch("src.api.routes.places.get_current_user")
    @patch("src.api.routes.places.db_service")
    def test_batch_create_international_places(self, mock_db, mock_auth):
        """Test batch creating international places."""
        mock_auth.return_value = "test-user-123"
        mock_db.get_visited_place.return_value = None  # None exist

        # Mock batch creation returns
        mock_db.create_visited_place.side_effect = [
            {
                "user_id": "test-user-123",
                "region_type": "australian_state",
                "region_code": "QLD",
                "region_name": "Queensland",
                "status": "visited",
                "visit_type": "visited",
                "marked_at": "2023-10-01T10:00:00Z",
                "sync_version": 1,
                "is_deleted": False,
            },
            {
                "user_id": "test-user-123",
                "region_type": "brazilian_state",
                "region_code": "SP",
                "region_name": "São Paulo",
                "status": "bucket_list",
                "visit_type": "visited",
                "marked_at": "2023-10-01T10:01:00Z",
                "sync_version": 1,
                "is_deleted": False,
            },
        ]

        batch_data = {
            "places": [
                {
                    "region_type": "australian_state",
                    "region_code": "QLD",
                    "region_name": "Queensland",
                    "status": "visited",
                    "visit_type": "visited",
                },
                {
                    "region_type": "brazilian_state",
                    "region_code": "SP",
                    "region_name": "São Paulo",
                    "status": "bucket_list",
                    "visit_type": "visited",
                },
            ]
        }

        response = client.post("/places/batch", json=batch_data)

        assert response.status_code == 200
        data = response.json()
        assert data["created"] == 2
        assert len(data["places"]) == 2

    @patch("src.api.routes.places.get_current_user")
    @patch("src.api.routes.places.db_service")
    def test_get_extended_stats_with_international_regions(
        self, mock_db, mock_auth, sample_international_places
    ):
        """Test getting extended statistics including international regions."""
        mock_auth.return_value = "test-user-123"
        mock_db.get_user_visited_places.return_value = sample_international_places

        response = client.get("/places/stats")

        assert response.status_code == 200
        data = response.json()

        # Check original stats fields exist
        assert "countries_visited" in data
        assert "us_states_visited" in data
        assert "canadian_provinces_visited" in data

        # Check new international stats fields
        assert "australian_states_visited" in data
        assert "mexican_states_visited" in data
        assert "brazilian_states_visited" in data
        assert "german_states_visited" in data
        assert "indian_states_visited" in data
        assert "chinese_provinces_visited" in data

        # Check totals
        assert "total_international_regions_visited" in data
        assert "total_international_regions_available" in data

        # Verify calculations based on sample data
        assert data["australian_states_visited"] == 1  # NSW visited
        assert data["mexican_states_visited"] == 0  # YUC is bucket list
        assert data["brazilian_states_visited"] == 1  # RJ visited
        assert data["total_international_regions_visited"] == 2

    @patch("src.api.routes.places.get_current_user")
    @patch("src.api.routes.places.db_service")
    def test_filter_by_international_region_type(
        self, mock_db, mock_auth, sample_international_places
    ):
        """Test filtering places by international region type."""
        mock_auth.return_value = "test-user-123"

        # Filter should only return Australian states
        australian_places = [
            p
            for p in sample_international_places
            if p["region_type"] == "australian_state"
        ]
        mock_db.get_user_visited_places.return_value = australian_places

        response = client.get("/places/?region_type=australian_state")

        assert response.status_code == 200
        data = response.json()
        assert data["total"] == 1
        assert data["places"][0]["region_type"] == "australian_state"
        assert data["places"][0]["region_code"] == "NSW"

    @patch("src.api.routes.places.get_current_user")
    @patch("src.api.routes.places.db_service")
    def test_get_specific_international_place(
        self, mock_db, mock_auth, sample_international_places
    ):
        """Test getting a specific international place."""
        mock_auth.return_value = "test-user-123"
        mock_db.get_visited_place.return_value = sample_international_places[0]  # NSW

        response = client.get("/places/australian_state/NSW")

        assert response.status_code == 200
        data = response.json()
        assert data["region_type"] == "australian_state"
        assert data["region_code"] == "NSW"
        assert data["region_name"] == "New South Wales"

    @patch("src.api.routes.places.get_current_user")
    @patch("src.api.routes.places.db_service")
    def test_update_international_place(
        self, mock_db, mock_auth, sample_international_places
    ):
        """Test updating an international place."""
        mock_auth.return_value = "test-user-123"

        # Original place
        original_place = sample_international_places[1].copy()  # YUC bucket list
        mock_db.get_visited_place.return_value = original_place

        # Updated place
        updated_place = original_place.copy()
        updated_place["status"] = "visited"
        updated_place["notes"] = "Finally visited Chichen Itza!"
        mock_db.update_visited_place.return_value = updated_place

        update_data = {"status": "visited", "notes": "Finally visited Chichen Itza!"}

        response = client.patch("/places/mexican_state/YUC", json=update_data)

        assert response.status_code == 200
        data = response.json()
        assert data["status"] == "visited"
        assert "Chichen Itza" in data["notes"]

    @patch("src.api.routes.places.get_current_user")
    @patch("src.api.routes.places.db_service")
    def test_delete_international_place(
        self, mock_db, mock_auth, sample_international_places
    ):
        """Test deleting an international place."""
        mock_auth.return_value = "test-user-123"
        mock_db.get_visited_place.return_value = sample_international_places[0]  # NSW
        mock_db.delete_visited_place.return_value = None

        response = client.delete("/places/australian_state/NSW")

        assert response.status_code == 204
        mock_db.delete_visited_place.assert_called_once_with(
            "test-user-123", "australian_state", "NSW"
        )


class TestInternationalRegionValidation:
    """Test validation for international region data."""

    @patch("src.api.routes.places.get_current_user")
    def test_invalid_region_type(self, mock_auth):
        """Test creating place with invalid region type."""
        mock_auth.return_value = "test-user-123"

        place_data = {
            "region_type": "invalid_region",  # Invalid
            "region_code": "TEST",
            "region_name": "Test Region",
            "status": "visited",
            "visit_type": "visited",
        }

        response = client.post("/places/", json=place_data)

        # Should fail validation
        assert response.status_code == 422

    def test_region_type_enum_values(self):
        """Test that all international region types are valid enum values."""
        international_types = [
            "australian_state",
            "mexican_state",
            "brazilian_state",
            "german_state",
            "indian_state",
            "chinese_province",
        ]

        for region_type in international_types:
            assert hasattr(RegionType, region_type.upper())
            assert getattr(RegionType, region_type.upper()) == region_type
