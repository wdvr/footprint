"""Tests for auth service."""

import time
from datetime import UTC, datetime, timedelta
from unittest.mock import AsyncMock, MagicMock, patch

import pytest
from jose import jwt


class TestTokenCreation:
    """Tests for JWT token creation."""

    def test_create_access_token(self):
        """Test creating an access token."""
        from src.services.auth import AuthService
        auth = AuthService()

        token = auth.create_access_token("user-123")

        # Decode and verify
        payload = jwt.decode(token, auth.JWT_SECRET, algorithms=[auth.JWT_ALGORITHM])
        assert payload["sub"] == "user-123"
        assert payload["type"] == "access"
        assert "exp" in payload
        assert "iat" in payload

    def test_create_refresh_token(self):
        """Test creating a refresh token."""
        from src.services.auth import AuthService
        auth = AuthService()

        token = auth.create_refresh_token("user-456")

        payload = jwt.decode(token, auth.JWT_SECRET, algorithms=[auth.JWT_ALGORITHM])
        assert payload["sub"] == "user-456"
        assert payload["type"] == "refresh"
        assert "jti" in payload  # JWT ID for uniqueness

    def test_access_token_expires(self):
        """Test access token has correct expiration."""
        from src.services.auth import AuthService
        auth = AuthService()

        token = auth.create_access_token("user-789")

        payload = jwt.decode(token, auth.JWT_SECRET, algorithms=[auth.JWT_ALGORITHM])
        exp = datetime.fromtimestamp(payload["exp"], tz=UTC)
        now = datetime.now(UTC)

        # Should expire in ~60 minutes (give some buffer)
        assert timedelta(minutes=59) < (exp - now) < timedelta(minutes=61)


class TestTokenVerification:
    """Tests for JWT token verification."""

    def test_verify_access_token_valid(self):
        """Test verifying a valid access token."""
        from src.services.auth import AuthService
        auth = AuthService()

        token = auth.create_access_token("verify-user")
        result = auth.verify_access_token(token)

        assert result == "verify-user"

    def test_verify_access_token_invalid(self):
        """Test verifying an invalid token."""
        from src.services.auth import AuthService
        auth = AuthService()

        result = auth.verify_access_token("invalid-token")

        assert result is None

    def test_verify_access_token_wrong_type(self):
        """Test verifying a refresh token as access token fails."""
        from src.services.auth import AuthService
        auth = AuthService()

        refresh_token = auth.create_refresh_token("user-123")
        result = auth.verify_access_token(refresh_token)

        assert result is None

    def test_verify_refresh_token_valid(self):
        """Test verifying a valid refresh token."""
        from src.services.auth import AuthService
        auth = AuthService()

        token = auth.create_refresh_token("refresh-user")
        result = auth.verify_refresh_token(token)

        assert result == "refresh-user"

    def test_verify_refresh_token_invalid(self):
        """Test verifying an invalid refresh token."""
        from src.services.auth import AuthService
        auth = AuthService()

        result = auth.verify_refresh_token("invalid-token")

        assert result is None

    def test_verify_refresh_token_wrong_type(self):
        """Test verifying an access token as refresh token fails."""
        from src.services.auth import AuthService
        auth = AuthService()

        access_token = auth.create_access_token("user-123")
        result = auth.verify_refresh_token(access_token)

        assert result is None

    def test_verify_expired_token(self):
        """Test verifying an expired token."""
        from src.services.auth import AuthService
        auth = AuthService()

        # Create token that's already expired
        expire = datetime.now(UTC) - timedelta(hours=1)
        payload = {
            "sub": "expired-user",
            "exp": expire,
            "iat": datetime.now(UTC) - timedelta(hours=2),
            "type": "access",
        }
        token = jwt.encode(payload, auth.JWT_SECRET, algorithm=auth.JWT_ALGORITHM)

        result = auth.verify_access_token(token)

        assert result is None


class TestAppleTokenVerification:
    """Tests for Apple token verification."""

    @pytest.mark.asyncio
    async def test_verify_apple_token_success(self):
        """Test verifying a valid Apple token."""
        from src.services.auth import AuthService
        auth = AuthService()

        # Mock the _get_apple_public_keys method
        mock_key = {
            "kid": "test-key-id",
            "kty": "RSA",
            "use": "sig",
            "alg": "RS256",
            "n": "test-n",
            "e": "AQAB",
        }
        auth._get_apple_public_keys = AsyncMock(return_value=[mock_key])

        # Mock jwt.get_unverified_header and jwt.decode
        with patch("src.services.auth.jwt") as mock_jwt:
            mock_jwt.get_unverified_header.return_value = {"kid": "test-key-id"}
            mock_jwt.decode.return_value = {
                "iss": "https://appleid.apple.com",
                "sub": "apple-user-123",
                "aud": "com.skratch.app",
                "iat": int(time.time()),
                "exp": int(time.time()) + 3600,
                "email": "user@privaterelay.appleid.com",
            }

            result = await auth.verify_apple_token("valid-apple-token")

            assert result is not None
            assert result.sub == "apple-user-123"
            assert result.email == "user@privaterelay.appleid.com"

    @pytest.mark.asyncio
    async def test_verify_apple_token_no_matching_key(self):
        """Test verifying Apple token with no matching key."""
        from src.services.auth import AuthService
        auth = AuthService()

        mock_key = {"kid": "different-key-id"}
        auth._get_apple_public_keys = AsyncMock(return_value=[mock_key])

        with patch("src.services.auth.jwt") as mock_jwt:
            mock_jwt.get_unverified_header.return_value = {"kid": "test-key-id"}

            result = await auth.verify_apple_token("no-matching-key-token")

            assert result is None

    @pytest.mark.asyncio
    async def test_verify_apple_token_jwt_error(self):
        """Test verifying Apple token with JWT error."""
        from jose import JWTError
        from src.services.auth import AuthService
        auth = AuthService()

        mock_key = {"kid": "test-key-id"}
        auth._get_apple_public_keys = AsyncMock(return_value=[mock_key])

        with patch("src.services.auth.jwt") as mock_jwt:
            mock_jwt.get_unverified_header.return_value = {"kid": "test-key-id"}
            mock_jwt.decode.side_effect = JWTError("Invalid token")

            result = await auth.verify_apple_token("invalid-token")

            assert result is None


