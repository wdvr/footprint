"""Friend and friendship models."""

from datetime import datetime
from enum import Enum

from pydantic import BaseModel, ConfigDict, Field


class FriendRequestStatus(str, Enum):
    """Status of a friend request."""

    PENDING = "pending"
    ACCEPTED = "accepted"
    REJECTED = "rejected"


class FriendRequest(BaseModel):
    """Friend request model."""

    model_config = ConfigDict(from_attributes=True)

    request_id: str = Field(..., description="Unique request identifier")
    from_user_id: str = Field(..., description="User who sent the request")
    to_user_id: str = Field(..., description="User who received the request")
    status: FriendRequestStatus = Field(
        default=FriendRequestStatus.PENDING, description="Request status"
    )
    message: str | None = Field(None, description="Optional message with request")
    created_at: datetime = Field(
        default_factory=datetime.utcnow, description="Request creation time"
    )
    updated_at: datetime = Field(
        default_factory=datetime.utcnow, description="Last update time"
    )


class Friendship(BaseModel):
    """Friendship model (bidirectional relationship)."""

    model_config = ConfigDict(from_attributes=True)

    user_id: str = Field(..., description="One user in the friendship")
    friend_id: str = Field(..., description="The other user in the friendship")
    created_at: datetime = Field(
        default_factory=datetime.utcnow, description="When friendship was established"
    )


class FriendProfile(BaseModel):
    """Friend profile for display (public info only)."""

    user_id: str
    display_name: str | None = None
    profile_picture_url: str | None = None
    countries_visited: int = 0
    us_states_visited: int = 0
    canadian_provinces_visited: int = 0


class FriendComparison(BaseModel):
    """Comparison between user and friend's travel stats."""

    friend: FriendProfile
    common_countries: list[str] = Field(
        default_factory=list, description="Countries both have visited"
    )
    friend_unique_countries: list[str] = Field(
        default_factory=list, description="Countries only friend has visited"
    )
    user_unique_countries: list[str] = Field(
        default_factory=list, description="Countries only user has visited"
    )


class FriendRequestCreate(BaseModel):
    """Create a friend request."""

    to_user_id: str = Field(..., description="User to send request to")
    message: str | None = Field(None, description="Optional message")


class FriendRequestResponse(BaseModel):
    """Response to a friend request."""

    accept: bool = Field(..., description="True to accept, False to reject")
