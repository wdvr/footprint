"""Feedback and feature request API routes."""

import uuid
from typing import Any

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel

from ...models.feedback import (
    Feedback,
    FeedbackCreate,
    FeedbackResponse,
    FeedbackStatus,
    FeedbackType,
)
from ...services.dynamodb import db_service
from .auth import get_current_user

router = APIRouter(prefix="/feedback", tags=["feedback"])


# Public feedback model (for website)
class PublicFeedbackCreate(BaseModel):
    """Public feedback submission from website."""

    name: str | None = None
    email: str | None = None
    type: str = "feedback"
    message: str
    source: str = "website"


class PublicFeedbackResponse(BaseModel):
    """Response for public feedback submission."""

    feedback_id: str
    message: str


@router.post(
    "/public",
    response_model=PublicFeedbackResponse,
    status_code=status.HTTP_201_CREATED,
)
async def submit_public_feedback(feedback: PublicFeedbackCreate):
    """Submit anonymous feedback from website (no auth required)."""
    feedback_id = str(uuid.uuid4())

    db_service.create_public_feedback(
        feedback_id=feedback_id,
        feedback_type=feedback.type,
        message=feedback.message,
        name=feedback.name,
        email=feedback.email,
        source=feedback.source,
    )

    return PublicFeedbackResponse(
        feedback_id=feedback_id,
        message="Thank you for your feedback!",
    )


@router.post("/", response_model=FeedbackResponse, status_code=status.HTTP_201_CREATED)
async def submit_feedback(
    feedback: FeedbackCreate,
    current_user: dict[str, Any] = Depends(get_current_user),
):
    """Submit feedback or feature request."""
    user_id = current_user["user_id"]
    feedback_id = str(uuid.uuid4())

    result = db_service.create_feedback(
        user_id=user_id,
        feedback_id=feedback_id,
        feedback_type=feedback.type.value,
        title=feedback.title,
        description=feedback.description,
        app_version=feedback.app_version,
        device_info=feedback.device_info,
    )

    return FeedbackResponse(
        feedback_id=result["feedback_id"],
        type=FeedbackType(result["type"]),
        title=result["title"],
        status=FeedbackStatus(result["status"]),
        created_at=result["created_at"],
    )


@router.get("/", response_model=list[FeedbackResponse])
async def get_my_feedback(
    current_user: dict[str, Any] = Depends(get_current_user),
):
    """Get all feedback submitted by the current user."""
    user_id = current_user["user_id"]
    items = db_service.get_user_feedback(user_id)

    return [
        FeedbackResponse(
            feedback_id=item["feedback_id"],
            type=FeedbackType(item["type"]),
            title=item["title"],
            status=FeedbackStatus(item["status"]),
            created_at=item["created_at"],
        )
        for item in items
    ]


@router.get("/{feedback_id}", response_model=Feedback)
async def get_feedback_detail(
    feedback_id: str,
    current_user: dict[str, Any] = Depends(get_current_user),
):
    """Get detailed feedback by ID."""
    user_id = current_user["user_id"]
    items = db_service.get_user_feedback(user_id)

    for item in items:
        if item["feedback_id"] == feedback_id:
            return Feedback(
                feedback_id=item["feedback_id"],
                user_id=item["user_id"],
                type=FeedbackType(item["type"]),
                title=item["title"],
                description=item["description"],
                status=FeedbackStatus(item["status"]),
                app_version=item.get("app_version"),
                device_info=item.get("device_info"),
                created_at=item["created_at"],
                updated_at=item["updated_at"],
            )

    raise HTTPException(
        status_code=status.HTTP_404_NOT_FOUND,
        detail="Feedback not found",
    )
