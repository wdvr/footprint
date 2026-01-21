"""Tests for auth API routes."""

from unittest.mock import AsyncMock, patch

import pytest
from fastapi.testclient import TestClient

from src.api.main import app


@pytest.fixture
def client():
    """Create test client."""
    return TestClient(app)


@pytest.fixture
def mock_auth_service():
    """Mock auth service."""
    with patch("src.api.routes.auth.auth_service") as mock:
        yield mock


@pytest.fixture
def mock_db_service():
    """Mock DynamoDB service."""
    with patch("src.api.routes.auth.db_service") as mock:
        yield mock


class TestAppleAuth:
    """Tests for POST /auth/apple endpoint."""

    def test_apple_auth_success(self, client, mock_auth_service, mock_db_service):
        """Test successful Apple Sign In."""
        mock_auth_service.authenticate_apple = AsyncMock(
            return_value=(
                {
                    "user_id": "user-123",
                    "email": "test@example.com",
                    "display_name": None,
                    "countries_visited": 0,
                    "us_states_visited": 0,
                    "canadian_provinces_visited": 0,
                },
                {
                    "access_token": "access-token-123",
                    "refresh_token": "refresh-token-123",
                    "token_type": "Bearer",
                    "expires_in": 3600,
                },
            )
        )

        response = client.post(
            "/auth/apple",
            json={
                "identity_token": "valid-apple-token",
                "authorization_code": "auth-code",
            },
        )

        assert response.status_code == 200
        data = response.json()
        assert "user" in data
        assert "tokens" in data
        assert data["user"]["user_id"] == "user-123"
        assert data["tokens"]["access_token"] == "access-token-123"

    def test_apple_auth_with_username(self, client, mock_auth_service, mock_db_service):
        """Test Apple Sign In with username on first login."""
        mock_auth_service.authenticate_apple = AsyncMock(
            return_value=(
                {
                    "user_id": "user-123",
                    "email": "test@example.com",
                    "display_name": None,
                    "countries_visited": 0,
                    "us_states_visited": 0,
                    "canadian_provinces_visited": 0,
                },
                {
                    "access_token": "access-token",
                    "refresh_token": "refresh-token",
                    "token_type": "Bearer",
                    "expires_in": 3600,
                },
            )
        )
        mock_db_service.update_user.return_value = {
            "user_id": "user-123",
            "email": "test@example.com",
            "display_name": "John Doe",
            "countries_visited": 0,
            "us_states_visited": 0,
            "canadian_provinces_visited": 0,
        }

        response = client.post(
            "/auth/apple",
            json={
                "identity_token": "valid-token",
                "user_name": "John Doe",
            },
        )

        assert response.status_code == 200
        mock_db_service.update_user.assert_called_once()

    def test_apple_auth_invalid_token(self, client, mock_auth_service):
        """Test Apple Sign In with invalid token."""
        mock_auth_service.authenticate_apple = AsyncMock(return_value=None)

        response = client.post(
            "/auth/apple",
            json={
                "identity_token": "invalid-token",
            },
        )

        assert response.status_code == 401
        assert "Invalid Apple identity token" in response.json()["detail"]


class TestRefreshToken:
    """Tests for POST /auth/refresh endpoint."""

    def test_refresh_success(self, client, mock_auth_service):
        """Test successful token refresh."""
        mock_auth_service.refresh_tokens.return_value = {
            "access_token": "new-access-token",
            "refresh_token": "new-refresh-token",
            "token_type": "Bearer",
            "expires_in": 3600,
        }

        response = client.post(
            "/auth/refresh",
            json={"refresh_token": "valid-refresh-token"},
        )

        assert response.status_code == 200
        data = response.json()
        assert data["access_token"] == "new-access-token"

    def test_refresh_invalid_token(self, client, mock_auth_service):
        """Test refresh with invalid token."""
        mock_auth_service.refresh_tokens.return_value = None

        response = client.post(
            "/auth/refresh",
            json={"refresh_token": "invalid-token"},
        )

        assert response.status_code == 401
        assert "Invalid or expired refresh token" in response.json()["detail"]


class TestGetCurrentUser:
    """Tests for GET /auth/me endpoint."""

    def test_get_me_success(self, client, mock_auth_service, mock_db_service):
        """Test getting current user info."""
        mock_auth_service.verify_access_token.return_value = "user-123"
        mock_db_service.get_user.return_value = {
            "user_id": "user-123",
            "email": "test@example.com",
            "display_name": "Test User",
            "countries_visited": 15,
            "us_states_visited": 25,
            "canadian_provinces_visited": 5,
        }

        response = client.get(
            "/auth/me",
            headers={"Authorization": "Bearer valid-token"},
        )

        assert response.status_code == 200
        data = response.json()
        assert data["user_id"] == "user-123"
        assert data["display_name"] == "Test User"
        assert data["countries_visited"] == 15

    def test_get_me_invalid_token(self, client, mock_auth_service):
        """Test getting user with invalid token."""
        mock_auth_service.verify_access_token.return_value = None

        response = client.get(
            "/auth/me",
            headers={"Authorization": "Bearer invalid-token"},
        )

        assert response.status_code == 401

    def test_get_me_user_not_found(self, client, mock_auth_service, mock_db_service):
        """Test getting user that doesn't exist in DB."""
        mock_auth_service.verify_access_token.return_value = "user-123"
        mock_db_service.get_user.return_value = None

        response = client.get(
            "/auth/me",
            headers={"Authorization": "Bearer valid-token"},
        )

        assert response.status_code == 401

    def test_get_me_no_auth_header(self, client):
        """Test getting user without auth header."""
        response = client.get("/auth/me")
        # HTTPBearer can return 401 or 403 depending on version
        assert response.status_code in [401, 403]


class TestDeleteAccount:
    """Tests for DELETE /auth/me endpoint."""

    def test_delete_account_not_implemented(
        self, client, mock_auth_service, mock_db_service
    ):
        """Test account deletion returns 501."""
        mock_auth_service.verify_access_token.return_value = "user-123"
        mock_db_service.get_user.return_value = {
            "user_id": "user-123",
            "email": "test@example.com",
        }

        response = client.delete(
            "/auth/me",
            headers={"Authorization": "Bearer valid-token"},
        )

        assert response.status_code == 501
        assert "not yet implemented" in response.json()["detail"]
