"""User data models."""

from datetime import datetime
from enum import Enum
from typing import Any

from pydantic import BaseModel, ConfigDict, Field


class AuthProvider(str, Enum):
    """Authentication provider types."""

    APPLE = "apple"
    EMAIL = "email"


class User(BaseModel):
    """User model with full data."""

    model_config = ConfigDict(from_attributes=True)

    user_id: str = Field(..., description="Unique user identifier")
    auth_provider: AuthProvider = Field(..., description="Authentication provider")
    auth_provider_id: str = Field(..., description="Provider-specific user ID")
    email: str | None = Field(None, description="User email (optional for Apple)")
    display_name: str | None = Field(None, description="User display name")
    profile_picture_url: str | None = Field(None, description="Profile picture URL")

    # Travel statistics (computed fields)
    countries_visited: int = Field(default=0, description="Number of countries visited")
    us_states_visited: int = Field(default=0, description="Number of US states visited")
    canadian_provinces_visited: int = Field(
        default=0, description="Number of Canadian provinces visited"
    )

    # Settings
    privacy_settings: dict[str, Any] = Field(
        default_factory=dict, description="User privacy preferences"
    )
    notification_settings: dict[str, Any] = Field(
        default_factory=dict, description="Notification preferences"
    )

    # Timestamps
    created_at: datetime = Field(
        default_factory=datetime.utcnow, description="Account creation time"
    )
    updated_at: datetime = Field(
        default_factory=datetime.utcnow, description="Last update time"
    )
    last_login_at: datetime | None = Field(None, description="Last login time")

    # Sync metadata
    sync_version: int = Field(default=1, description="Data version for sync conflicts")
    last_sync_at: datetime | None = Field(None, description="Last successful sync")


class UserCreate(BaseModel):
    """User creation model."""

    auth_provider: AuthProvider
    auth_provider_id: str
    email: str | None = None
    display_name: str | None = None
    profile_picture_url: str | None = None


class UserUpdate(BaseModel):
    """User update model."""

    display_name: str | None = None
    profile_picture_url: str | None = None
    privacy_settings: dict[str, Any] | None = None
    notification_settings: dict[str, Any] | None = None


class UserStats(BaseModel):
    """User travel statistics."""

    countries_visited: int
    countries_percentage: float
    us_states_visited: int
    us_states_percentage: float
    canadian_provinces_visited: int
    canadian_provinces_percentage: float
    total_regions_visited: int
    total_regions_percentage: float
