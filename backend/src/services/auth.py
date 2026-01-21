"""Authentication service for Apple Sign In."""

import os
import uuid
from datetime import UTC, datetime, timedelta
from typing import Any

import httpx
from jose import JWTError, jwt
from pydantic import BaseModel

from src.services.dynamodb import db_service


class AppleTokenPayload(BaseModel):
    """Apple ID token payload."""

    iss: str  # Issuer (https://appleid.apple.com)
    sub: str  # Subject (Apple user ID)
    aud: str  # Audience (your app's bundle ID)
    iat: int  # Issued at
    exp: int  # Expiration
    email: str | None = None
    email_verified: bool | str | None = None
    is_private_email: bool | str | None = None
    nonce: str | None = None
    nonce_supported: bool | None = None


class TokenResponse(BaseModel):
    """JWT token response."""

    access_token: str
    refresh_token: str
    token_type: str = "bearer"
    expires_in: int


class AuthService:
    """Service for authentication operations."""

    APPLE_KEYS_URL = "https://appleid.apple.com/auth/keys"
    APPLE_ISSUER = "https://appleid.apple.com"

    # JWT settings
    JWT_SECRET = os.environ.get("JWT_SECRET", "dev-secret-change-in-production")
    JWT_ALGORITHM = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES = 60
    REFRESH_TOKEN_EXPIRE_DAYS = 30

    def __init__(self):
        self._apple_keys: list[dict[str, Any]] | None = None
        self._keys_fetched_at: datetime | None = None

    async def _get_apple_public_keys(self) -> list[dict[str, Any]]:
        """Fetch Apple's public keys for token verification."""
        # Cache keys for 24 hours
        if (
            self._apple_keys
            and self._keys_fetched_at
            and datetime.now(UTC) - self._keys_fetched_at < timedelta(hours=24)
        ):
            return self._apple_keys

        async with httpx.AsyncClient() as client:
            response = await client.get(self.APPLE_KEYS_URL)
            response.raise_for_status()
            self._apple_keys = response.json().get("keys", [])
            self._keys_fetched_at = datetime.now(UTC)
            return self._apple_keys

    async def verify_apple_token(self, identity_token: str) -> AppleTokenPayload | None:
        """Verify Apple identity token and return payload."""
        try:
            # Get Apple's public keys
            apple_keys = await self._get_apple_public_keys()

            # Decode token header to get key ID
            unverified_header = jwt.get_unverified_header(identity_token)
            kid = unverified_header.get("kid")

            # Find the matching key
            apple_key = next((k for k in apple_keys if k.get("kid") == kid), None)
            if not apple_key:
                return None

            # Verify and decode the token
            payload = jwt.decode(
                identity_token,
                apple_key,
                algorithms=["RS256"],
                audience=os.environ.get("APPLE_BUNDLE_ID", "com.footprint.app"),
                issuer=self.APPLE_ISSUER,
            )

            return AppleTokenPayload(**payload)

        except JWTError:
            return None

    def create_access_token(self, user_id: str) -> str:
        """Create a JWT access token."""
        expire = datetime.now(UTC) + timedelta(minutes=self.ACCESS_TOKEN_EXPIRE_MINUTES)
        payload = {
            "sub": user_id,
            "exp": expire,
            "iat": datetime.now(UTC),
            "type": "access",
        }
        return jwt.encode(payload, self.JWT_SECRET, algorithm=self.JWT_ALGORITHM)

    def create_refresh_token(self, user_id: str) -> str:
        """Create a JWT refresh token."""
        expire = datetime.now(UTC) + timedelta(days=self.REFRESH_TOKEN_EXPIRE_DAYS)
        payload = {
            "sub": user_id,
            "exp": expire,
            "iat": datetime.now(UTC),
            "type": "refresh",
            "jti": str(uuid.uuid4()),
        }
        return jwt.encode(payload, self.JWT_SECRET, algorithm=self.JWT_ALGORITHM)

    def verify_access_token(self, token: str) -> str | None:
        """Verify access token and return user_id."""
        try:
            payload = jwt.decode(
                token, self.JWT_SECRET, algorithms=[self.JWT_ALGORITHM]
            )
            if payload.get("type") != "access":
                return None
            return payload.get("sub")
        except JWTError:
            return None

    def verify_refresh_token(self, token: str) -> str | None:
        """Verify refresh token and return user_id."""
        try:
            payload = jwt.decode(
                token, self.JWT_SECRET, algorithms=[self.JWT_ALGORITHM]
            )
            if payload.get("type") != "refresh":
                return None
            return payload.get("sub")
        except JWTError:
            return None

    async def authenticate_apple(
        self, identity_token: str, authorization_code: str | None = None
    ) -> tuple[dict[str, Any], TokenResponse] | None:
        """
        Authenticate user with Apple Sign In.

        Returns tuple of (user_data, tokens) or None if auth fails.
        """
        # Verify the Apple identity token
        apple_payload = await self.verify_apple_token(identity_token)
        if not apple_payload:
            return None

        apple_user_id = apple_payload.sub

        # Check if user exists
        user = db_service.get_user_by_auth("apple", apple_user_id)

        if user:
            # Existing user - create tokens
            user_id = user["user_id"]
        else:
            # New user - create account
            user_id = str(uuid.uuid4())
            user_data = {
                "user_id": user_id,
                "auth_provider": "apple",
                "auth_provider_id": apple_user_id,
                "email": apple_payload.email,
                "countries_visited": 0,
                "us_states_visited": 0,
                "canadian_provinces_visited": 0,
                "sync_version": 1,
            }
            user = db_service.create_user(user_data)

        # Create tokens
        access_token = self.create_access_token(user_id)
        refresh_token = self.create_refresh_token(user_id)

        tokens = TokenResponse(
            access_token=access_token,
            refresh_token=refresh_token,
            expires_in=self.ACCESS_TOKEN_EXPIRE_MINUTES * 60,
        )

        return user, tokens

    def refresh_tokens(self, refresh_token: str) -> TokenResponse | None:
        """Refresh access token using refresh token."""
        user_id = self.verify_refresh_token(refresh_token)
        if not user_id:
            return None

        # Verify user still exists
        user = db_service.get_user(user_id)
        if not user:
            return None

        # Create new tokens
        new_access_token = self.create_access_token(user_id)
        new_refresh_token = self.create_refresh_token(user_id)

        return TokenResponse(
            access_token=new_access_token,
            refresh_token=new_refresh_token,
            expires_in=self.ACCESS_TOKEN_EXPIRE_MINUTES * 60,
        )


# Singleton instance
auth_service = AuthService()
