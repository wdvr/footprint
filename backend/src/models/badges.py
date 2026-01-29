"""Badge and achievement data models."""

from datetime import datetime
from enum import Enum

from pydantic import BaseModel, Field


class BadgeCategory(str, Enum):
    """Badge category classification."""

    COUNTRIES = "countries"
    REGIONS = "regions"
    CONTINENTS = "continents"
    SPECIAL = "special"
    STATES = "states"


class Badge(BaseModel):
    """Badge definition model."""

    id: str = Field(..., description="Unique badge identifier")
    name: str = Field(..., description="Display name")
    description: str = Field(..., description="Badge description")
    category: BadgeCategory = Field(..., description="Badge category")
    icon: str = Field(..., description="SF Symbol name or emoji")
    requirement_type: str = Field(..., description="Type of requirement check")
    requirement_value: int = Field(..., description="Value to achieve")
    requirement_filter: dict | None = Field(
        None, description="Optional filter (e.g., continent name)"
    )


class UserBadge(BaseModel):
    """User's earned badge."""

    badge_id: str = Field(..., description="Badge identifier")
    unlocked_at: datetime = Field(..., description="When badge was earned")
    progress: int = Field(default=0, description="Current progress")
    progress_total: int = Field(..., description="Total needed")


class BadgeProgress(BaseModel):
    """Badge with user progress."""

    badge: Badge = Field(..., description="Badge definition")
    unlocked: bool = Field(default=False, description="Whether badge is earned")
    unlocked_at: datetime | None = Field(None, description="When badge was earned")
    progress: int = Field(default=0, description="Current progress")
    progress_total: int = Field(..., description="Total needed")
    progress_percentage: float = Field(default=0.0, description="Progress percentage")


class BadgesResponse(BaseModel):
    """Response model for user badges."""

    earned: list[BadgeProgress] = Field(..., description="Earned badges")
    in_progress: list[BadgeProgress] = Field(..., description="Badges in progress")
    total_earned: int = Field(default=0, description="Total badges earned")
    total_badges: int = Field(..., description="Total available badges")


