"""Feedback and feature request models."""

from datetime import datetime
from enum import Enum

from pydantic import BaseModel, ConfigDict, Field


class FeedbackType(str, Enum):
    """Type of feedback submission."""

    BUG = "bug"
    FEATURE = "feature"
    IMPROVEMENT = "improvement"
    GENERAL = "general"


class FeedbackStatus(str, Enum):
    """Status of feedback processing."""

    NEW = "new"
    REVIEWED = "reviewed"
    IN_PROGRESS = "in_progress"
    COMPLETED = "completed"
    DECLINED = "declined"


class Feedback(BaseModel):
    """Feedback model."""

    model_config = ConfigDict(from_attributes=True)

    feedback_id: str = Field(..., description="Unique feedback identifier")
    user_id: str = Field(..., description="User who submitted the feedback")
    type: FeedbackType = Field(..., description="Type of feedback")
    title: str = Field(..., description="Short title/summary")
    description: str = Field(..., description="Detailed description")
    status: FeedbackStatus = Field(
        default=FeedbackStatus.NEW, description="Processing status"
    )
    app_version: str | None = Field(None, description="App version when submitted")
    device_info: str | None = Field(None, description="Device information")
    created_at: datetime = Field(
        default_factory=datetime.utcnow, description="Submission time"
    )
    updated_at: datetime = Field(
        default_factory=datetime.utcnow, description="Last update time"
    )


class FeedbackCreate(BaseModel):
    """Create feedback request."""

    type: FeedbackType = Field(..., description="Type of feedback")
    title: str = Field(..., min_length=3, max_length=100, description="Short title")
    description: str = Field(
        ..., min_length=10, max_length=2000, description="Detailed description"
    )
    app_version: str | None = Field(None, description="App version")
    device_info: str | None = Field(None, description="Device info")


class FeedbackResponse(BaseModel):
    """Feedback response model."""

    feedback_id: str
    type: FeedbackType
    title: str
    status: FeedbackStatus
    created_at: datetime
