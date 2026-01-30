"""Tests for places API routes."""

from unittest.mock import patch

import pytest
from fastapi.testclient import TestClient

from src.api.main import app
from src.api.routes.auth import get_current_user


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


class TestListPlaces:
    """Tests for GET /places endpoint."""

    def test_list_places_empty(self, client, mock_db_service):
        """Test listing places when user has none."""
        mock_db_service.get_user_visited_places.return_value = []

        response = client.get(
            "/places",
            headers={"Authorization": "Bearer test-token"},
        )

        assert response.status_code == 200
        data = response.json()
        assert data["places"] == []
        assert data["total"] == 0

    def test_list_places_with_data(self, client, mock_db_service):
        """Test listing places with existing data."""
        mock_db_service.get_user_visited_places.return_value = [
            {
                "user_id": "test-user-123",
                "region_type": "country",
                "region_code": "US",
                "region_name": "United States",
                "created_at": "2024-01-01T00:00:00",
                "sync_version": 1,
                "is_deleted": False,
            },
            {
                "user_id": "test-user-123",
                "region_type": "country",
                "region_code": "FR",
                "region_name": "France",
                "created_at": "2024-01-02T00:00:00",
                "sync_version": 1,
                "is_deleted": False,
            },
        ]

        response = client.get(
            "/places",
            headers={"Authorization": "Bearer test-token"},
        )

        assert response.status_code == 200
        data = response.json()
        assert len(data["places"]) == 2
        assert data["total"] == 2
        assert data["places"][0]["region_code"] == "US"
        assert data["places"][1]["region_code"] == "FR"

    def test_list_places_excludes_deleted(self, client, mock_db_service):
        """Test that deleted places are excluded from list."""
        # Mock returns only non-deleted places (simulating database filtering)
        mock_db_service.get_user_visited_places.return_value = [
            {
                "user_id": "test-user-123",
                "region_type": "country",
                "region_code": "US",
                "region_name": "United States",
                "created_at": "2024-01-01T00:00:00",
                "sync_version": 1,
                "is_deleted": False,
            },
        ]

        response = client.get(
            "/places",
            headers={"Authorization": "Bearer test-token"},
        )

        assert response.status_code == 200
        data = response.json()
        assert len(data["places"]) == 1
        assert data["places"][0]["region_code"] == "US"

    def test_list_places_filter_by_type(self, client, mock_db_service):
        """Test filtering places by region type."""
        mock_db_service.get_user_visited_places.return_value = [
            {
                "user_id": "test-user-123",
                "region_type": "us_state",
                "region_code": "CA",
                "region_name": "California",
                "created_at": "2024-01-01T00:00:00",
                "sync_version": 1,
                "is_deleted": False,
            },
        ]

        response = client.get(
            "/places?region_type=us_state",
            headers={"Authorization": "Bearer test-token"},
        )

        assert response.status_code == 200
        # Check that the service was called with correct parameters
        call_args = mock_db_service.get_user_visited_places.call_args
        assert call_args[0][1] == "us_state"  # region_type parameter


class TestCreatePlace:
    """Tests for POST /places endpoint."""

    def test_create_place_success(self, client, mock_db_service):
        """Test successfully creating a visited place."""
        mock_db_service.get_visited_place.return_value = None
        mock_db_service.create_visited_place.return_value = {
            "user_id": "test-user-123",
            "region_type": "country",
            "region_code": "JP",
            "region_name": "Japan",
            "created_at": "2024-01-01T00:00:00",
            "sync_version": 1,
            "is_deleted": False,
        }

        response = client.post(
            "/places",
            headers={"Authorization": "Bearer test-token"},
            json={
                "region_type": "country",
                "region_code": "JP",
                "region_name": "Japan",
            },
        )

        assert response.status_code == 201
        data = response.json()
        assert data["region_code"] == "JP"
        assert data["region_name"] == "Japan"

    def test_create_place_already_exists(self, client, mock_db_service):
        """Test creating a place that already exists."""
        mock_db_service.get_visited_place.return_value = {
            "user_id": "test-user-123",
            "region_type": "country",
            "region_code": "JP",
            "region_name": "Japan",
            "is_deleted": False,
        }

        response = client.post(
            "/places",
            headers={"Authorization": "Bearer test-token"},
            json={
                "region_type": "country",
                "region_code": "JP",
                "region_name": "Japan",
            },
        )

        assert response.status_code == 409
        assert "Place already exists" in response.json()["detail"]

    def test_create_place_restores_deleted(self, client, mock_db_service):
        """Test that creating a soft-deleted place restores it."""
        mock_db_service.get_visited_place.return_value = {
            "user_id": "test-user-123",
            "region_type": "country",
            "region_code": "JP",
            "region_name": "Japan",
            "is_deleted": True,  # Was soft-deleted
        }
        mock_db_service.create_visited_place.return_value = {
            "user_id": "test-user-123",
            "region_type": "country",
            "region_code": "JP",
            "region_name": "Japan",
            "status": "visited",
            "visit_type": "visited",
            "visited_date": None,
            "departure_date": None,
            "notes": None,
            "created_at": "2024-01-01T00:00:00",
            "sync_version": 1,
            "is_deleted": False,
        }

        response = client.post(
            "/places",
            headers={"Authorization": "Bearer test-token"},
            json={
                "region_type": "country",
                "region_code": "JP",
                "region_name": "Japan",
                "status": "visited",
                "visit_type": "visited",
            },
        )

        assert response.status_code == 201
        mock_db_service.create_visited_place.assert_called_once()


