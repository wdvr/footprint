"""Tests for sync API routes."""

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
        "sync_version": 5,
        "last_sync_at": "2024-01-01T00:00:00",
        "last_sync_device": "device-old",
    }


@pytest.fixture
def mock_db_service():
    """Mock DynamoDB service."""
    with patch("src.api.routes.sync.db_service") as mock:
        yield mock


@pytest.fixture
def client(mock_user):
    """Create test client with mocked auth."""
    app.dependency_overrides[get_current_user] = lambda: mock_user
    client = TestClient(app)
    yield client
    app.dependency_overrides.clear()


class TestSyncData:
    """Tests for POST /sync endpoint."""

    def test_sync_empty_operations(self, client, mock_db_service):
        """Test sync with no operations."""
        mock_db_service.get_changes_since.return_value = []
        mock_db_service.update_user.return_value = None

        response = client.post(
            "/sync",
            headers={"Authorization": "Bearer test-token"},
            json={
                "device_id": "test-device-123",
                "last_sync_version": 5,
                "operations": [],
            },
        )

        assert response.status_code == 200
        data = response.json()
        assert data["success"] is True
        assert data["new_sync_version"] == 6
        assert data["server_operations"] == []
        assert data["conflicts"] == []
        assert data["errors"] == []
        assert "sync_timestamp" in data

    def test_sync_with_server_changes(self, client, mock_db_service):
        """Test sync returns server changes since last sync."""
        mock_db_service.get_changes_since.return_value = [
            {
                "region_type": "country",
                "region_code": "US",
                "region_name": "United States",
                "sync_version": 3,
                "is_deleted": False,
            },
            {
                "region_type": "country",
                "region_code": "GB",
                "region_name": "United Kingdom",
                "sync_version": 4,
                "is_deleted": True,
            },
        ]
        mock_db_service.update_user.return_value = None

        response = client.post(
            "/sync",
            headers={"Authorization": "Bearer test-token"},
            json={
                "device_id": "test-device-123",
                "last_sync_version": 2,
                "operations": [],
            },
        )

        assert response.status_code == 200
        data = response.json()
        assert len(data["server_operations"]) == 2

        # First operation is update
        assert data["server_operations"][0]["operation_type"] == "update"
        assert data["server_operations"][0]["entity_id"] == "country#US"

        # Second operation is delete
        assert data["server_operations"][1]["operation_type"] == "delete"
        assert data["server_operations"][1]["entity_id"] == "country#GB"

    def test_sync_create_operation(self, client, mock_db_service):
        """Test sync with create operation."""
        mock_db_service.get_visited_place.return_value = None
        mock_db_service.create_visited_place.return_value = {}
        mock_db_service.get_changes_since.return_value = []
        mock_db_service.update_user.return_value = None

        response = client.post(
            "/sync",
            headers={"Authorization": "Bearer test-token"},
            json={
                "device_id": "test-device-123",
                "last_sync_version": 5,
                "operations": [
                    {
                        "operation_id": "op-1",
                        "operation_type": "create",
                        "entity_type": "visited_place",
                        "entity_id": "country#JP",
                        "entity_data": {
                            "region_name": "Japan",
                            "visited_date": "2024-01-15",
                        },
                        "client_version": 5,
                        "client_timestamp": "2024-01-15T10:00:00",
                    }
                ],
            },
        )

        assert response.status_code == 200
        data = response.json()
        assert data["success"] is True
        mock_db_service.create_visited_place.assert_called_once()

    def test_sync_create_conflict_exists(self, client, mock_db_service):
        """Test sync create operation with existing place conflicts."""
        mock_db_service.get_visited_place.return_value = {
            "region_type": "country",
            "region_code": "JP",
            "region_name": "Japan",
            "sync_version": 10,  # Server version is higher
            "is_deleted": False,
        }
        mock_db_service.get_changes_since.return_value = []
        mock_db_service.update_user.return_value = None

        response = client.post(
            "/sync",
            headers={"Authorization": "Bearer test-token"},
            json={
                "device_id": "test-device-123",
                "last_sync_version": 5,
                "operations": [
                    {
                        "operation_id": "op-1",
                        "operation_type": "create",
                        "entity_type": "visited_place",
                        "entity_id": "country#JP",
                        "entity_data": {"region_name": "Japan"},
                        "client_version": 5,
                        "client_timestamp": "2024-01-15T10:00:00",
                    }
                ],
            },
        )

        assert response.status_code == 200
        data = response.json()
        assert len(data["conflicts"]) == 1
        assert data["conflicts"][0]["conflict_type"] == "create_exists"
        assert data["conflicts"][0]["suggested_resolution"] == "server_wins"

    def test_sync_update_operation(self, client, mock_db_service):
        """Test sync with update operation."""
        mock_db_service.get_visited_place.return_value = {
            "region_type": "country",
            "region_code": "JP",
            "region_name": "Japan",
            "sync_version": 5,
            "is_deleted": False,
        }
        mock_db_service.update_visited_place.return_value = {}
        mock_db_service.get_changes_since.return_value = []
        mock_db_service.update_user.return_value = None

        response = client.post(
            "/sync",
            headers={"Authorization": "Bearer test-token"},
            json={
                "device_id": "test-device-123",
                "last_sync_version": 5,
                "operations": [
                    {
                        "operation_id": "op-1",
                        "operation_type": "update",
                        "entity_type": "visited_place",
                        "entity_id": "country#JP",
                        "entity_data": {
                            "notes": "Great trip!",
                        },
                        "client_version": 5,
                        "client_timestamp": "2024-01-15T10:00:00",
                    }
                ],
            },
        )

        assert response.status_code == 200
        data = response.json()
        assert data["success"] is True
        mock_db_service.update_visited_place.assert_called_once()

    def test_sync_update_version_conflict(self, client, mock_db_service):
        """Test sync update with version mismatch."""
        mock_db_service.get_visited_place.return_value = {
            "region_type": "country",
            "region_code": "JP",
            "sync_version": 10,  # Server is ahead
            "is_deleted": False,
        }
        mock_db_service.update_visited_place.return_value = {}
        mock_db_service.get_changes_since.return_value = []
        mock_db_service.update_user.return_value = None

        response = client.post(
            "/sync",
            headers={"Authorization": "Bearer test-token"},
            json={
                "device_id": "test-device-123",
                "last_sync_version": 5,
                "operations": [
                    {
                        "operation_id": "op-1",
                        "operation_type": "update",
                        "entity_type": "visited_place",
                        "entity_id": "country#JP",
                        "entity_data": {"notes": "My notes"},
                        "client_version": 5,
                        "client_timestamp": "2024-01-15T10:00:00",
                    }
                ],
            },
        )

        assert response.status_code == 200
        data = response.json()
        assert len(data["conflicts"]) == 1
        assert data["conflicts"][0]["conflict_type"] == "version_mismatch"
        # Still updates (last write wins)
        mock_db_service.update_visited_place.assert_called_once()

    def test_sync_delete_operation(self, client, mock_db_service):
        """Test sync with delete operation."""
        mock_db_service.get_visited_place.return_value = {
            "region_type": "country",
            "region_code": "JP",
            "is_deleted": False,
        }
        mock_db_service.delete_visited_place.return_value = True
        mock_db_service.get_changes_since.return_value = []
        mock_db_service.update_user.return_value = None

        response = client.post(
            "/sync",
            headers={"Authorization": "Bearer test-token"},
            json={
                "device_id": "test-device-123",
                "last_sync_version": 5,
                "operations": [
                    {
                        "operation_id": "op-1",
                        "operation_type": "delete",
                        "entity_type": "visited_place",
                        "entity_id": "country#JP",
                        "entity_data": {},
                        "client_version": 5,
                        "client_timestamp": "2024-01-15T10:00:00",
                    }
                ],
            },
        )

        assert response.status_code == 200
        data = response.json()
        assert data["success"] is True
        mock_db_service.delete_visited_place.assert_called_once()

    def test_sync_invalid_entity_id(self, client, mock_db_service):
        """Test sync with invalid entity_id format."""
        mock_db_service.get_changes_since.return_value = []
        mock_db_service.update_user.return_value = None

        response = client.post(
            "/sync",
            headers={"Authorization": "Bearer test-token"},
            json={
                "device_id": "test-device-123",
                "last_sync_version": 5,
                "operations": [
                    {
                        "operation_id": "op-1",
                        "operation_type": "create",
                        "entity_type": "visited_place",
                        "entity_id": "invalid-format",  # Missing #
                        "entity_data": {},
                        "client_version": 5,
                        "client_timestamp": "2024-01-15T10:00:00",
                    }
                ],
            },
        )

        assert response.status_code == 200
        data = response.json()
        # Operation is silently skipped for invalid format
        assert data["success"] is True

    def test_sync_multiple_operations(self, client, mock_db_service):
        """Test sync with multiple operations."""
        mock_db_service.get_visited_place.return_value = None
        mock_db_service.create_visited_place.return_value = {}
        mock_db_service.get_changes_since.return_value = []
        mock_db_service.update_user.return_value = None

        response = client.post(
            "/sync",
            headers={"Authorization": "Bearer test-token"},
            json={
                "device_id": "test-device-123",
                "last_sync_version": 5,
                "operations": [
                    {
                        "operation_id": "op-1",
                        "operation_type": "create",
                        "entity_type": "visited_place",
                        "entity_id": "country#JP",
                        "entity_data": {"region_name": "Japan"},
                        "client_version": 5,
                        "client_timestamp": "2024-01-15T10:00:00",
                    },
                    {
                        "operation_id": "op-2",
                        "operation_type": "create",
                        "entity_type": "visited_place",
                        "entity_id": "country#FR",
                        "entity_data": {"region_name": "France"},
                        "client_version": 5,
                        "client_timestamp": "2024-01-15T10:00:00",
                    },
                ],
            },
        )

        assert response.status_code == 200
        data = response.json()
        assert data["success"] is True
        assert mock_db_service.create_visited_place.call_count == 2


class TestSyncStatus:
    """Tests for GET /sync/status endpoint."""

    def test_get_sync_status(self, client):
        """Test getting sync status."""
        response = client.get(
            "/sync/status",
            headers={"Authorization": "Bearer test-token"},
        )

        assert response.status_code == 200
        data = response.json()
        assert data["user_id"] == "test-user-123"
        assert data["sync_version"] == 5
        assert data["last_sync_at"] == "2024-01-01T00:00:00"
        assert data["last_sync_device"] == "device-old"

    def test_get_sync_status_new_user(self, mock_db_service):
        """Test getting sync status for user with no sync history."""
        new_user = {
            "user_id": "new-user-456",
            "email": "new@example.com",
        }
        app.dependency_overrides[get_current_user] = lambda: new_user
        client = TestClient(app)

        response = client.get(
            "/sync/status",
            headers={"Authorization": "Bearer test-token"},
        )

        assert response.status_code == 200
        data = response.json()
        assert data["user_id"] == "new-user-456"
        assert data["sync_version"] == 1  # Default
        assert data["last_sync_at"] is None
        assert data["last_sync_device"] is None

        app.dependency_overrides.clear()
