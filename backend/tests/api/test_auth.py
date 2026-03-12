"""Tests for auth API routes."""

from unittest.mock import AsyncMock, MagicMock, patch

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


@pytest.fixture
def mock_table():
    """Mock DynamoDB table."""
    with patch("src.api.routes.auth.table") as mock:
        yield mock


class TestDeleteAccount:
    """Tests for DELETE /auth/me endpoint."""

    def test_delete_account_success(
        self, client, mock_auth_service, mock_db_service, mock_table
    ):
        """Test successful account deletion returns 204."""
        mock_auth_service.verify_access_token.return_value = "user-123"
        mock_db_service.get_user.return_value = {
            "user_id": "user-123",
            "email": "test@example.com",
        }

        # Simulate items returned by query (profile, a place, a friend)
        mock_table.query.return_value = {
            "Items": [
                {"pk": "USER#user-123", "sk": "PROFILE"},
                {"pk": "USER#user-123", "sk": "PLACE#country#US"},
                {"pk": "USER#user-123", "sk": "FRIEND#friend-456"},
                {"pk": "USER#user-123", "sk": "GOOGLE_TOKENS"},
                {"pk": "USER#user-123", "sk": "FEEDBACK#fb-1"},
                {"pk": "USER#user-123", "sk": "DEVICE_TOKEN#abc123"},
            ],
        }

        # Mock batch_writer context manager
        mock_batch = MagicMock()
        mock_table.batch_writer.return_value.__enter__ = MagicMock(
            return_value=mock_batch
        )
        mock_table.batch_writer.return_value.__exit__ = MagicMock(return_value=False)

        response = client.delete(
            "/auth/me",
            headers={"Authorization": "Bearer valid-token"},
        )

        assert response.status_code == 204

        # Verify all user items were batch-deleted
        assert mock_batch.delete_item.call_count == 6

        # Verify bidirectional friendship cleanup
        mock_table.delete_item.assert_called_once_with(
            Key={"pk": "USER#friend-456", "sk": "FRIEND#user-123"}
        )

    def test_delete_account_no_data(
        self, client, mock_auth_service, mock_db_service, mock_table
    ):
        """Test account deletion when user has no items."""
        mock_auth_service.verify_access_token.return_value = "user-123"
        mock_db_service.get_user.return_value = {
            "user_id": "user-123",
            "email": "test@example.com",
        }

        mock_table.query.return_value = {"Items": []}

        mock_batch = MagicMock()
        mock_table.batch_writer.return_value.__enter__ = MagicMock(
            return_value=mock_batch
        )
        mock_table.batch_writer.return_value.__exit__ = MagicMock(return_value=False)

        response = client.delete(
            "/auth/me",
            headers={"Authorization": "Bearer valid-token"},
        )

        assert response.status_code == 204
        assert mock_batch.delete_item.call_count == 0

    def test_delete_account_unauthenticated(self, client, mock_auth_service):
        """Test account deletion without valid auth."""
        mock_auth_service.verify_access_token.return_value = None

        response = client.delete(
            "/auth/me",
            headers={"Authorization": "Bearer invalid-token"},
        )

        assert response.status_code == 401

    def test_delete_account_paginated_query(
        self, client, mock_auth_service, mock_db_service, mock_table
    ):
        """Test account deletion handles paginated DynamoDB results."""
        mock_auth_service.verify_access_token.return_value = "user-123"
        mock_db_service.get_user.return_value = {
            "user_id": "user-123",
            "email": "test@example.com",
        }

        # Simulate paginated response
        mock_table.query.side_effect = [
            {
                "Items": [{"pk": "USER#user-123", "sk": "PROFILE"}],
                "LastEvaluatedKey": {"pk": "USER#user-123", "sk": "PROFILE"},
            },
            {
                "Items": [{"pk": "USER#user-123", "sk": "PLACE#country#FR"}],
            },
        ]

        mock_batch = MagicMock()
        mock_table.batch_writer.return_value.__enter__ = MagicMock(
            return_value=mock_batch
        )
        mock_table.batch_writer.return_value.__exit__ = MagicMock(return_value=False)

        response = client.delete(
            "/auth/me",
            headers={"Authorization": "Bearer valid-token"},
        )

        assert response.status_code == 204
        # Two items deleted across two pages
        assert mock_batch.delete_item.call_count == 2
        # Query called twice due to pagination
        assert mock_table.query.call_count == 2