class TestGetPlace:
    """Tests for GET /places/{region_type}/{region_code} endpoint."""

    def test_get_place_success(self, client, mock_db_service):
        """Test getting a specific visited place."""
        mock_db_service.get_visited_place.return_value = {
            "user_id": "test-user-123",
            "region_type": "us_state",
            "region_code": "CA",
            "region_name": "California",
            "created_at": "2024-01-01T00:00:00",
            "sync_version": 1,
            "is_deleted": False,
        }

        response = client.get(
            "/places/us_state/CA",
            headers={"Authorization": "Bearer test-token"},
        )

        assert response.status_code == 200
        data = response.json()
        assert data["region_code"] == "CA"
        assert data["region_type"] == "us_state"

    def test_get_place_not_found(self, client, mock_db_service):
        """Test getting a place that doesn't exist."""
        mock_db_service.get_visited_place.return_value = None

        response = client.get(
            "/places/country/ZZ",
            headers={"Authorization": "Bearer test-token"},
        )

        assert response.status_code == 404

    def test_get_place_deleted(self, client, mock_db_service):
        """Test getting a soft-deleted place returns 404."""
        mock_db_service.get_visited_place.return_value = {
            "user_id": "test-user-123",
            "region_type": "country",
            "region_code": "JP",
            "is_deleted": True,
        }

        response = client.get(
            "/places/country/JP",
            headers={"Authorization": "Bearer test-token"},
        )

        assert response.status_code == 404


class TestDeletePlace:
    """Tests for DELETE /places/{region_type}/{region_code} endpoint."""

    def test_delete_place_success(self, client, mock_db_service):
        """Test successfully deleting a visited place."""
        mock_db_service.get_visited_place.return_value = {
            "user_id": "test-user-123",
            "region_type": "country",
            "region_code": "JP",
            "is_deleted": False,
        }
        mock_db_service.delete_visited_place.return_value = True

        response = client.delete(
            "/places/country/JP",
            headers={"Authorization": "Bearer test-token"},
        )

        assert response.status_code == 204

    def test_delete_place_not_found(self, client, mock_db_service):
        """Test deleting a place that doesn't exist."""
        mock_db_service.get_visited_place.return_value = None

        response = client.delete(
            "/places/country/ZZ",
            headers={"Authorization": "Bearer test-token"},
        )

        assert response.status_code == 404


class TestPlaceStats:
    """Tests for GET /places/stats endpoint."""

    def test_get_stats(self, client, mock_db_service):
        """Test getting place statistics."""
        mock_db_service.get_user_visited_places.return_value = [
            {"region_type": "country", "status": "visited", "is_deleted": False},
            {"region_type": "country", "status": "visited", "is_deleted": False},
            {"region_type": "us_state", "status": "visited", "is_deleted": False},
            {
                "region_type": "canadian_province",
                "status": "visited",
                "is_deleted": False,
            },
            {"region_type": "country", "is_deleted": True},  # Should be excluded
        ]

        response = client.get(
            "/places/stats",
            headers={"Authorization": "Bearer test-token"},
        )

        assert response.status_code == 200
        data = response.json()
        assert data["countries_visited"] == 3
        assert data["us_states_visited"] == 1
        assert data["canadian_provinces_visited"] == 1
        assert data["total_regions_visited"] == 5
        assert data["countries_total"] == 195
        assert data["us_states_total"] == 51
        assert data["canadian_provinces_total"] == 13

    def test_get_stats_with_bucket_list(self, client, mock_db_service):
        """Test getting place statistics including bucket list items."""
        mock_db_service.get_user_visited_places.return_value = [
            {"region_type": "country", "status": "visited", "is_deleted": False},
            {"region_type": "country", "status": "bucket_list", "is_deleted": False},
            {"region_type": "country", "status": "bucket_list", "is_deleted": False},
            {"region_type": "us_state", "status": "visited", "is_deleted": False},
            {"region_type": "us_state", "status": "bucket_list", "is_deleted": False},
            {
                "region_type": "canadian_province",
                "status": "visited",
                "is_deleted": False,
            },
        ]

        response = client.get(
            "/places/stats",
            headers={"Authorization": "Bearer test-token"},
        )

        assert response.status_code == 200
        data = response.json()
        # Visited counts
        assert data["countries_visited"] == 1
        assert data["us_states_visited"] == 1
        assert data["canadian_provinces_visited"] == 1
        assert data["total_regions_visited"] == 3
        # Bucket list counts
        assert data["countries_bucket_list"] == 2
        assert data["us_states_bucket_list"] == 1
        assert data["canadian_provinces_bucket_list"] == 0
        assert data["total_bucket_list"] == 3


