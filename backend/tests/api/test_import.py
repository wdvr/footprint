"""Tests for import API routes."""

from unittest.mock import MagicMock, patch

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
    with patch("src.api.routes.import_routes.db_service") as mock:
        yield mock


@pytest.fixture
def mock_google_service():
    """Mock Google service."""
    with patch("src.api.routes.import_routes.google_service") as mock:
        yield mock


@pytest.fixture
def client(mock_user):
    """Create test client with mocked auth."""
    app.dependency_overrides[get_current_user] = lambda: mock_user
    client = TestClient(app)
    yield client
    app.dependency_overrides.clear()


class TestGoogleConnectionStatus:
    """Tests for GET /import/google/status endpoint."""

    def test_connected_status(self, client, mock_google_service):
        """Test when Google account is connected."""
        mock_google_service.get_connection_status.return_value = {
            "is_connected": True,
            "email": "user@gmail.com",
        }

        response = client.get(
            "/import/google/status",
            headers={"Authorization": "Bearer test-token"},
        )

        assert response.status_code == 200
        data = response.json()
        assert data["is_connected"] is True
        assert data["email"] == "user@gmail.com"

    def test_not_connected_status(self, client, mock_google_service):
        """Test when Google account is not connected."""
        mock_google_service.get_connection_status.return_value = {
            "is_connected": False,
            "email": None,
        }

        response = client.get(
            "/import/google/status",
            headers={"Authorization": "Bearer test-token"},
        )

        assert response.status_code == 200
        data = response.json()
        assert data["is_connected"] is False
        assert data["email"] is None


class TestGoogleConnect:
    """Tests for POST /import/google/connect endpoint."""

    def test_connect_success(self, client, mock_google_service):
        """Test successful Google connection."""
        mock_google_service.exchange_auth_code.return_value = {
            "email": "user@gmail.com",
            "connected": True,
        }

        response = client.post(
            "/import/google/connect",
            headers={"Authorization": "Bearer test-token"},
            json={"authorization_code": "test-auth-code"},
        )

        assert response.status_code == 200
        data = response.json()
        assert data["email"] == "user@gmail.com"
        assert data["connected"] is True

    def test_connect_failure(self, client, mock_google_service):
        """Test failed Google connection."""
        mock_google_service.exchange_auth_code.side_effect = Exception("Invalid code")

        response = client.post(
            "/import/google/connect",
            headers={"Authorization": "Bearer test-token"},
            json={"authorization_code": "invalid-code"},
        )

        assert response.status_code == 400
        assert "Failed to connect" in response.json()["detail"]


class TestGoogleDisconnect:
    """Tests for DELETE /import/google/disconnect endpoint."""

    def test_disconnect_success(self, client, mock_google_service):
        """Test successful Google disconnection."""
        mock_google_service.disconnect.return_value = True

        response = client.delete(
            "/import/google/disconnect",
            headers={"Authorization": "Bearer test-token"},
        )

        assert response.status_code == 204


