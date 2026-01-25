"""Google OAuth and API service."""

import os
from datetime import UTC, datetime, timedelta

from google.auth.transport.requests import Request
from google.oauth2.credentials import Credentials
from google_auth_oauthlib.flow import Flow
from googleapiclient.discovery import build

from src.services.dynamodb import db_service

# Google OAuth configuration (loaded from .env)
GOOGLE_CLIENT_ID = os.environ.get("GOOGLE_CLIENT_ID", "")
GOOGLE_CLIENT_SECRET = os.environ.get("GOOGLE_CLIENT_SECRET", "")
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
            "web": {
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
        print(f"[GoogleService] exchange_auth_code: redirect_uri={GOOGLE_REDIRECT_URI}")
        print(f"[GoogleService] client_id={GOOGLE_CLIENT_ID[:20]}...")

        flow = Flow.from_client_config(
            self.client_config,
            scopes=SCOPES,
            redirect_uri=GOOGLE_REDIRECT_URI,
        )

        # Exchange the auth code for tokens
        print(f"[GoogleService] Fetching token with auth_code (len={len(auth_code)})")
        flow.fetch_token(code=auth_code)
        credentials = flow.credentials
        print(
            f"[GoogleService] Token fetched: token={credentials.token[:20] if credentials.token else 'None'}..., refresh={credentials.refresh_token is not None}"
        )

        # Get user info to get email
        service = build("oauth2", "v2", credentials=credentials)
        user_info = service.userinfo().get().execute()
        email = user_info.get("email", "")

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
        token_data = db_service.get_google_tokens(user_id)
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