class TestBucketList:
    """Tests for bucket list functionality."""

    def test_create_bucket_list_place(self, client, mock_db_service):
        """Test creating a place with bucket_list status."""
        mock_db_service.get_visited_place.return_value = None
        mock_db_service.create_visited_place.return_value = {
            "user_id": "test-user-123",
            "region_type": "country",
            "region_code": "JP",
            "region_name": "Japan",
            "status": "bucket_list",
            "created_at": "2024-01-01T00:00:00",
            "sync_version": 1,
            "is_deleted": False,
        }

        response = client.post(
            "/places",
            headers={"Authorization": "Bearer test-token"},
            json={
                "region_type": "country",
                "region_code": "JP",
                "region_name": "Japan",
                "status": "bucket_list",
            },
        )

        assert response.status_code == 201
        data = response.json()
        assert data["region_code"] == "JP"
        assert data["status"] == "bucket_list"

    def test_update_status_to_bucket_list(self, client, mock_db_service):
        """Test updating a place status to bucket_list."""
        mock_db_service.get_visited_place.return_value = {
            "user_id": "test-user-123",
            "region_type": "country",
            "region_code": "JP",
            "region_name": "Japan",
            "status": "visited",
            "sync_version": 1,
            "is_deleted": False,
        }
        mock_db_service.update_visited_place.return_value = {
            "user_id": "test-user-123",
            "region_type": "country",
            "region_code": "JP",
            "region_name": "Japan",
            "status": "bucket_list",
            "created_at": "2024-01-01T00:00:00",
            "sync_version": 2,
            "is_deleted": False,
        }

        response = client.patch(
            "/places/country/JP",
            headers={"Authorization": "Bearer test-token"},
            json={"status": "bucket_list"},
        )

        assert response.status_code == 200
        data = response.json()
        assert data["status"] == "bucket_list"

    def test_update_status_to_visited(self, client, mock_db_service):
        """Test updating a place status from bucket_list to visited."""
        mock_db_service.get_visited_place.return_value = {
            "user_id": "test-user-123",
            "region_type": "country",
            "region_code": "JP",
            "region_name": "Japan",
            "status": "bucket_list",
            "sync_version": 1,
            "is_deleted": False,
        }
        mock_db_service.update_visited_place.return_value = {
            "user_id": "test-user-123",
            "region_type": "country",
            "region_code": "JP",
            "region_name": "Japan",
            "status": "visited",
            "created_at": "2024-01-01T00:00:00",
            "sync_version": 2,
            "is_deleted": False,
        }

        response = client.patch(
            "/places/country/JP",
            headers={"Authorization": "Bearer test-token"},
            json={"status": "visited"},
        )

        assert response.status_code == 200
        data = response.json()
        assert data["status"] == "visited"

    def test_list_places_filter_by_status(self, client, mock_db_service):
        """Test filtering places by status."""
        # Mock to return only bucket_list items when status=bucket_list is requested
        mock_db_service.get_user_visited_places.return_value = [
            {
                "user_id": "test-user-123",
                "region_type": "country",
                "region_code": "JP",
                "region_name": "Japan",
                "status": "bucket_list",
                "created_at": "2024-01-02T00:00:00",
                "sync_version": 1,
                "is_deleted": False,
            },
        ]

        # Filter to bucket_list only
        response = client.get(
            "/places?status=bucket_list",
            headers={"Authorization": "Bearer test-token"},
        )

        assert response.status_code == 200
        data = response.json()
        assert len(data["places"]) == 1
        assert data["places"][0]["status"] == "bucket_list"
        assert data["places"][0]["region_code"] == "JP"
        assert data["places"][0]["status"] == "bucket_list"

    def test_default_status_is_visited(self, client, mock_db_service):
        """Test that default status for a new place is 'visited'."""
        mock_db_service.get_visited_place.return_value = None
        mock_db_service.create_visited_place.return_value = {
            "user_id": "test-user-123",
            "region_type": "country",
            "region_code": "AU",
            "region_name": "Australia",
            "status": "visited",
            "created_at": "2024-01-01T00:00:00",
            "sync_version": 1,
            "is_deleted": False,
        }

        response = client.post(
            "/places",
            headers={"Authorization": "Bearer test-token"},
            json={
                "region_type": "country",
                "region_code": "AU",
                "region_name": "Australia",
                # status not specified - should default to visited
            },
        )

        assert response.status_code == 201
        # Verify the call included "visited" status
        call_args = mock_db_service.create_visited_place.call_args
        assert call_args[0][3]["status"] == "visited"


