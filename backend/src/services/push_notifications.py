"""Push notification service for APNs (Apple Push Notification service)."""

import os
import time
from dataclasses import dataclass

import httpx
from jose import jwt

from src.services.dynamodb import db_service


@dataclass
class PushNotification:
    """Push notification payload."""

    title: str
    body: str
    data: dict | None = None
    badge: int | None = None
    sound: str = "default"
    category: str | None = None


class APNsService:
    """Apple Push Notification service client."""

    # APNs endpoints
    SANDBOX_URL = "https://api.sandbox.push.apple.com"
    PRODUCTION_URL = "https://api.push.apple.com"

    def __init__(self):
        self.key_id = os.environ.get("APNS_KEY_ID", "")
        self.team_id = os.environ.get("APNS_TEAM_ID", "")
        self.bundle_id = os.environ.get(
            "APNS_BUNDLE_ID", "com.wouterdevriendt.footprint"
        )
        self.key_path = os.environ.get("APNS_KEY_PATH", "")
        self.is_sandbox = os.environ.get("ENVIRONMENT", "dev") != "prod"
        self._private_key: str | None = None
        self._token: str | None = None
        self._token_timestamp: float = 0

    @property
    def base_url(self) -> str:
        """Get APNs base URL based on environment."""
        return self.SANDBOX_URL if self.is_sandbox else self.PRODUCTION_URL

    def _load_private_key(self) -> str:
        """Load APNs private key from file or environment."""
        if self._private_key:
            return self._private_key

        # Try environment variable first (for Lambda)
        key_content = os.environ.get("APNS_PRIVATE_KEY", "")
        if key_content:
            self._private_key = key_content
            return self._private_key

        # Fall back to file path
        if self.key_path and os.path.exists(self.key_path):
            with open(self.key_path) as f:
                self._private_key = f.read()
            return self._private_key

        raise ValueError("APNs private key not configured")

    def _generate_token(self) -> str:
        """Generate JWT token for APNs authentication."""
        # Tokens are valid for 1 hour, refresh after 50 minutes
        if self._token and (time.time() - self._token_timestamp) < 3000:
            return self._token

        private_key = self._load_private_key()

        headers = {
            "alg": "ES256",
            "kid": self.key_id,
        }

        payload = {
            "iss": self.team_id,
            "iat": int(time.time()),
        }

        self._token = jwt.encode(
            payload, private_key, algorithm="ES256", headers=headers
        )
        self._token_timestamp = time.time()
        return self._token

    async def send_notification(
        self,
        device_token: str,
        notification: PushNotification,
        priority: int = 10,
    ) -> bool:
        """
        Send a push notification to a device.

        Args:
            device_token: APNs device token
            notification: Notification payload
            priority: 10 for immediate, 5 for power-saving

        Returns:
            True if notification was sent successfully
        """
        if not self.key_id or not self.team_id:
            print("[APNs] Not configured, skipping notification")
            return False

        try:
            token = self._generate_token()

            headers = {
                "authorization": f"bearer {token}",
                "apns-topic": self.bundle_id,
                "apns-priority": str(priority),
                "apns-push-type": "alert",
            }

            # Build APNs payload
            aps = {
                "alert": {
                    "title": notification.title,
                    "body": notification.body,
                },
                "sound": notification.sound,
            }

            if notification.badge is not None:
                aps["badge"] = notification.badge

            if notification.category:
                aps["category"] = notification.category

            payload = {"aps": aps}

            if notification.data:
                payload.update(notification.data)

            url = f"{self.base_url}/3/device/{device_token}"

            async with httpx.AsyncClient(http2=True) as client:
                response = await client.post(
                    url,
                    headers=headers,
                    json=payload,
                    timeout=30.0,
                )

                if response.status_code == 200:
                    print(f"[APNs] Notification sent to {device_token[:16]}...")
                    return True
                else:
                    error = response.json() if response.content else {}
                    print(f"[APNs] Failed: {response.status_code} - {error}")
                    return False

        except Exception as e:
            print(f"[APNs] Error sending notification: {e}")
            return False

    async def send_to_user(
        self,
        user_id: str,
        notification: PushNotification,
    ) -> int:
        """
        Send a notification to all devices registered for a user.

        Returns:
            Number of successful deliveries
        """
        tokens = db_service.get_user_device_tokens(user_id)
        if not tokens:
            print(f"[APNs] No device tokens for user {user_id}")
            return 0

        success_count = 0
        for token_record in tokens:
            device_token = token_record.get("device_token")
            if device_token:
                if await self.send_notification(device_token, notification):
                    success_count += 1

        return success_count


# Notification templates
def import_completed_notification(
    candidates_count: int,
    countries: list[str],
) -> PushNotification:
    """Create notification for completed import scan."""
    if candidates_count == 0:
        body = "No new countries found in your emails and calendar."
    elif candidates_count == 1:
        body = f"Found 1 new country: {countries[0]}. Tap to review."
    else:
        preview = ", ".join(countries[:3])
        if len(countries) > 3:
            preview += f" and {len(countries) - 3} more"
        body = f"Found {candidates_count} countries: {preview}. Tap to review."

    return PushNotification(
        title="Import Complete",
        body=body,
        category="IMPORT_REVIEW",
        data={"action": "review_import"},
    )


def import_failed_notification(error: str) -> PushNotification:
    """Create notification for failed import scan."""
    return PushNotification(
        title="Import Failed",
        body=f"Could not scan your emails: {error}",
        category="IMPORT_ERROR",
    )


def new_location_detected_notification(
    region_name: str,
    region_type: str,
) -> PushNotification:
    """Create notification for GPS-detected new location."""
    if region_type == "country":
        body = f"You're in {region_name}! Would you like to add it to your map?"
    elif region_type == "us_state":
        body = f"You're in {region_name}! Add it to your visited states?"
    else:
        body = f"New location detected: {region_name}. Add it to your map?"

    return PushNotification(
        title="New Location",
        body=body,
        category="NEW_LOCATION",
        data={
            "action": "confirm_location",
            "region_name": region_name,
            "region_type": region_type,
        },
    )


# Singleton instance
apns_service = APNsService()
