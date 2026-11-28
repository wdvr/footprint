"""Badge and achievement data models.

Medals v2 (spec §4.1): definitions come from the generated catalog
(`src/data/medals.json`, built by `scripts/build_medals_catalog.py`), shared
byte-for-byte with the iOS app. `BadgesResponse` keeps its v1 shape for
friends/leaderboard clients: one `BadgeProgress` per medal, `progress` is the
current metric and `progress_total` the next tier's threshold.
"""

from datetime import datetime
from enum import Enum

from pydantic import BaseModel, Field

from src.services.medals import load_catalog


class BadgeCategory(str, Enum):
    """Badge category classification (v1 values; v2 families map onto these)."""

    COUNTRIES = "countries"
    REGIONS = "regions"
    CONTINENTS = "continents"
    SPECIAL = "special"
    STATES = "states"


class BadgeTier(BaseModel):
    """One tier of a medal."""

    level: str = Field(..., description="bronze, silver, gold or platinum")
    threshold: float = Field(..., description="Metric value that earns this tier")


class Badge(BaseModel):
    """Badge (medal) definition model."""

    id: str = Field(..., description="Unique badge identifier")
    name: str = Field(..., description="Display name")
    description: str = Field(..., description="Badge description")
    category: BadgeCategory = Field(..., description="Badge category")
    icon: str = Field(..., description="SF Symbol name or emoji")
    requirement_type: str = Field(..., description="Metric that is counted")
    requirement_value: int = Field(..., description="Value that earns the first tier")
    requirement_filter: dict | None = Field(
        None, description="Optional filter (e.g., continent name)"
    )
    family: str | None = Field(None, description="Medals v2 family")
    tiers: list[BadgeTier] | None = Field(None, description="Medals v2 tiers, ordered")


class BadgeTierProgress(BaseModel):
    """A tier the user has earned."""

    level: str
    threshold: float
    unlocked_at: datetime | None = None
    trigger: str | None = Field(None, description="Place that crossed the threshold")


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
    unlocked_at: datetime | None = Field(
        None, description="When the first tier was earned"
    )
    progress: int = Field(default=0, description="Current progress")
    progress_total: int = Field(..., description="Next tier's threshold")
    progress_percentage: float = Field(default=0.0, description="Progress percentage")
    tier: str | None = Field(None, description="Highest tier earned")
    tiers_earned: list[BadgeTierProgress] = Field(
        default_factory=list, description="Earned tiers, lowest first"
    )


class BadgesResponse(BaseModel):
    """Response model for user badges."""

    earned: list[BadgeProgress] = Field(..., description="Earned badges")
    in_progress: list[BadgeProgress] = Field(..., description="Badges in progress")
    total_earned: int = Field(default=0, description="Total badges earned")
    total_badges: int = Field(..., description="Total available badges")


def badge_from_medal(medal: dict) -> Badge:
    """Map a catalog medal definition onto the v1 `Badge` DTO."""
    tiers = [BadgeTier(**t) for t in medal["tiers"]]
    return Badge(
        id=medal["id"],
        name=medal["name"],
        description=medal["description"],
        category=BadgeCategory(medal["category"]),
        icon=medal["icon"],
        requirement_type=medal["metric"],
        requirement_value=int(tiers[0].threshold),
        requirement_filter=medal.get("filter"),
        family=medal["family"],
        tiers=tiers,
    )


# Medals the backend can evaluate from synced places
BADGES: list[Badge] = [
    badge_from_medal(m) for m in load_catalog()["medals"] if "backend" in m["platforms"]
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