class TestBatchCreate:
    """Tests for POST /places/batch endpoint."""

    def test_batch_create_success(self, client, mock_db_service):
        """Test batch creating multiple places."""
        # Mock that places don't exist
        mock_db_service.get_visited_place.return_value = None

        # Mock creation returns
        mock_db_service.create_visited_place.side_effect = [
            {
                "user_id": "test-user-123",
                "region_type": "country",
                "region_code": "DE",
                "region_name": "Germany",
                "status": "visited",
                "visit_type": "visited",
                "visited_date": None,
                "departure_date": None,
                "notes": None,
                "created_at": "2024-01-01T00:00:00",
                "sync_version": 1,
                "is_deleted": False,
            },
            {
                "user_id": "test-user-123",
                "region_type": "country",
                "region_code": "IT",
                "region_name": "Italy",
                "status": "visited",
                "visit_type": "visited",
                "visited_date": None,
                "departure_date": None,
                "notes": None,
                "created_at": "2024-01-01T00:00:00",
                "sync_version": 1,
                "is_deleted": False,
            },
        ]

        response = client.post(
            "/places/batch",
            headers={"Authorization": "Bearer test-token"},
            json={
                "places": [
                    {
                        "region_type": "country",
                        "region_code": "DE",
                        "region_name": "Germany",
                        "status": "visited",
                        "visit_type": "visited",
                    },
                    {
                        "region_type": "country",
                        "region_code": "IT",
                        "region_name": "Italy",
                        "status": "visited",
                        "visit_type": "visited",
                    },
                ]
            },
        )

        assert response.status_code == 200
        data = response.json()
        assert data["created"] == 2
        assert len(data["places"]) == 2

    def test_batch_create_with_bucket_list(self, client, mock_db_service):
        """Test batch creating places with mixed statuses."""
        # Mock that places don't exist
        mock_db_service.get_visited_place.return_value = None

        # Mock creation returns
        mock_db_service.create_visited_place.side_effect = [
            {
                "user_id": "test-user-123",
                "region_type": "country",
                "region_code": "DE",
                "region_name": "Germany",
                "status": "visited",
                "visit_type": "visited",
                "visited_date": None,
                "departure_date": None,
                "notes": None,
                "created_at": "2024-01-01T00:00:00",
                "sync_version": 1,
                "is_deleted": False,
            },
            {
                "user_id": "test-user-123",
                "region_type": "country",
                "region_code": "PT",
                "region_name": "Portugal",
                "status": "bucket_list",
                "visit_type": "visited",
                "visited_date": None,
                "departure_date": None,
                "notes": None,
                "created_at": "2024-01-01T00:00:00",
                "sync_version": 1,
                "is_deleted": False,
            },
        ]

        response = client.post(
            "/places/batch",
            headers={"Authorization": "Bearer test-token"},
            json={
                "places": [
                    {
                        "region_type": "country",
                        "region_code": "DE",
                        "region_name": "Germany",
                        "status": "visited",
                        "visit_type": "visited",
                    },
                    {
                        "region_type": "country",
                        "region_code": "PT",
                        "region_name": "Portugal",
                        "status": "bucket_list",
                        "visit_type": "visited",
                    },
                ]
            },
        )

        assert response.status_code == 200
        data = response.json()
        assert data["created"] == 2

        # Check that both places were created with correct statuses
        statuses = {place["status"] for place in data["places"]}
        assert statuses == {"visited", "bucket_list"}