class TestGoogleScan:
    """Tests for POST /import/google/scan endpoint."""

    def test_scan_not_connected(self, client, mock_google_service, mock_db_service):
        """Test scan when Google is not connected."""
        mock_google_service.get_connection_status.return_value = {
            "is_connected": False,
            "email": None,
        }

        response = client.post(
            "/import/google/scan",
            headers={"Authorization": "Bearer test-token"},
        )

        assert response.status_code == 400
        assert "not connected" in response.json()["detail"]

    def test_scan_success(self, client, mock_google_service, mock_db_service):
        """Test successful scan with results."""
        mock_google_service.get_connection_status.return_value = {
            "is_connected": True,
            "email": "user@gmail.com",
        }
        mock_db_service.get_user_visited_places.return_value = []

        # Mock Gmail service
        mock_gmail = MagicMock()
        mock_google_service.get_gmail_service.return_value = mock_gmail

        # Mock Calendar service
        mock_calendar = MagicMock()
        mock_google_service.get_calendar_service.return_value = mock_calendar

        # Patch email and calendar parsers
        with (
            patch("src.api.routes.import_routes.parse_emails") as mock_parse_emails,
            patch(
                "src.api.routes.import_routes.parse_calendar_events"
            ) as mock_parse_events,
            patch(
                "src.api.routes.import_routes.aggregate_email_countries"
            ) as mock_agg_email,
            patch(
                "src.api.routes.import_routes.aggregate_calendar_countries"
            ) as mock_agg_cal,
        ):
            mock_parse_emails.return_value = []
            mock_parse_events.return_value = []
            mock_agg_email.return_value = {
                "FR": {
                    "count": 5,
                    "samples": [
                        {"id": "1", "source_type": "email", "title": "Flight to Paris"}
                    ],
                },
            }
            mock_agg_cal.return_value = {
                "FR": {
                    "count": 2,
                    "samples": [
                        {"id": "2", "source_type": "calendar", "title": "Paris trip"}
                    ],
                },
            }

            response = client.post(
                "/import/google/scan",
                headers={"Authorization": "Bearer test-token"},
            )

            assert response.status_code == 200
            data = response.json()
            assert "candidates" in data
            assert data["scanned_emails"] == 0
            assert data["scanned_events"] == 0

    def test_scan_excludes_existing_countries(
        self, client, mock_google_service, mock_db_service
    ):
        """Test that scan excludes countries user has already visited."""
        mock_google_service.get_connection_status.return_value = {
            "is_connected": True,
            "email": "user@gmail.com",
        }
        # User has already visited France
        mock_db_service.get_user_visited_places.return_value = [
            {"region_code": "FR", "region_type": "country"},
        ]

        mock_gmail = MagicMock()
        mock_google_service.get_gmail_service.return_value = mock_gmail
        mock_calendar = MagicMock()
        mock_google_service.get_calendar_service.return_value = mock_calendar

        with (
            patch("src.api.routes.import_routes.parse_emails") as mock_parse_emails,
            patch(
                "src.api.routes.import_routes.parse_calendar_events"
            ) as mock_parse_events,
            patch(
                "src.api.routes.import_routes.aggregate_email_countries"
            ) as mock_agg_email,
            patch(
                "src.api.routes.import_routes.aggregate_calendar_countries"
            ) as mock_agg_cal,
        ):
            mock_parse_emails.return_value = []
            mock_parse_events.return_value = []
            # Both FR and DE found in emails
            mock_agg_email.return_value = {
                "FR": {"count": 5, "samples": []},
                "DE": {"count": 3, "samples": []},
            }
            mock_agg_cal.return_value = {}

            response = client.post(
                "/import/google/scan",
                headers={"Authorization": "Bearer test-token"},
            )

            assert response.status_code == 200
            data = response.json()
            # FR should be excluded since user already visited
            country_codes = [c["country_code"] for c in data["candidates"]]
            assert "FR" not in country_codes
            assert "DE" in country_codes


