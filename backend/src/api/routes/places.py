"""Visited places API routes with extended region type support."""

from fastapi import APIRouter, Depends, HTTPException, Query, status
from pydantic import BaseModel

from src.api.routes.auth import get_current_user
from src.models.visited_place import (
    PlaceStatus,
    RegionType,
    VisitedPlaceCreate,
    VisitedPlaceUpdate,
    get_region_total,
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


class ExtendedPlaceStatsResponse(BaseModel):
    """User's visited places statistics with international regions."""

    # Original stats
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

    # International region stats
    australian_states_visited: int
    australian_states_total: int
    australian_states_percentage: float
    australian_states_bucket_list: int
    mexican_states_visited: int
    mexican_states_total: int
    mexican_states_percentage: float
    mexican_states_bucket_list: int
    brazilian_states_visited: int
    brazilian_states_total: int
    brazilian_states_percentage: float
    brazilian_states_bucket_list: int
    german_states_visited: int
    german_states_total: int
    german_states_percentage: float
    german_states_bucket_list: int
    indian_states_visited: int
    indian_states_total: int
    indian_states_percentage: float
    indian_states_bucket_list: int
    chinese_provinces_visited: int
    chinese_provinces_total: int
    chinese_provinces_percentage: float
    chinese_provinces_bucket_list: int

    # Aggregate totals
    total_regions_visited: int
    total_bucket_list: int
    total_international_regions_visited: int
    total_international_regions_available: int


def _is_visited(place: dict) -> bool:
    """Check if place has 'visited' status (not bucket_list)."""
    return place.get("status", "visited") == "visited"


def _is_bucket_list(place: dict) -> bool:
    """Check if place has 'bucket_list' status."""
    return place.get("status") == "bucket_list"


def _count_places_by_type(places: list[dict]) -> dict[str, dict[str, int]]:
    """Count visited and bucket_list places by region type."""
    counts = {
        "country": {"visited": 0, "bucket_list": 0},
        "us_state": {"visited": 0, "bucket_list": 0},
        "canadian_province": {"visited": 0, "bucket_list": 0},
        "australian_state": {"visited": 0, "bucket_list": 0},
        "mexican_state": {"visited": 0, "bucket_list": 0},
        "brazilian_state": {"visited": 0, "bucket_list": 0},
        "german_state": {"visited": 0, "bucket_list": 0},
        "indian_state": {"visited": 0, "bucket_list": 0},
        "chinese_province": {"visited": 0, "bucket_list": 0},
    }

    for p in places:
        region_type = p.get("region_type")
        if region_type in counts:
            if _is_visited(p):
                counts[region_type]["visited"] += 1
            elif _is_bucket_list(p):
                counts[region_type]["bucket_list"] += 1

    return counts


def _convert_to_response(place: dict) -> VisitedPlaceResponse:
    """Convert database place to response model."""
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
        marked_at=place.get("marked_at", ""),
        sync_version=place.get("sync_version", 1),
        is_deleted=place.get("is_deleted", False),
    )


@router.get("/", response_model=PlacesListResponse)
async def list_places(
    user_id: str = Depends(get_current_user),
    region_type: RegionType | None = Query(None, description="Filter by region type"),
    status: PlaceStatus | None = Query(None, description="Filter by status"),
    limit: int = Query(1000, ge=1, le=1000, description="Maximum number of results"),
    offset: int = Query(0, ge=0, description="Offset for pagination"),
):
    """Get user's visited places with optional filtering."""
    try:
        # Convert enum to string for service layer
        region_type_str = region_type.value if region_type else None
        status_str = status.value if status else None

        places = db_service.get_user_visited_places(
            user_id, region_type_str, status_str, limit, offset
        )

        response_places = [_convert_to_response(p) for p in places]

        return PlacesListResponse(places=response_places, total=len(response_places))
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to retrieve places: {str(e)}",
        ) from e