class TestAuthenticateApple:
    """Tests for Apple authentication flow."""

    @pytest.mark.asyncio
    async def test_authenticate_apple_new_user(self):
        """Test Apple authentication creates new user."""
        from src.services.auth import AppleTokenPayload, AuthService
        auth = AuthService()

        # Mock verify_apple_token
        mock_payload = AppleTokenPayload(
            iss="https://appleid.apple.com",
            sub="new-apple-user",
            aud="com.skratch.app",
            iat=int(time.time()),
            exp=int(time.time()) + 3600,
            email="newuser@example.com",
        )
        auth.verify_apple_token = AsyncMock(return_value=mock_payload)

        with patch("src.services.auth.db_service") as mock_db:
            mock_db.get_user_by_auth.return_value = None
            mock_db.create_user.return_value = {
                "user_id": "generated-uuid",
                "email": "newuser@example.com",
            }

            result = await auth.authenticate_apple("valid-token", "auth-code")

            assert result is not None
            user, tokens = result
            assert "access_token" in tokens.model_dump()
            assert "refresh_token" in tokens.model_dump()
            mock_db.create_user.assert_called_once()

    @pytest.mark.asyncio
    async def test_authenticate_apple_existing_user(self):
        """Test Apple authentication returns existing user."""
        from src.services.auth import AppleTokenPayload, AuthService
        auth = AuthService()

        mock_payload = AppleTokenPayload(
            iss="https://appleid.apple.com",
            sub="existing-apple-user",
            aud="com.skratch.app",
            iat=int(time.time()),
            exp=int(time.time()) + 3600,
        )
        auth.verify_apple_token = AsyncMock(return_value=mock_payload)

        with patch("src.services.auth.db_service") as mock_db:
            mock_db.get_user_by_auth.return_value = {
                "user_id": "existing-user-123",
                "email": "existing@example.com",
            }

            result = await auth.authenticate_apple("valid-token")

            assert result is not None
            user, tokens = result
            assert user["user_id"] == "existing-user-123"
            mock_db.create_user.assert_not_called()

    @pytest.mark.asyncio
    async def test_authenticate_apple_invalid_token(self):
        """Test Apple authentication with invalid token."""
        from src.services.auth import AuthService
        auth = AuthService()

        auth.verify_apple_token = AsyncMock(return_value=None)

        result = await auth.authenticate_apple("invalid-token")

        assert result is None


class TestRefreshTokens:
    """Tests for token refresh flow."""

    def test_refresh_tokens_success(self):
        """Test successful token refresh."""
        from src.services.auth import AuthService
        auth = AuthService()

        refresh_token = auth.create_refresh_token("refresh-user-123")

        with patch("src.services.auth.db_service") as mock_db:
            mock_db.get_user.return_value = {
                "user_id": "refresh-user-123",
                "email": "user@example.com",
            }

            result = auth.refresh_tokens(refresh_token)

            assert result is not None
            assert result.access_token is not None
            assert result.refresh_token is not None

    def test_refresh_tokens_invalid_token(self):
        """Test refresh with invalid token."""
        from src.services.auth import AuthService
        auth = AuthService()

        result = auth.refresh_tokens("invalid-refresh-token")

        assert result is None

    def test_refresh_tokens_user_not_found(self):
        """Test refresh when user no longer exists."""
        from src.services.auth import AuthService
        auth = AuthService()

        refresh_token = auth.create_refresh_token("deleted-user")

        with patch("src.services.auth.db_service") as mock_db:
            mock_db.get_user.return_value = None

            result = auth.refresh_tokens(refresh_token)

            assert result is None


class TestAppleKeyCaching:
    """Tests for Apple public key caching."""

    @pytest.mark.asyncio
    async def test_keys_are_cached(self):
        """Test that Apple keys are cached."""
        from src.services.auth import AuthService
        auth = AuthService()

        mock_response = MagicMock()
        mock_response.json.return_value = {"keys": [{"kid": "test-key"}]}
        mock_response.raise_for_status = MagicMock()

        with patch("httpx.AsyncClient") as mock_client:
            mock_instance = AsyncMock()
            mock_instance.get = AsyncMock(return_value=mock_response)
            mock_instance.__aenter__ = AsyncMock(return_value=mock_instance)
            mock_instance.__aexit__ = AsyncMock()
            mock_client.return_value = mock_instance

            # First call - should fetch
            keys1 = await auth._get_apple_public_keys()
            # Second call - should use cache
            keys2 = await auth._get_apple_public_keys()

            assert keys1 == keys2
            # Should only have fetched once
            assert mock_instance.get.call_count == 1
