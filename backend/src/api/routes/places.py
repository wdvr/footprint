"""Visited places API routes."""

from fastapi import APIRouter, Depends, HTTPException, Query, status
from pydantic import BaseModel

from src.api.routes.auth import get_current_user
from src.models.visited_place import (
    PlaceStatus,
    RegionType,
    VisitedPlaceCreate,
    VisitedPlaceUpdate,
    VisitType,
)
from src.services.dynamodb import db_service

router = APIRouter(prefix="/places", tags=["places"])


class VisitedPlaceResponse(BaseModel):
    """Response model for a visited place."""

    user_id: str
    region_type: str
    region_code: str
    region_name: str
    status: str = "visited"
    visit_type: str = "visited"
    visited_date: str | None = None
    departure_date: str | None = None
    notes: str | None = None
    marked_at: str
    sync_version: int
    is_deleted: bool = False


class PlacesListResponse(BaseModel):
    """Response model for list of visited places."""

    places: list[VisitedPlaceResponse]
    total: int


class BatchCreateRequest(BaseModel):
    """Request for batch creating visited places."""

    places: list[VisitedPlaceCreate]


class BatchCreateResponse(BaseModel):
    """Response for batch create operation."""

    created: int
    places: list[VisitedPlaceResponse]


class PlaceStatsResponse(BaseModel):
    """User's visited places statistics."""

    countries_visited: int
    countries_total: int
    countries_percentage: float
    countries_bucket_list: int
    us_states_visited: int
    us_states_total: int
    us_states_percentage: float
    us_states_bucket_list: int
    canadian_provinces_visited: int
    canadian_provinces_total: int
    canadian_provinces_percentage: float
    canadian_provinces_bucket_list: int
    total_regions_visited: int
    total_bucket_list: int


# Geographic totals
TOTAL_COUNTRIES = 195
TOTAL_US_STATES = 51  # 50 states + DC
TOTAL_CANADIAN_PROVINCES = 13  # 10 provinces + 3 territories


def _is_visited(place: dict) -> bool:
    """Check if place has 'visited' status (not bucket_list)."""
    return place.get("status", "visited") == "visited"


def _is_bucket_list(place: dict) -> bool:
    """Check if place has 'bucket_list' status."""
    return place.get("status") == "bucket_list"


def _count_places_by_type(
    places: list[dict],
) -> dict[str, dict[str, int]]:
    """Count visited and bucket_list places by region type."""
    counts = {
        "country": {"visited": 0, "bucket_list": 0},
        "us_state": {"visited": 0, "bucket_list": 0},
        "canadian_province": {"visited": 0, "bucket_list": 0},
    }
    for p in places:
        region_type = p.get("region_type")
        if region_type in counts:
            if _is_visited(p):
                counts[region_type]["visited"] += 1
            elif _is_bucket_list(p):
                counts[region_type]["bucket_list"] += 1
    return counts


def _place_to_response(place: dict) -> VisitedPlaceResponse:
    """Convert DynamoDB item to response model."""
    return VisitedPlaceResponse(
        user_id=place.get("user_id", ""),
        region_type=place.get("region_type", ""),
        region_code=place.get("region_code", ""),
        region_name=place.get("region_name", ""),
        status=place.get("status", "visited"),
        visit_type=place.get("visit_type", "visited"),
        visited_date=place.get("visited_date"),
        departure_date=place.get("departure_date"),
        notes=place.get("notes"),
        marked_at=place.get("created_at", ""),
        sync_version=place.get("sync_version", 1),
        is_deleted=place.get("is_deleted", False),
    )