# Badge definitions
BADGES: list[Badge] = [
    # Country milestones
    Badge(
        id="first_steps",
        name="First Steps",
        description="Visit your first country",
        category=BadgeCategory.COUNTRIES,
        icon="figure.walk",
        requirement_type="countries_visited",
        requirement_value=1,
    ),
    Badge(
        id="explorer_10",
        name="Explorer",
        description="Visit 10 countries",
        category=BadgeCategory.COUNTRIES,
        icon="globe.americas",
        requirement_type="countries_visited",
        requirement_value=10,
    ),
    Badge(
        id="globetrotter_25",
        name="Globetrotter",
        description="Visit 25 countries",
        category=BadgeCategory.COUNTRIES,
        icon="globe",
        requirement_type="countries_visited",
        requirement_value=25,
    ),
    Badge(
        id="world_traveler_50",
        name="World Traveler",
        description="Visit 50 countries",
        category=BadgeCategory.COUNTRIES,
        icon="airplane",
        requirement_type="countries_visited",
        requirement_value=50,
    ),
    Badge(
        id="elite_traveler_100",
        name="Elite Traveler",
        description="Visit 100 countries",
        category=BadgeCategory.COUNTRIES,
        icon="crown",
        requirement_type="countries_visited",
        requirement_value=100,
    ),
    Badge(
        id="world_champion_150",
        name="World Champion",
        description="Visit 150 countries",
        category=BadgeCategory.COUNTRIES,
        icon="trophy",
        requirement_type="countries_visited",
        requirement_value=150,
    ),
    # Continent achievements
    Badge(
        id="europe_explorer",
        name="Europe Explorer",
        description="Visit 10 European countries",
        category=BadgeCategory.CONTINENTS,
        icon="building.columns",
        requirement_type="continent_countries",
        requirement_value=10,
        requirement_filter={"continent": "Europe"},
    ),
    Badge(
        id="asia_adventurer",
        name="Asia Adventurer",
        description="Visit 10 Asian countries",
        category=BadgeCategory.CONTINENTS,
        icon="building.2",
        requirement_type="continent_countries",
        requirement_value=10,
        requirement_filter={"continent": "Asia"},
    ),
    Badge(
        id="africa_safari",
        name="African Safari",
        description="Visit 10 African countries",
        category=BadgeCategory.CONTINENTS,
        icon="leaf",
        requirement_type="continent_countries",
        requirement_value=10,
        requirement_filter={"continent": "Africa"},
    ),
    Badge(
        id="americas_explorer",
        name="Americas Explorer",
        description="Visit 10 countries in the Americas",
        category=BadgeCategory.CONTINENTS,
        icon="mountain.2",
        requirement_type="americas_countries",
        requirement_value=10,
    ),
    Badge(
        id="oceania_hopper",
        name="Island Hopper",
        description="Visit 5 Oceania countries",
        category=BadgeCategory.CONTINENTS,
        icon="water.waves",
        requirement_type="continent_countries",
        requirement_value=5,
        requirement_filter={"continent": "Oceania"},
    ),
    Badge(
        id="all_continents",
        name="Continental Master",
        description="Visit at least one country on every continent",
        category=BadgeCategory.CONTINENTS,
        icon="globe.europe.africa",
        requirement_type="continents_visited",
        requirement_value=6,  # Excluding Antarctica
    ),
    # US State achievements
    Badge(
        id="us_starter",
        name="US Starter",
        description="Visit 10 US states",
        category=BadgeCategory.STATES,
        icon="flag",
        requirement_type="us_states_visited",
        requirement_value=10,
    ),
    Badge(
        id="us_half",
        name="Half the States",
        description="Visit 25 US states",
        category=BadgeCategory.STATES,
        icon="star",
        requirement_type="us_states_visited",
        requirement_value=25,
    ),
    Badge(
        id="us_complete",
        name="All 50 States",
        description="Visit all 50 US states",
        category=BadgeCategory.STATES,
        icon="star.fill",
        requirement_type="us_states_visited",
        requirement_value=50,
    ),
    # Canadian achievements
    Badge(
        id="canada_explorer",
        name="Canada Explorer",
        description="Visit 5 Canadian provinces",
        category=BadgeCategory.STATES,
        icon="leaf.circle",
        requirement_type="canadian_provinces_visited",
        requirement_value=5,
    ),
    Badge(
        id="canada_complete",
        name="True North Strong",
        description="Visit all Canadian provinces and territories",
        category=BadgeCategory.STATES,
        icon="maple.leaf",
        requirement_type="canadian_provinces_visited",
        requirement_value=13,
    ),
    # Special achievements
    Badge(
        id="time_zone_master",
        name="Time Zone Master",
        description="Visit countries in 12+ time zones",
        category=BadgeCategory.SPECIAL,
        icon="clock",
        requirement_type="time_zones_visited",
        requirement_value=12,
    ),
    Badge(
        id="all_time_zones",
        name="Around the Clock",
        description="Visit countries in all 24 time zones",
        category=BadgeCategory.SPECIAL,
        icon="clock.badge.checkmark",
        requirement_type="time_zones_visited",
        requirement_value=24,
    ),
    Badge(
        id="bucket_list_5",
        name="Dream Chaser",
        description="Check off 5 places from your bucket list",
        category=BadgeCategory.SPECIAL,
        icon="checklist",
        requirement_type="bucket_list_completed",
        requirement_value=5,
    ),
    Badge(
        id="bucket_list_25",
        name="Dream Achiever",
        description="Check off 25 places from your bucket list",
        category=BadgeCategory.SPECIAL,
        icon="checklist.checked",
        requirement_type="bucket_list_completed",
        requirement_value=25,
    ),
]

# Badge lookup by ID
BADGES_BY_ID: dict[str, Badge] = {badge.id: badge for badge in BADGES}


def get_badge(badge_id: str) -> Badge | None:
    """Get a badge by ID."""
    return BADGES_BY_ID.get(badge_id)


def get_all_badges() -> list[Badge]:
    """Get all badge definitions."""
    return BADGES


def get_badges_by_category(category: BadgeCategory) -> list[Badge]:
    """Get badges by category."""
    return [b for b in BADGES if b.category == category]
