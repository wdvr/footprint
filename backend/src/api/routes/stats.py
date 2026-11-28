"""Statistics API routes for continent, timezone, badges, and leaderboard."""

from datetime import datetime

from fastapi import APIRouter, Depends
from pydantic import BaseModel, Field

from src.api.routes.auth import get_current_user
from src.models.badges import (
    BADGES_BY_ID,
    BadgeProgress,
    BadgesResponse,
    BadgeTierProgress,
)
from src.models.geographic import (
    CONTINENT_COUNTRY_COUNTS,
    Continent,
    ContinentStats,
    ContinentStatsResponse,
    TimeZoneStats,
    get_country_continent,
    get_country_timezones,
)
from src.services.dynamodb import db_service
from src.services.medals import MedalResult, evaluate

router = APIRouter(prefix="/stats", tags=["stats"])


# Response models
class LeaderboardEntry(BaseModel):
    """Single entry in the leaderboard."""

    user_id: str
    display_name: str | None = None
    countries_visited: int = 0
    us_states_visited: int = 0
    canadian_provinces_visited: int = 0
    total_regions: int = 0
    rank: int = 0


class LeaderboardResponse(BaseModel):
    """Response model for leaderboard."""

    entries: list[LeaderboardEntry] = Field(..., description="Leaderboard entries")
    user_rank: int | None = Field(None, description="Current user's rank")
    total_friends: int = Field(default=0, description="Total friends in leaderboard")


class ExtendedStatsResponse(BaseModel):
    """Extended statistics including all new features."""

    # Basic stats
    countries_visited: int = 0
    countries_transit: int = 0
    us_states_visited: int = 0
    us_states_transit: int = 0
    canadian_provinces_visited: int = 0
    canadian_provinces_transit: int = 0

    # Continent breakdown
    continents: ContinentStatsResponse | None = None

    # Time zones
    time_zones: TimeZoneStats | None = None

    # Badges summary
    badges_earned: int = 0
    badges_total: int = 0

    # Timeline info
    first_visit_date: str | None = None
    latest_visit_date: str | None = None
    countries_this_year: int = 0


def _count_by_visit_type(places: list[dict], region_type: str) -> tuple[int, int]:
    """Count visited and transit places for a region type."""
    visited = sum(
        1
        for p in places
        if p.get("region_type") == region_type
        and p.get("status", "visited") == "visited"
        and p.get("visit_type", "visited") == "visited"
        and not p.get("is_deleted", False)
    )
    transit = sum(
        1
        for p in places
        if p.get("region_type") == region_type
        and p.get("status", "visited") == "visited"
        and p.get("visit_type") == "transit"
        and not p.get("is_deleted", False)
    )
    return visited, transit


@router.get("/continents", response_model=ContinentStatsResponse)
async def get_continent_stats(current_user: dict = Depends(get_current_user)):
    """
    Get user's statistics broken down by continent.

    Shows number of countries visited in each continent and percentage progress.
    """
    user_id = current_user["user_id"]
    places = db_service.get_user_visited_places(user_id, "country")

    # Get visited country codes (excluding deleted and bucket list)
    visited_countries = [
        p.get("region_code")
        for p in places
        if not p.get("is_deleted", False) and p.get("status", "visited") == "visited"
    ]

    # Group by continent
    continent_stats: dict[Continent, list[str]] = {c: [] for c in Continent}
    for code in visited_countries:
        continent = get_country_continent(code)
        if continent:
            continent_stats[continent].append(code)

    # Build response
    stats = []
    continents_with_visits = 0
    for continent in Continent:
        if continent == Continent.ANTARCTICA:
            continue  # Skip Antarctica for stats

        visited = continent_stats.get(continent, [])
        total = CONTINENT_COUNTRY_COUNTS.get(continent, 0)
        percentage = round((len(visited) / total * 100) if total > 0 else 0, 2)

        if len(visited) > 0:
            continents_with_visits += 1

        stats.append(
            ContinentStats(
                continent=continent.value,
                countries_visited=len(visited),
                countries_total=total,
                percentage=percentage,
                visited_countries=visited,
            )
        )

    return ContinentStatsResponse(
        continents=stats,
        total_continents_visited=continents_with_visits,
    )


@router.get("/timezones", response_model=TimeZoneStats)
async def get_timezone_stats(current_user: dict = Depends(get_current_user)):
    """
    Get user's time zone coverage statistics.

    Shows how many of the world's 24 time zones the user has visited.
    """
    user_id = current_user["user_id"]
    places = db_service.get_user_visited_places(user_id, "country")

    # Get visited country codes
    visited_countries = [
        p.get("region_code")
        for p in places
        if not p.get("is_deleted", False) and p.get("status", "visited") == "visited"
    ]

    # Collect all time zones from visited countries
    visited_zones: set[int] = set()
    zone_countries: dict[int, list[str]] = {}

    for code in visited_countries:
        zones = get_country_timezones(code)
        for zone in zones:
            visited_zones.add(zone)
            if zone not in zone_countries:
                zone_countries[zone] = []
            zone_countries[zone].append(code)

    # Build zones list (UTC-12 to UTC+14)
    zones_list = []
    for offset in range(-12, 15):
        is_visited = offset in visited_zones
        zones_list.append(
            {
                "offset": offset,
                "name": f"UTC{'+' if offset >= 0 else ''}{offset}",
                "visited": is_visited,
                "countries": zone_countries.get(offset, []),
            }
        )

    # Calculate farthest points
    farthest_east = max(visited_zones) if visited_zones else None
    farthest_west = min(visited_zones) if visited_zones else None

    return TimeZoneStats(
        total_zones=24,
        zones_visited=len(visited_zones),
        percentage=round(len(visited_zones) / 24 * 100, 2),
        zones=zones_list,
        farthest_east=farthest_east,
        farthest_west=farthest_west,
    )