@router.get("", response_model=PlacesListResponse)
async def list_visited_places(
    region_type: RegionType | None = Query(None, description="Filter by region type"),
    status: PlaceStatus | None = Query(None, description="Filter by status"),
    current_user: dict = Depends(get_current_user),
):
    """
    List all visited places for the current user.

    Optionally filter by region type (country, us_state, canadian_province)
    and/or status (visited, bucket_list).
    """
    user_id = current_user["user_id"]
    region_type_str = region_type.value if region_type else None
    places = db_service.get_user_visited_places(user_id, region_type_str)

    # Filter out soft-deleted places
    active_places = [p for p in places if not p.get("is_deleted", False)]

    # Filter by status if specified
    if status:
        active_places = [
            p for p in active_places if p.get("status", "visited") == status.value
        ]

    return PlacesListResponse(
        places=[_place_to_response(p) for p in active_places],
        total=len(active_places),
    )


@router.post(
    "", response_model=VisitedPlaceResponse, status_code=status.HTTP_201_CREATED
)
async def create_visited_place(
    place: VisitedPlaceCreate,
    current_user: dict = Depends(get_current_user),
):
    """
    Mark a new place as visited.

    Creates a record that the user has visited this region.
    """
    user_id = current_user["user_id"]

    # Check if place already exists
    existing = db_service.get_visited_place(
        user_id, place.region_type.value, place.region_code
    )

    if existing and not existing.get("is_deleted", False):
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="This place is already marked as visited",
        )

    # Create or restore the place
    place_data = {
        "region_type": place.region_type.value,
        "region_code": place.region_code,
        "region_name": place.region_name,
        "status": place.status.value,
        "visit_type": place.visit_type.value,
        "visited_date": place.visited_date.isoformat() if place.visited_date else None,
        "departure_date": place.departure_date.isoformat() if place.departure_date else None,
        "notes": place.notes,
        "sync_version": 1,
        "is_deleted": False,
    }

    if existing:
        # Restore soft-deleted place
        result = db_service.update_visited_place(
            user_id, place.region_type.value, place.region_code, place_data
        )
    else:
        result = db_service.create_visited_place(user_id, place_data)

    # Update user stats
    _update_user_stats(user_id)

    return _place_to_response(result)


@router.get("/stats", response_model=PlaceStatsResponse)
async def get_place_stats(current_user: dict = Depends(get_current_user)):
    """
    Get user's visited places statistics.

    Returns counts and percentages for each region type, including bucket list.
    """
    user_id = current_user["user_id"]
    places = db_service.get_user_visited_places(user_id)
    active_places = [p for p in places if not p.get("is_deleted", False)]
    counts = _count_places_by_type(active_places)

    countries = counts["country"]["visited"]
    us_states = counts["us_state"]["visited"]
    canadian_provinces = counts["canadian_province"]["visited"]
    countries_bucket = counts["country"]["bucket_list"]
    us_states_bucket = counts["us_state"]["bucket_list"]
    canadian_provinces_bucket = counts["canadian_province"]["bucket_list"]

    return PlaceStatsResponse(
        countries_visited=countries,
        countries_total=TOTAL_COUNTRIES,
        countries_percentage=round((countries / TOTAL_COUNTRIES) * 100, 2),
        countries_bucket_list=countries_bucket,
        us_states_visited=us_states,
        us_states_total=TOTAL_US_STATES,
        us_states_percentage=round((us_states / TOTAL_US_STATES) * 100, 2),
        us_states_bucket_list=us_states_bucket,
        canadian_provinces_visited=canadian_provinces,
        canadian_provinces_total=TOTAL_CANADIAN_PROVINCES,
        canadian_provinces_percentage=round(
            (canadian_provinces / TOTAL_CANADIAN_PROVINCES) * 100, 2
        ),
        canadian_provinces_bucket_list=canadian_provinces_bucket,
        total_regions_visited=countries + us_states + canadian_provinces,
        total_bucket_list=countries_bucket + us_states_bucket + canadian_provinces_bucket,
    )


@router.get("/{region_type}/{region_code}", response_model=VisitedPlaceResponse)
async def get_visited_place(
    region_type: RegionType,
    region_code: str,
    current_user: dict = Depends(get_current_user),
):
    """
    Get a specific visited place.

    Returns the details of a visited place by region type and code.
    """
    user_id = current_user["user_id"]
    place = db_service.get_visited_place(user_id, region_type.value, region_code)

    if not place or place.get("is_deleted", False):
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Visited place not found",
        )

    return _place_to_response(place)


