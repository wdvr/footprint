"""Friend-related API routes."""

import uuid
from typing import Any

from fastapi import APIRouter, Depends, HTTPException, status

from ...models.friend import (
    FriendComparison,
    FriendProfile,
    FriendRequest,
    FriendRequestCreate,
    FriendRequestResponse,
    FriendRequestStatus,
)
from ...services.dynamodb import db_service
from .auth import get_current_user

router = APIRouter(prefix="/friends", tags=["friends"])


@router.get("/", response_model=list[FriendProfile])
async def get_friends(current_user: dict[str, Any] = Depends(get_current_user)):
    """Get all friends."""
    user_id = current_user["user_id"]
    friendships = db_service.get_friends(user_id)

    friends = []
    for friendship in friendships:
        friend_id = friendship["friend_id"]
        friend_data = db_service.get_user(friend_id)
        if friend_data:
            friends.append(
                FriendProfile(
                    user_id=friend_id,
                    display_name=friend_data.get("display_name"),
                    profile_picture_url=friend_data.get("profile_picture_url"),
                    countries_visited=friend_data.get("countries_visited", 0),
                    us_states_visited=friend_data.get("us_states_visited", 0),
                    canadian_provinces_visited=friend_data.get(
                        "canadian_provinces_visited", 0
                    ),
                )
            )

    return friends


@router.get("/requests", response_model=list[FriendRequest])
async def get_friend_requests(current_user: dict[str, Any] = Depends(get_current_user)):
    """Get pending friend requests."""
    user_id = current_user["user_id"]
    requests = db_service.get_friend_requests(user_id)

    return [
        FriendRequest(
            request_id=req["request_id"],
            from_user_id=req["from_user_id"],
            to_user_id=req["to_user_id"],
            status=FriendRequestStatus(req["status"]),
            message=req.get("message"),
            created_at=req["created_at"],
            updated_at=req["updated_at"],
        )
        for req in requests
    ]


@router.post("/requests", response_model=FriendRequest)
async def send_friend_request(
    request: FriendRequestCreate,
    current_user: dict[str, Any] = Depends(get_current_user),
):
    """Send a friend request."""
    user_id = current_user["user_id"]

    if user_id == request.to_user_id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Cannot send friend request to yourself",
        )

    # Check if user exists
    to_user = db_service.get_user(request.to_user_id)
    if not to_user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found",
        )

    # Check if already friends
    friends = db_service.get_friends(user_id)
    if any(f["friend_id"] == request.to_user_id for f in friends):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Already friends with this user",
        )

    request_id = str(uuid.uuid4())
    req_data = db_service.create_friend_request(
        from_user_id=user_id,
        to_user_id=request.to_user_id,
        request_id=request_id,
        message=request.message,
    )

    return FriendRequest(
        request_id=req_data["request_id"],
        from_user_id=req_data["from_user_id"],
        to_user_id=req_data["to_user_id"],
        status=FriendRequestStatus(req_data["status"]),
        message=req_data.get("message"),
        created_at=req_data["created_at"],
        updated_at=req_data["updated_at"],
    )


@router.post("/requests/{request_id}/respond")
async def respond_to_friend_request(
    request_id: str,
    response: FriendRequestResponse,
    current_user: dict[str, Any] = Depends(get_current_user),
):
    """Accept or reject a friend request."""
    user_id = current_user["user_id"]

    # Get the request
    requests = db_service.get_friend_requests(user_id)
    request_data = next((r for r in requests if r["request_id"] == request_id), None)

    if not request_data:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Friend request not found",
        )

    if response.accept:
        # Create friendship
        db_service.create_friendship(user_id, request_data["from_user_id"])
        db_service.update_friend_request(user_id, request_id, "accepted")
        return {"message": "Friend request accepted"}
    else:
        db_service.update_friend_request(user_id, request_id, "rejected")
        return {"message": "Friend request rejected"}


@router.delete("/{friend_id}")
async def remove_friend(
    friend_id: str,
    current_user: dict[str, Any] = Depends(get_current_user),
):
    """Remove a friend."""
    user_id = current_user["user_id"]
    db_service.remove_friendship(user_id, friend_id)
    return {"message": "Friend removed"}


@router.get("/{friend_id}/compare", response_model=FriendComparison)
async def compare_with_friend(
    friend_id: str,
    current_user: dict[str, Any] = Depends(get_current_user),
):
    """Compare travel stats with a friend."""
    user_id = current_user["user_id"]

    # Get user's visited places
    user_places = db_service.get_user_visited_places(user_id, region_type="country")
    user_countries = {p["region_code"] for p in user_places if not p.get("is_deleted")}

    # Get friend's visited places
    friend_places = db_service.get_user_visited_places(friend_id, region_type="country")
    friend_countries = {
        p["region_code"] for p in friend_places if not p.get("is_deleted")
    }

    # Get friend profile
    friend_data = db_service.get_user(friend_id)
    if not friend_data:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Friend not found",
        )

    return FriendComparison(
        friend=FriendProfile(
            user_id=friend_id,
            display_name=friend_data.get("display_name"),
            profile_picture_url=friend_data.get("profile_picture_url"),
            countries_visited=friend_data.get("countries_visited", 0),
            us_states_visited=friend_data.get("us_states_visited", 0),
            canadian_provinces_visited=friend_data.get("canadian_provinces_visited", 0),
        ),
        common_countries=list(user_countries & friend_countries),
        friend_unique_countries=list(friend_countries - user_countries),
        user_unique_countries=list(user_countries - friend_countries),
    )