@router.post(
    "/", response_model=VisitedPlaceResponse, status_code=status.HTTP_201_CREATED
)
async def create_place(
    place: VisitedPlaceCreate,
    user_id: str = Depends(get_current_user),
):
    """Create a new visited place."""
    try:
        # Check if place already exists
        existing = db_service.get_visited_place(
            user_id, place.region_type.value, place.region_code
        )
        if existing and not existing.get("is_deleted", False):
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT, detail="Place already exists"
            )

        # Convert to dict for database
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
        }

        created_place = db_service.create_visited_place(
            user_id, place.region_type.value, place.region_code, place_data
        )

        return _convert_to_response(created_place)

    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to create place: {str(e)}",
        ) from e


@router.post("/batch", response_model=BatchCreateResponse)
async def batch_create_places(
    request: BatchCreateRequest,
    user_id: str = Depends(get_current_user),
):
    """Batch create multiple visited places."""
    created_places = []

    try:
        for place in request.places:
            # Check if place already exists
            existing = db_service.get_visited_place(
                user_id, place.region_type.value, place.region_code
            )
            if existing and not existing.get("is_deleted", False):
                continue  # Skip existing places

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
            }

            created_place = db_service.create_visited_place(
                user_id, place.region_type.value, place.region_code, place_data
            )
            created_places.append(created_place)

        response_places = [_convert_to_response(p) for p in created_places]

        return BatchCreateResponse(created=len(created_places), places=response_places)

    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to batch create places: {str(e)}",
        ) from e


@router.get("/{region_type}/{region_code}", response_model=VisitedPlaceResponse)
async def get_place(
    region_type: RegionType,
    region_code: str,
    user_id: str = Depends(get_current_user),
):
    """Get a specific visited place."""
    try:
        place = db_service.get_visited_place(user_id, region_type.value, region_code)
        if not place or place.get("is_deleted", False):
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND, detail="Place not found"
            )

        return _convert_to_response(place)

    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to get place: {str(e)}",
        ) from e


@router.patch("/{region_type}/{region_code}", response_model=VisitedPlaceResponse)
async def update_place(
    region_type: RegionType,
    region_code: str,
    updates: VisitedPlaceUpdate,
    user_id: str = Depends(get_current_user),
):
    """Update an existing visited place."""
    try:
        # Check if place exists
        existing = db_service.get_visited_place(user_id, region_type.value, region_code)
        if not existing or existing.get("is_deleted", False):
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND, detail="Place not found"
            )

        # Convert updates to dict, only including non-None values
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

        updated_place = db_service.update_visited_place(
            user_id, region_type.value, region_code, update_data
        )

        return _convert_to_response(updated_place)

    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to update place: {str(e)}",
        ) from e


@router.delete("/{region_type}/{region_code}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_place(
    region_type: RegionType,
    region_code: str,
    user_id: str = Depends(get_current_user),
):
    """Delete a visited place (soft delete for sync)."""
    try:
        # Check if place exists
        existing = db_service.get_visited_place(user_id, region_type.value, region_code)
        if not existing or existing.get("is_deleted", False):
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND, detail="Place not found"
            )

        db_service.delete_visited_place(user_id, region_type.value, region_code)

    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to delete place: {str(e)}",
        ) from e


