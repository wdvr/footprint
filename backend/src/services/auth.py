"""Authentication service for Apple and Google Sign In."""

import hashlib
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


class GoogleTokenPayload(BaseModel):
    """Google ID token payload."""

    iss: str  # Issuer (https://accounts.google.com)
    sub: str  # Subject (Google user ID)
    aud: str  # Audience (your app's client ID)
    iat: int  # Issued at
    exp: int  # Expiration
    email: str | None = None
    email_verified: bool | None = None
    name: str | None = None
    picture: str | None = None
    azp: str | None = None  # Authorized party


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

    GOOGLE_KEYS_URL = "https://www.googleapis.com/oauth2/v3/certs"
    GOOGLE_ISSUERS = ["https://accounts.google.com", "accounts.google.com"]

    # JWT settings
    JWT_SECRET = os.environ.get("JWT_SECRET", "dev-secret-change-in-production")
    JWT_ALGORITHM = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES = 60
    # Sliding window: each refresh rotates the token and restarts the clock, so a
    # device stays signed in as long as it opens the app at least this often.
    REFRESH_TOKEN_EXPIRE_DAYS = 90

    def __init__(self):
        self._apple_keys: list[dict[str, Any]] | None = None
        self._apple_keys_fetched_at: datetime | None = None
        self._google_keys: list[dict[str, Any]] | None = None
        self._google_keys_fetched_at: datetime | None = None

    async def _get_apple_public_keys(self) -> list[dict[str, Any]]:
        """Fetch Apple's public keys for token verification."""
        # Cache keys for 24 hours
        if (
            self._apple_keys
            and self._apple_keys_fetched_at
            and datetime.now(UTC) - self._apple_keys_fetched_at < timedelta(hours=24)
        ):
            return self._apple_keys

        async with httpx.AsyncClient() as client:
            response = await client.get(self.APPLE_KEYS_URL)
            response.raise_for_status()
            self._apple_keys = response.json().get("keys", [])
            self._apple_keys_fetched_at = datetime.now(UTC)
            return self._apple_keys

    async def _get_google_public_keys(self) -> list[dict[str, Any]]:
        """Fetch Google's public keys for token verification."""
        # Cache keys for 24 hours
        if (
            self._google_keys
            and self._google_keys_fetched_at
            and datetime.now(UTC) - self._google_keys_fetched_at < timedelta(hours=24)
        ):
            return self._google_keys

        async with httpx.AsyncClient() as client:
            response = await client.get(self.GOOGLE_KEYS_URL)
            response.raise_for_status()
            self._google_keys = response.json().get("keys", [])
            self._google_keys_fetched_at = datetime.now(UTC)
            return self._google_keys

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

    def _refresh_expiry(self) -> datetime:
        return datetime.now(UTC) + timedelta(days=self.REFRESH_TOKEN_EXPIRE_DAYS)

    def create_refresh_token(
        self,
        user_id: str,
        session_id: str | None = None,
        expire: datetime | None = None,
    ) -> str:
        """Create a JWT refresh token, bound to a server-side session when given."""
        payload = {
            "sub": user_id,
            "exp": expire or self._refresh_expiry(),
            "iat": datetime.now(UTC),
            "type": "refresh",
            "jti": str(uuid.uuid4()),
        }
        if session_id:
            payload["sid"] = session_id
        return jwt.encode(payload, self.JWT_SECRET, algorithm=self.JWT_ALGORITHM)

    @staticmethod
    def hash_token(token: str) -> str:
        """Hash a refresh token for storage; raw refresh tokens are never stored."""
        return hashlib.sha256(token.encode()).hexdigest()

    def _token_response(self, user_id: str, refresh_token: str) -> TokenResponse:
        return TokenResponse(
            access_token=self.create_access_token(user_id),
            refresh_token=refresh_token,
            token_type="bearer",
            expires_in=self.ACCESS_TOKEN_EXPIRE_MINUTES * 60,
        )

    def create_tokens(
        self,
        user_id: str,
        session_id: str | None = None,
        previous_hash: str | None = None,
    ) -> TokenResponse:
        """Start a new refresh session and return its access and refresh tokens."""
        session_id = session_id or str(uuid.uuid4())
        expire = self._refresh_expiry()
        refresh_token = self.create_refresh_token(user_id, session_id, expire)
        db_service.create_refresh_session(
            user_id,
            session_id,
            self.hash_token(refresh_token),
            int(expire.timestamp()),
            previous_hash=previous_hash,
        )
        return self._token_response(user_id, refresh_token)

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

    def _decode_refresh_token(
        self, token: str, verify_exp: bool = True
    ) -> dict[str, Any] | None:
        try:
            payload = jwt.decode(
                token,
                self.JWT_SECRET,
                algorithms=[self.JWT_ALGORITHM],
                options={"verify_exp": verify_exp},
            )
        except JWTError:
            return None
        if payload.get("type") != "refresh" or not payload.get("sub"):
            return None
        return payload

    def verify_refresh_token(self, token: str) -> str | None:
        """Verify refresh token signature/expiry and return user_id."""
        payload = self._decode_refresh_token(token)
        return payload.get("sub") if payload else None

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

        return user, self.create_tokens(user_id)

    async def verify_google_token(self, id_token: str) -> GoogleTokenPayload | None:
        """Verify Google ID token using Google's tokeninfo endpoint."""
        import httpx

        try:
            google_client_id = os.environ.get("GOOGLE_CLIENT_ID", "")
            print("[GoogleAuth] Verifying token with Google tokeninfo endpoint")
            print(f"[GoogleAuth] Expected client ID: {google_client_id}")

            # Use Google's tokeninfo endpoint for verification
            async with httpx.AsyncClient() as client:
                response = await client.get(
                    "https://oauth2.googleapis.com/tokeninfo",
                    params={"id_token": id_token},
                    timeout=10.0,
                )

            if response.status_code != 200:
                print(
                    f"[GoogleAuth] Token verification failed: {response.status_code} - {response.text}"
                )
                return None

            payload = response.json()
            print(f"[GoogleAuth] Token info received for: {payload.get('email')}")

            # Verify audience matches our client ID
            if payload.get("aud") != google_client_id:
                print(
                    f"[GoogleAuth] Audience mismatch: {payload.get('aud')} != {google_client_id}"
                )
                return None

            # Verify issuer
            if payload.get("iss") not in self.GOOGLE_ISSUERS:
                print(f"[GoogleAuth] Invalid issuer: {payload.get('iss')}")
                return None

            print(
                f"[GoogleAuth] Token verified successfully for: {payload.get('email')}"
            )
            return GoogleTokenPayload(**payload)

        except Exception as e:
            print(f"[GoogleAuth] Token verification error: {e}")
            return None

    async def authenticate_google(
        self, id_token: str
    ) -> tuple[dict[str, Any], TokenResponse] | None:
        """
        Authenticate user with Google Sign In.

        Returns tuple of (user_data, tokens) or None if auth fails.
        """
        # Verify the Google ID token
        google_payload = await self.verify_google_token(id_token)
        if not google_payload:
            return None

        google_user_id = google_payload.sub

        # Check if user exists
        user = db_service.get_user_by_auth("google", google_user_id)

        if user:
            # Existing user - create tokens
            user_id = user["user_id"]
            # Update profile picture if available
            if (
                google_payload.picture
                and user.get("profile_picture_url") != google_payload.picture
            ):
                user = db_service.update_user(
                    user_id, {"profile_picture_url": google_payload.picture}
                )
        else:
            # New user - create account
            user_id = str(uuid.uuid4())
            user_data = {
                "user_id": user_id,
                "auth_provider": "google",
                "auth_provider_id": google_user_id,
                "email": google_payload.email,
                "display_name": google_payload.name,
                "profile_picture_url": google_payload.picture,
                "countries_visited": 0,
                "us_states_visited": 0,
                "canadian_provinces_visited": 0,
                "sync_version": 1,
            }
            user = db_service.create_user(user_data)

        return user, self.create_tokens(user_id)

    def refresh_tokens(self, refresh_token: str) -> TokenResponse | None:
        """
        Exchange a refresh token for a new access token and a rotated refresh token.

        Returns None (-> 401) when the token is invalid, expired, revoked, already
        rotated past, or the user no longer exists.
        """
        payload = self._decode_refresh_token(refresh_token)
        if not payload:
            return None
        user_id = payload["sub"]

        if not db_service.get_user(user_id):
            return None

        session_id = payload.get("sid")
        if not session_id:
            # Token issued before server-side sessions existed: migrate it into a
            # session so existing installs are not signed out. The first exchange
            # creates the session with the legacy token as its one-time grace
            # token; a retry (lost response) goes through normal rotation.
            jti = payload.get("jti")
            if not jti:
                return None
            session_id = f"legacy-{jti}"
            if db_service.consume_legacy_refresh_token(
                user_id, jti, int(payload["exp"])
            ):
                return self.create_tokens(
                    user_id, session_id, previous_hash=self.hash_token(refresh_token)
                )

        expire = self._refresh_expiry()
        new_refresh_token = self.create_refresh_token(user_id, session_id, expire)
        rotated = db_service.rotate_refresh_session(
            user_id,
            session_id,
            self.hash_token(refresh_token),
            self.hash_token(new_refresh_token),
            int(expire.timestamp()),
        )
        if not rotated:
            return None

        return self._token_response(user_id, new_refresh_token)

    def revoke_refresh_token(self, refresh_token: str) -> None:
        """
        Revoke the session a refresh token belongs to (sign out). Idempotent.

        Any token issued for the session can revoke it, so a device whose token
        was superseded by a leaked copy can still end that session.
        """
        payload = self._decode_refresh_token(refresh_token, verify_exp=False)
        if not payload:
            return
        session_id = payload.get("sid") or (
            f"legacy-{payload['jti']}" if payload.get("jti") else None
        )
        if session_id:
            db_service.delete_refresh_session(payload["sub"], session_id)


# Singleton instance
auth_service = AuthService()