def _badge_progress(result: MedalResult) -> BadgeProgress:
    """Map a medal evaluation onto the v1 `BadgeProgress` shape."""
    total = result.progress_total
    progress = int(result.value)
    percentage = min(100.0, round(result.value / total * 100, 2)) if total > 0 else 0
    top = result.highest_award
    return BadgeProgress(
        badge=BADGES_BY_ID[result.definition["id"]],
        unlocked=top is not None,
        unlocked_at=result.awards[0].earned_at if result.awards else None,
        progress=progress,
        progress_total=int(total),
        progress_percentage=percentage,
        tier=top.level if top else None,
        tiers_earned=[
            BadgeTierProgress(
                level=a.level,
                threshold=a.threshold,
                unlocked_at=a.earned_at,
                trigger=a.trigger,
            )
            for a in result.awards
        ],
    )


@router.get("/badges", response_model=BadgesResponse)
async def get_badges(current_user: dict = Depends(get_current_user)):
    """
    Get user's medal (badge) progress and achievements.

    Medals v2: tiered medals evaluated from the user's places in date order, so
    `unlocked_at` is when the first tier was actually reached. Earned medals
    list their tiers; in-progress ones show progress toward the next tier.
    """
    user_id = current_user["user_id"]
    places = db_service.get_user_visited_places(user_id)

    earned = []
    in_progress = []
    for result in evaluate(places):
        progress = _badge_progress(result)
        (earned if progress.unlocked else in_progress).append(progress)

    # Sort by progress percentage (descending) for in-progress
    in_progress.sort(key=lambda x: x.progress_percentage, reverse=True)

    return BadgesResponse(
        earned=earned,
        in_progress=in_progress,
        total_earned=len(earned),
        total_badges=len(earned) + len(in_progress),
    )


@router.get("/leaderboard", response_model=LeaderboardResponse)
async def get_leaderboard(current_user: dict = Depends(get_current_user)):
    """
    Get friends leaderboard with travel stats comparison.

    Shows rankings among friends based on countries visited.
    """
    user_id = current_user["user_id"]

    # Get friends list
    friends = db_service.get_friends(user_id)
    friend_ids = [f.get("friend_id") for f in friends]

    # Include current user in the leaderboard
    all_user_ids = [user_id] + friend_ids

    # Get stats for all users
    entries = []
    for uid in all_user_ids:
        user = db_service.get_user(uid)
        if not user:
            continue

        total_regions = (
            user.get("countries_visited", 0)
            + user.get("us_states_visited", 0)
            + user.get("canadian_provinces_visited", 0)
        )

        entries.append(
            LeaderboardEntry(
                user_id=uid,
                display_name=user.get("display_name"),
                countries_visited=user.get("countries_visited", 0),
                us_states_visited=user.get("us_states_visited", 0),
                canadian_provinces_visited=user.get("canadian_provinces_visited", 0),
                total_regions=total_regions,
            )
        )

    # Sort by countries visited (primary), then total regions
    entries.sort(key=lambda x: (x.countries_visited, x.total_regions), reverse=True)

    # Assign ranks
    for i, entry in enumerate(entries):
        entry.rank = i + 1

    # Find user's rank
    user_rank = next((e.rank for e in entries if e.user_id == user_id), None)

    return LeaderboardResponse(
        entries=entries,
        user_rank=user_rank,
        total_friends=len(friend_ids),
    )


@router.get("/extended", response_model=ExtendedStatsResponse)
async def get_extended_stats(current_user: dict = Depends(get_current_user)):
    """
    Get comprehensive extended statistics including all features.

    Combines basic stats, continent breakdown, time zones, and badges.
    """
    user_id = current_user["user_id"]
    places = db_service.get_user_visited_places(user_id)
    active_places = [p for p in places if not p.get("is_deleted", False)]

    # Count by visit type
    countries_visited, countries_transit = _count_by_visit_type(
        active_places, "country"
    )
    us_visited, us_transit = _count_by_visit_type(active_places, "us_state")
    ca_visited, ca_transit = _count_by_visit_type(active_places, "canadian_province")

    # Get continent stats
    continent_response = await get_continent_stats(current_user)

    # Get timezone stats
    timezone_response = await get_timezone_stats(current_user)

    # Get badge counts
    badges_response = await get_badges(current_user)

    # Timeline info
    visited_dates = [
        p.get("visited_date")
        for p in active_places
        if p.get("visited_date") and p.get("status", "visited") == "visited"
    ]
    sorted_dates = sorted([d for d in visited_dates if d])

    first_visit = sorted_dates[0] if sorted_dates else None
    latest_visit = sorted_dates[-1] if sorted_dates else None

    # Countries this year
    current_year = datetime.now().year
    countries_this_year = sum(
        1
        for p in active_places
        if p.get("region_type") == "country"
        and p.get("status", "visited") == "visited"
        and p.get("visited_date")
        and str(p.get("visited_date", "")).startswith(str(current_year))
    )

    return ExtendedStatsResponse(
        countries_visited=countries_visited,
        countries_transit=countries_transit,
        us_states_visited=us_visited,
        us_states_transit=us_transit,
        canadian_provinces_visited=ca_visited,
        canadian_provinces_transit=ca_transit,
        continents=continent_response,
        time_zones=timezone_response,
        badges_earned=badges_response.total_earned,
        badges_total=badges_response.total_badges,
        first_visit_date=first_visit,
        latest_visit_date=latest_visit,
        countries_this_year=countries_this_year,
    )
