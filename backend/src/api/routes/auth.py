"""Authentication API routes."""

from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from pydantic import BaseModel

from src.services.auth import TokenResponse, auth_service
from src.services.dynamodb import db_service

router = APIRouter(prefix="/auth", tags=["auth"])
security = HTTPBearer()


class AppleAuthRequest(BaseModel):
    """Apple Sign In authentication request."""

    identity_token: str
    authorization_code: str | None = None
    user_name: str | None = None  # Optional - only provided on first sign in


class RefreshTokenRequest(BaseModel):
    """Token refresh request."""

    refresh_token: str


class UserResponse(BaseModel):
    """User data response."""

    user_id: str
    email: str | None
    display_name: str | None
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
        countries_visited=current_user.get("countries_visited", 0),
        us_states_visited=current_user.get("us_states_visited", 0),
        canadian_provinces_visited=current_user.get("canadian_provinces_visited", 0),
    )


@router.delete("/me", status_code=status.HTTP_204_NO_CONTENT)
async def delete_account(current_user: dict = Depends(get_current_user)):
    """
    Delete current user account.

    Permanently deletes the user account and all associated data.
    """
    # TODO: Implement account deletion
    # This should delete all user data, visited places, etc.
    raise HTTPException(
        status_code=status.HTTP_501_NOT_IMPLEMENTED,
        detail="Account deletion not yet implemented",
    )