@router.patch("/{region_type}/{region_code}", response_model=VisitedPlaceResponse)
async def update_visited_place(
    region_type: RegionType,
    region_code: str,
    updates: VisitedPlaceUpdate,
    current_user: dict = Depends(get_current_user),
):
    """
    Update a visited place.

    Update the visited date or notes for an existing visited place.
    """
    user_id = current_user["user_id"]
    existing = db_service.get_visited_place(user_id, region_type.value, region_code)

    if not existing or existing.get("is_deleted", False):
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Visited place not found",
        )

    update_data = {}
    if updates.status is not None:
        update_data["status"] = updates.status.value
    if updates.visit_type is not None:
        update_data["visit_type"] = updates.visit_type.value
    if updates.visited_date is not None:
        update_data["visited_date"] = updates.visited_date.isoformat()
    if updates.departure_date is not None:
        update_data["departure_date"] = updates.departure_date.isoformat()
    if updates.notes is not None:
        update_data["notes"] = updates.notes

    # Increment sync version
    update_data["sync_version"] = existing.get("sync_version", 1) + 1

    result = db_service.update_visited_place(
        user_id, region_type.value, region_code, update_data
    )

    # Update user stats if status changed
    if updates.status is not None:
        _update_user_stats(user_id)

    return _place_to_response(result)


@router.delete("/{region_type}/{region_code}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_visited_place(
    region_type: RegionType,
    region_code: str,
    current_user: dict = Depends(get_current_user),
):
    """
    Unmark a place as visited.

    Soft deletes the visited place record (for sync purposes).
    """
    user_id = current_user["user_id"]
    existing = db_service.get_visited_place(user_id, region_type.value, region_code)

    if not existing or existing.get("is_deleted", False):
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Visited place not found",
        )

    db_service.delete_visited_place(user_id, region_type.value, region_code)

    # Update user stats
    _update_user_stats(user_id)


@router.post("/batch", response_model=BatchCreateResponse)
async def batch_create_places(
    request: BatchCreateRequest,
    current_user: dict = Depends(get_current_user),
):
    """
    Batch create multiple visited places.

    Efficiently mark multiple places as visited in a single request.
    """
    user_id = current_user["user_id"]

    places_data = []
    for place in request.places:
        place_data = {
            "region_type": place.region_type.value,
            "region_code": place.region_code,
            "region_name": place.region_name,
            "status": place.status.value,
            "visit_type": place.visit_type.value,
            "visited_date": place.visited_date.isoformat()
            if place.visited_date
            else None,
            "departure_date": place.departure_date.isoformat()
            if place.departure_date
            else None,
            "notes": place.notes,
            "sync_version": 1,
            "is_deleted": False,
        }
        places_data.append(place_data)

    created = db_service.batch_create_places(user_id, places_data)

    # Update user stats
    _update_user_stats(user_id)

    return BatchCreateResponse(
        created=len(created),
        places=[_place_to_response(p) for p in created],
    )


def _update_user_stats(user_id: str) -> None:
    """Update user's visited places statistics."""
    places = db_service.get_user_visited_places(user_id)
    active_places = [p for p in places if not p.get("is_deleted", False)]
    counts = _count_places_by_type(active_places)

    db_service.update_user(
        user_id,
        {
            "countries_visited": counts["country"]["visited"],
            "us_states_visited": counts["us_state"]["visited"],
            "canadian_provinces_visited": counts["canadian_province"]["visited"],
            "countries_bucket_list": counts["country"]["bucket_list"],
            "us_states_bucket_list": counts["us_state"]["bucket_list"],
            "canadian_provinces_bucket_list": counts["canadian_province"]["bucket_list"],
        },
    )
