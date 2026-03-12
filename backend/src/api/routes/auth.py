"""Authentication API routes."""

import logging

from fastapi import APIRouter, Depends, HTTPException, Response, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from pydantic import BaseModel

from src.services.auth import TokenResponse, auth_service
from src.services.dynamodb import db_service, table

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/auth", tags=["auth"])
security = HTTPBearer()


class AppleAuthRequest(BaseModel):
    """Apple Sign In authentication request."""

    identity_token: str
    authorization_code: str | None = None
    user_name: str | None = None  # Optional - only provided on first sign in


class GoogleAuthRequest(BaseModel):
    """Google Sign In authentication request."""

    id_token: str


class RefreshTokenRequest(BaseModel):
    """Token refresh request."""

    refresh_token: str


class UserResponse(BaseModel):
    """User data response."""

    user_id: str
    email: str | None
    display_name: str | None
    auth_provider: str | None
    countries_visited: int
    us_states_visited: int
    canadian_provinces_visited: int


class AuthResponse(BaseModel):
    """Authentication response."""

    user: UserResponse
    tokens: TokenResponse


async def get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(security),
) -> dict:
    """Dependency to get the current authenticated user."""
    token = credentials.credentials
    user_id = auth_service.verify_access_token(token)

    if not user_id:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired token",
            headers={"WWW-Authenticate": "Bearer"},
        )

    user = db_service.get_user(user_id)
    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="User not found",
            headers={"WWW-Authenticate": "Bearer"},
        )

    return user


@router.post("/apple", response_model=AuthResponse)
async def authenticate_apple(request: AppleAuthRequest):
    """
    Authenticate user with Apple Sign In.

    Verifies the Apple identity token and creates/retrieves user account.
    Returns user data and JWT tokens.
    """
    result = await auth_service.authenticate_apple(
        request.identity_token, request.authorization_code
    )

    if not result:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid Apple identity token",
        )

    user, tokens = result

    # Update display name if provided (only on first sign in)
    if request.user_name and not user.get("display_name"):
        user = db_service.update_user(
            user["user_id"], {"display_name": request.user_name}
        )

    user_response = UserResponse(
        user_id=user["user_id"],
        email=user.get("email"),
        display_name=user.get("display_name"),
        auth_provider=user.get("auth_provider"),
        countries_visited=user.get("countries_visited", 0),
        us_states_visited=user.get("us_states_visited", 0),
        canadian_provinces_visited=user.get("canadian_provinces_visited", 0),
    )

    return AuthResponse(user=user_response, tokens=tokens)


@router.post("/google", response_model=AuthResponse)
async def authenticate_google(request: GoogleAuthRequest):
    """
    Authenticate user with Google Sign In.

    Verifies the Google ID token and creates/retrieves user account.
    Returns user data and JWT tokens.
    """
    result = await auth_service.authenticate_google(request.id_token)

    if not result:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid Google ID token",
        )

    user, tokens = result

    user_response = UserResponse(
        user_id=user["user_id"],
        email=user.get("email"),
        display_name=user.get("display_name"),
        auth_provider=user.get("auth_provider"),
        countries_visited=user.get("countries_visited", 0),
        us_states_visited=user.get("us_states_visited", 0),
        canadian_provinces_visited=user.get("canadian_provinces_visited", 0),
    )

    return AuthResponse(user=user_response, tokens=tokens)


@router.post("/refresh", response_model=TokenResponse)
async def refresh_token(request: RefreshTokenRequest):
    """
    Refresh access token.

    Exchange a valid refresh token for new access and refresh tokens.
    """
    tokens = auth_service.refresh_tokens(request.refresh_token)

    if not tokens:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired refresh token",
        )

    return tokens


@router.get("/me", response_model=UserResponse)
async def get_current_user_info(current_user: dict = Depends(get_current_user)):
    """
    Get current user information.

    Returns the authenticated user's profile data.
    """
    return UserResponse(
        user_id=current_user["user_id"],
        email=current_user.get("email"),
        display_name=current_user.get("display_name"),
        auth_provider=current_user.get("auth_provider"),
        countries_visited=current_user.get("countries_visited", 0),
        us_states_visited=current_user.get("us_states_visited", 0),
        canadian_provinces_visited=current_user.get("canadian_provinces_visited", 0),
    )


@router.delete("/me", status_code=status.HTTP_204_NO_CONTENT)
async def delete_account(current_user: dict = Depends(get_current_user)):
    """
    Delete current user account.

    Permanently deletes the user account and all associated data.
    This includes: PROFILE, PLACE#*, SYNC#*, FRIEND#*, FRIEND_REQUEST#*,
    FEEDBACK#*, GOOGLE_TOKENS, DEVICE_TOKEN#*, IMPORT_JOB#*, IMPORT_RESULTS#*.
    Also removes bidirectional friendships from other users.
    """
    user_id = current_user["user_id"]
    user_pk = f"USER#{user_id}"

    logger.info(f"Starting account deletion for user {user_id}")

    # Step 1: Query ALL items with pk=USER#{user_id}
    all_items = []
    friend_ids = []
    last_evaluated_key = None

    while True:
        query_kwargs = {
            "KeyConditionExpression": "pk = :pk",
            "ExpressionAttributeValues": {":pk": user_pk},
            "ProjectionExpression": "pk, sk",
        }
        if last_evaluated_key:
            query_kwargs["ExclusiveStartKey"] = last_evaluated_key

        response = table.query(**query_kwargs)
        items = response.get("Items", [])
        all_items.extend(items)

        # Collect friend IDs for bidirectional cleanup
        for item in items:
            sk = item["sk"]
            if sk.startswith("FRIEND#") and not sk.startswith("FRIEND_REQUEST#"):
                friend_id = sk.removeprefix("FRIEND#")
                friend_ids.append(friend_id)

        last_evaluated_key = response.get("LastEvaluatedKey")
        if not last_evaluated_key:
            break

    logger.info(
        f"Found {len(all_items)} items to delete for user {user_id}, "
        f"{len(friend_ids)} friendships to clean up"
    )

    # Step 2: Batch-delete all user items
    with table.batch_writer() as batch:
        for item in all_items:
            batch.delete_item(Key={"pk": item["pk"], "sk": item["sk"]})

    # Step 3: Remove friendships where OTHER users have FRIEND#{user_id} as sk
    for friend_id in friend_ids:
        friend_pk = f"USER#{friend_id}"
        friend_sk = f"FRIEND#{user_id}"
        table.delete_item(Key={"pk": friend_pk, "sk": friend_sk})

    logger.info(f"Account deletion completed for user {user_id}")

    return Response(status_code=status.HTTP_204_NO_CONTENT)