class TestImportConfirm:
    """Tests for POST /import/google/confirm endpoint."""

    def test_confirm_empty_selection(self, client, mock_db_service):
        """Test confirm with no countries selected."""
        response = client.post(
            "/import/google/confirm",
            headers={"Authorization": "Bearer test-token"},
            json={"country_codes": []},
        )

        assert response.status_code == 400
        assert "No countries selected" in response.json()["detail"]

    def test_confirm_success(self, client, mock_db_service):
        """Test successful import confirmation."""
        mock_db_service.get_visited_place.return_value = None
        mock_db_service.create_visited_place.return_value = {
            "user_id": "test-user-123",
            "region_type": "country",
            "region_code": "FR",
            "region_name": "France",
        }
        mock_db_service.update_user.return_value = {}

        response = client.post(
            "/import/google/confirm",
            headers={"Authorization": "Bearer test-token"},
            json={"country_codes": ["FR", "DE"]},
        )

        assert response.status_code == 200
        data = response.json()
        assert data["imported"] == 2
        assert len(data["countries"]) == 2

    def test_confirm_skips_existing(self, client, mock_db_service):
        """Test that confirm skips already visited countries."""
        # FR already exists
        mock_db_service.get_visited_place.side_effect = [
            {"region_code": "FR", "is_deleted": False},  # FR exists
            None,  # DE doesn't exist
        ]
        mock_db_service.create_visited_place.return_value = {
            "user_id": "test-user-123",
            "region_type": "country",
            "region_code": "DE",
            "region_name": "Germany",
        }
        mock_db_service.update_user.return_value = {}

        response = client.post(
            "/import/google/confirm",
            headers={"Authorization": "Bearer test-token"},
            json={"country_codes": ["FR", "DE"]},
        )

        assert response.status_code == 200
        data = response.json()
        assert data["imported"] == 1  # Only DE imported
        assert data["countries"][0]["country_code"] == "DE"

    def test_confirm_invalid_country_code(self, client, mock_db_service):
        """Test confirm with invalid country code."""
        mock_db_service.get_visited_place.return_value = None

        response = client.post(
            "/import/google/confirm",
            headers={"Authorization": "Bearer test-token"},
            json={"country_codes": ["XX", "ZZ"]},  # Invalid codes
        )

        assert response.status_code == 200
        data = response.json()
        assert data["imported"] == 0  # No valid countries to import


class TestImportEndToEnd:
    """End-to-end tests for the import flow."""

    def test_full_import_flow(self, client, mock_google_service, mock_db_service):
        """Test the complete import flow: connect -> scan -> confirm."""
        # Step 1: Connect Google
        mock_google_service.exchange_auth_code.return_value = {
            "email": "user@gmail.com",
            "connected": True,
        }

        connect_response = client.post(
            "/import/google/connect",
            headers={"Authorization": "Bearer test-token"},
            json={"authorization_code": "test-auth-code"},
        )
        assert connect_response.status_code == 200

        # Step 2: Scan for countries
        mock_google_service.get_connection_status.return_value = {
            "is_connected": True,
            "email": "user@gmail.com",
        }
        mock_db_service.get_user_visited_places.return_value = []

        mock_gmail = MagicMock()
        mock_google_service.get_gmail_service.return_value = mock_gmail
        mock_calendar = MagicMock()
        mock_google_service.get_calendar_service.return_value = mock_calendar

        with (
            patch("src.api.routes.import_routes.parse_emails") as mock_parse_emails,
            patch(
                "src.api.routes.import_routes.parse_calendar_events"
            ) as mock_parse_events,
            patch(
                "src.api.routes.import_routes.aggregate_email_countries"
            ) as mock_agg_email,
            patch(
                "src.api.routes.import_routes.aggregate_calendar_countries"
            ) as mock_agg_cal,
        ):
            mock_parse_emails.return_value = []
            mock_parse_events.return_value = []
            mock_agg_email.return_value = {"FR": {"count": 5, "samples": []}}
            mock_agg_cal.return_value = {"FR": {"count": 2, "samples": []}}

            scan_response = client.post(
                "/import/google/scan",
                headers={"Authorization": "Bearer test-token"},
            )
            assert scan_response.status_code == 200

        # Step 3: Confirm import
        mock_db_service.get_visited_place.return_value = None
        mock_db_service.create_visited_place.return_value = {
            "user_id": "test-user-123",
            "region_type": "country",
            "region_code": "FR",
            "region_name": "France",
        }
        mock_db_service.update_user.return_value = {}

        confirm_response = client.post(
            "/import/google/confirm",
            headers={"Authorization": "Bearer test-token"},
            json={"country_codes": ["FR"]},
        )
        assert confirm_response.status_code == 200
        assert confirm_response.json()["imported"] == 1