@router.get("/stats", response_model=ExtendedPlaceStatsResponse)
async def get_place_stats(user_id: str = Depends(get_current_user)):
    """Get user's visited places statistics with international regions."""
    try:
        places = db_service.get_user_visited_places(user_id)
        counts = _count_places_by_type(places)

        # Calculate percentages and build response
        def safe_percentage(visited: int, total: int) -> float:
            return (visited / total * 100) if total > 0 else 0.0

        # Count total international regions visited
        total_international_visited = sum(
            [
                counts["australian_state"]["visited"],
                counts["mexican_state"]["visited"],
                counts["brazilian_state"]["visited"],
                counts["german_state"]["visited"],
                counts["indian_state"]["visited"],
                counts["chinese_province"]["visited"],
            ]
        )

        # Calculate total regions visited
        total_visited = sum(
            [
                counts["country"]["visited"],
                counts["us_state"]["visited"],
                counts["canadian_province"]["visited"],
                total_international_visited,
            ]
        )

        # Calculate total bucket list items
        total_bucket_list = sum(
            [counts[region_type]["bucket_list"] for region_type in counts.keys()]
        )

        return ExtendedPlaceStatsResponse(
            # Original stats
            countries_visited=counts["country"]["visited"],
            countries_total=get_region_total(RegionType.COUNTRY),
            countries_percentage=safe_percentage(
                counts["country"]["visited"], get_region_total(RegionType.COUNTRY)
            ),
            countries_bucket_list=counts["country"]["bucket_list"],
            us_states_visited=counts["us_state"]["visited"],
            us_states_total=get_region_total(RegionType.US_STATE),
            us_states_percentage=safe_percentage(
                counts["us_state"]["visited"], get_region_total(RegionType.US_STATE)
            ),
            us_states_bucket_list=counts["us_state"]["bucket_list"],
            canadian_provinces_visited=counts["canadian_province"]["visited"],
            canadian_provinces_total=get_region_total(RegionType.CANADIAN_PROVINCE),
            canadian_provinces_percentage=safe_percentage(
                counts["canadian_province"]["visited"],
                get_region_total(RegionType.CANADIAN_PROVINCE),
            ),
            canadian_provinces_bucket_list=counts["canadian_province"]["bucket_list"],
            # International region stats
            australian_states_visited=counts["australian_state"]["visited"],
            australian_states_total=get_region_total(RegionType.AUSTRALIAN_STATE),
            australian_states_percentage=safe_percentage(
                counts["australian_state"]["visited"],
                get_region_total(RegionType.AUSTRALIAN_STATE),
            ),
            australian_states_bucket_list=counts["australian_state"]["bucket_list"],
            mexican_states_visited=counts["mexican_state"]["visited"],
            mexican_states_total=get_region_total(RegionType.MEXICAN_STATE),
            mexican_states_percentage=safe_percentage(
                counts["mexican_state"]["visited"],
                get_region_total(RegionType.MEXICAN_STATE),
            ),
            mexican_states_bucket_list=counts["mexican_state"]["bucket_list"],
            brazilian_states_visited=counts["brazilian_state"]["visited"],
            brazilian_states_total=get_region_total(RegionType.BRAZILIAN_STATE),
            brazilian_states_percentage=safe_percentage(
                counts["brazilian_state"]["visited"],
                get_region_total(RegionType.BRAZILIAN_STATE),
            ),
            brazilian_states_bucket_list=counts["brazilian_state"]["bucket_list"],
            german_states_visited=counts["german_state"]["visited"],
            german_states_total=get_region_total(RegionType.GERMAN_STATE),
            german_states_percentage=safe_percentage(
                counts["german_state"]["visited"],
                get_region_total(RegionType.GERMAN_STATE),
            ),
            german_states_bucket_list=counts["german_state"]["bucket_list"],
            indian_states_visited=counts["indian_state"]["visited"],
            indian_states_total=get_region_total(RegionType.INDIAN_STATE),
            indian_states_percentage=safe_percentage(
                counts["indian_state"]["visited"],
                get_region_total(RegionType.INDIAN_STATE),
            ),
            indian_states_bucket_list=counts["indian_state"]["bucket_list"],
            chinese_provinces_visited=counts["chinese_province"]["visited"],
            chinese_provinces_total=get_region_total(RegionType.CHINESE_PROVINCE),
            chinese_provinces_percentage=safe_percentage(
                counts["chinese_province"]["visited"],
                get_region_total(RegionType.CHINESE_PROVINCE),
            ),
            chinese_provinces_bucket_list=counts["chinese_province"]["bucket_list"],
            # Aggregate totals
            total_regions_visited=total_visited,
            total_bucket_list=total_bucket_list,
            total_international_regions_visited=total_international_visited,
            total_international_regions_available=sum(
                [
                    get_region_total(RegionType.AUSTRALIAN_STATE),
                    get_region_total(RegionType.MEXICAN_STATE),
                    get_region_total(RegionType.BRAZILIAN_STATE),
                    get_region_total(RegionType.GERMAN_STATE),
                    get_region_total(RegionType.INDIAN_STATE),
                    get_region_total(RegionType.CHINESE_PROVINCE),
                ]
            ),
        )

    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to get stats: {str(e)}",
        ) from e
