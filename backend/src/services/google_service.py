"""Google OAuth and API service."""

import logging
import os
from datetime import UTC, datetime, timedelta

from google.auth.transport.requests import Request
from google.oauth2.credentials import Credentials
from google_auth_oauthlib.flow import Flow
from googleapiclient.discovery import build

from src.services.dynamodb import db_service

logger = logging.getLogger(__name__)
logger.setLevel(logging.INFO)

# Google OAuth configuration for import (Web App client with secret)
GOOGLE_CLIENT_ID = os.environ.get("GOOGLE_IMPORT_CLIENT_ID", "")
GOOGLE_CLIENT_SECRET = os.environ.get("GOOGLE_IMPORT_CLIENT_SECRET", "")
GOOGLE_REDIRECT_URI = os.environ.get("GOOGLE_REDIRECT_URI", "")

SCOPES = [
    "openid",
    "https://www.googleapis.com/auth/userinfo.email",
    "https://www.googleapis.com/auth/gmail.readonly",
    "https://www.googleapis.com/auth/calendar.readonly",
]


class GoogleService:
    """Service for Google OAuth and API operations."""

    def __init__(self):
        self.client_config = {
            "installed": {
                "client_id": GOOGLE_CLIENT_ID,
                "client_secret": GOOGLE_CLIENT_SECRET,
                "redirect_uris": [GOOGLE_REDIRECT_URI],
                "auth_uri": "https://accounts.google.com/o/oauth2/auth",
                "token_uri": "https://oauth2.googleapis.com/token",
            }
        }

    def exchange_auth_code(self, auth_code: str, user_id: str) -> dict:
        """
        Exchange authorization code for tokens and store them.

        Returns the connected Google email.
        """
        logger.info(f"[GoogleService] Exchanging auth code for user {user_id}")
        logger.info(
            f"[GoogleService] Config: client_id={GOOGLE_CLIENT_ID[:20]}..., redirect_uri={GOOGLE_REDIRECT_URI}"
        )

        if not GOOGLE_CLIENT_ID or not GOOGLE_CLIENT_SECRET:
            logger.error(
                "[GoogleService] Missing GOOGLE_CLIENT_ID or GOOGLE_CLIENT_SECRET"
            )
            raise ValueError("Google OAuth not configured: missing client credentials")

        if not GOOGLE_REDIRECT_URI:
            logger.error("[GoogleService] Missing GOOGLE_REDIRECT_URI")
            raise ValueError("Google OAuth not configured: missing redirect URI")

        try:
            flow = Flow.from_client_config(
                self.client_config,
                scopes=SCOPES,
                redirect_uri=GOOGLE_REDIRECT_URI,
            )

            # Exchange the auth code for tokens
            logger.info("[GoogleService] Calling fetch_token...")
            flow.fetch_token(code=auth_code)
            credentials = flow.credentials
            logger.info("[GoogleService] Got credentials from auth code")
        except Exception as e:
            logger.error(
                f"[GoogleService] Token exchange failed: {type(e).__name__}: {e}"
            )
            raise

        # Get user info to get email
        service = build("oauth2", "v2", credentials=credentials)
        user_info = service.userinfo().get().execute()
        email = user_info.get("email", "")
        logger.info(f"[GoogleService] Got email: {email}")

        # Calculate token expiry
        expiry = credentials.expiry or (datetime.now(UTC) + timedelta(hours=1))

        # Store tokens in DynamoDB
        token_data = {
            "access_token": credentials.token,
            "refresh_token": credentials.refresh_token or "",
            "token_expiry": expiry.isoformat(),
            "email": email,
            "scopes": list(credentials.scopes or SCOPES),
        }

        db_service.store_google_tokens(user_id, token_data)
        logger.info(f"[GoogleService] Stored tokens for user {user_id}")

        return {"email": email, "connected": True}

    def get_credentials(self, user_id: str) -> Credentials | None:
        """
        Get valid Google credentials for a user.

        Refreshes tokens if needed.
        """
        token_data = db_service.get_google_tokens(user_id)
        if not token_data:
            return None

        credentials = Credentials(
            token=token_data.get("access_token"),
            refresh_token=token_data.get("refresh_token"),
            token_uri="https://oauth2.googleapis.com/token",
            client_id=GOOGLE_CLIENT_ID,
            client_secret=GOOGLE_CLIENT_SECRET,
            scopes=token_data.get("scopes", SCOPES),
        )

        # Check if token needs refresh
        if credentials.expired and credentials.refresh_token:
            credentials.refresh(Request())

            # Update stored tokens
            expiry = credentials.expiry or (datetime.now(UTC) + timedelta(hours=1))
            updated_data = {
                "access_token": credentials.token,
                "refresh_token": credentials.refresh_token,
                "token_expiry": expiry.isoformat(),
            }
            db_service.update_google_tokens(user_id, updated_data)

        return credentials

    def get_gmail_service(self, user_id: str):
        """Get Gmail API service for a user."""
        credentials = self.get_credentials(user_id)
        if not credentials:
            raise ValueError("No Google credentials found for user")
        return build("gmail", "v1", credentials=credentials)

    def get_calendar_service(self, user_id: str):
        """Get Calendar API service for a user."""
        credentials = self.get_credentials(user_id)
        if not credentials:
            raise ValueError("No Google credentials found for user")
        return build("calendar", "v3", credentials=credentials)

    def get_connection_status(self, user_id: str) -> dict:
        """Check if user has a connected Google account."""
        logger.info(f"[GoogleService] Checking connection for user {user_id}")
        token_data = db_service.get_google_tokens(user_id)
        logger.info(f"[GoogleService] Token data found: {token_data is not None}")
        if not token_data:
            return {"is_connected": False, "email": None}

        return {
            "is_connected": True,
            "email": token_data.get("email"),
        }

    def disconnect(self, user_id: str) -> bool:
        """Disconnect Google account by removing stored tokens."""
        return db_service.delete_google_tokens(user_id)


# Singleton instance
google_service = GoogleService()
