"""Tests for badge models and definitions."""


from src.models.badges import (
    BADGES,
    BADGES_BY_ID,
    Badge,
    BadgeCategory,
    BadgeProgress,
    BadgesResponse,
    get_all_badges,
    get_badge,
    get_badges_by_category,
)


class TestBadgeDefinitions:
    """Tests for badge definitions."""

    def test_all_badges_have_required_fields(self):
        """Test that all badge definitions have required fields."""
        for badge in BADGES:
            assert badge.id, f"Badge missing id: {badge}"
            assert badge.name, f"Badge missing name: {badge.id}"
            assert badge.description, f"Badge missing description: {badge.id}"
            assert badge.category, f"Badge missing category: {badge.id}"
            assert badge.icon, f"Badge missing icon: {badge.id}"
            assert badge.requirement_type, f"Badge missing requirement_type: {badge.id}"
            assert badge.requirement_value > 0, f"Badge has invalid requirement_value: {badge.id}"

    def test_badge_ids_are_unique(self):
        """Test that all badge IDs are unique."""
        ids = [badge.id for badge in BADGES]
        assert len(ids) == len(set(ids)), "Duplicate badge IDs found"

    def test_badges_by_id_mapping(self):
        """Test that BADGES_BY_ID mapping is correct."""
        assert len(BADGES_BY_ID) == len(BADGES)
        for badge in BADGES:
            assert badge.id in BADGES_BY_ID
            assert BADGES_BY_ID[badge.id] == badge


class TestBadgeHelpers:
    """Tests for badge helper functions."""

    def test_get_badge_existing(self):
        """Test getting an existing badge."""
        badge = get_badge("first_steps")
        assert badge is not None
        assert badge.id == "first_steps"
        assert badge.name == "First Steps"

    def test_get_badge_non_existing(self):
        """Test getting a non-existing badge returns None."""
        badge = get_badge("non_existing_badge")
        assert badge is None

    def test_get_all_badges(self):
        """Test getting all badges."""
        badges = get_all_badges()
        assert len(badges) == len(BADGES)
        assert badges == BADGES

    def test_get_badges_by_category_countries(self):
        """Test filtering badges by countries category."""
        badges = get_badges_by_category(BadgeCategory.COUNTRIES)
        assert len(badges) > 0
        for badge in badges:
            assert badge.category == BadgeCategory.COUNTRIES

    def test_get_badges_by_category_continents(self):
        """Test filtering badges by continents category."""
        badges = get_badges_by_category(BadgeCategory.CONTINENTS)
        assert len(badges) > 0
        for badge in badges:
            assert badge.category == BadgeCategory.CONTINENTS

    def test_get_badges_by_category_states(self):
        """Test filtering badges by states category."""
        badges = get_badges_by_category(BadgeCategory.STATES)
        assert len(badges) > 0
        for badge in badges:
            assert badge.category == BadgeCategory.STATES

    def test_get_badges_by_category_special(self):
        """Test filtering badges by special category."""
        badges = get_badges_by_category(BadgeCategory.SPECIAL)
        assert len(badges) > 0
        for badge in badges:
            assert badge.category == BadgeCategory.SPECIAL


class TestBadgeModels:
    """Tests for badge Pydantic models."""

    def test_badge_model_creation(self):
        """Test creating a Badge model."""
        badge = Badge(
            id="test_badge",
            name="Test Badge",
            description="A test badge",
            category=BadgeCategory.COUNTRIES,
            icon="star",
            requirement_type="countries_visited",
            requirement_value=5,
        )
        assert badge.id == "test_badge"
        assert badge.requirement_filter is None

    def test_badge_model_with_filter(self):
        """Test creating a Badge model with requirement filter."""
        badge = Badge(
            id="test_badge",
            name="Test Badge",
            description="A test badge",
            category=BadgeCategory.CONTINENTS,
            icon="star",
            requirement_type="continent_countries",
            requirement_value=10,
            requirement_filter={"continent": "Europe"},
        )
        assert badge.requirement_filter == {"continent": "Europe"}

    def test_badge_progress_model(self):
        """Test creating a BadgeProgress model."""
        badge = get_badge("first_steps")
        progress = BadgeProgress(
            badge=badge,
            unlocked=True,
            progress=1,
            progress_total=1,
            progress_percentage=100.0,
        )
        assert progress.unlocked is True
        assert progress.progress == 1
        assert progress.progress_percentage == 100.0

    def test_badges_response_model(self):
        """Test creating a BadgesResponse model."""
        badge = get_badge("first_steps")
        earned_progress = BadgeProgress(
            badge=badge,
            unlocked=True,
            progress=1,
            progress_total=1,
            progress_percentage=100.0,
        )

        badge2 = get_badge("explorer_10")
        in_progress = BadgeProgress(
            badge=badge2,
            unlocked=False,
            progress=5,
            progress_total=10,
            progress_percentage=50.0,
        )

        response = BadgesResponse(
            earned=[earned_progress],
            in_progress=[in_progress],
            total_earned=1,
            total_badges=len(BADGES),
        )
        assert response.total_earned == 1
        assert len(response.earned) == 1
        assert len(response.in_progress) == 1


class TestSpecificBadges:
    """Tests for specific badge definitions."""

    def test_first_steps_badge(self):
        """Test First Steps badge definition."""
        badge = get_badge("first_steps")
        assert badge.requirement_type == "countries_visited"
        assert badge.requirement_value == 1

    def test_explorer_badge(self):
        """Test Explorer badge definition."""
        badge = get_badge("explorer_10")
        assert badge.requirement_type == "countries_visited"
        assert badge.requirement_value == 10

    def test_globetrotter_badge(self):
        """Test Globetrotter badge definition."""
        badge = get_badge("globetrotter_25")
        assert badge.requirement_type == "countries_visited"
        assert badge.requirement_value == 25

    def test_europe_explorer_badge(self):
        """Test Europe Explorer badge definition."""
        badge = get_badge("europe_explorer")
        assert badge.requirement_type == "continent_countries"
        assert badge.requirement_value == 10
        assert badge.requirement_filter == {"continent": "Europe"}

    def test_us_complete_badge(self):
        """Test All 50 States badge definition."""
        badge = get_badge("us_complete")
        assert badge.requirement_type == "us_states_visited"
        assert badge.requirement_value == 50

    def test_time_zone_master_badge(self):
        """Test Time Zone Master badge definition."""
        badge = get_badge("time_zone_master")
        assert badge.requirement_type == "time_zones_visited"
        assert badge.requirement_value == 12

    def test_all_continents_badge(self):
        """Test Continental Master badge definition."""
        badge = get_badge("all_continents")
        assert badge.requirement_type == "continents_visited"
        assert badge.requirement_value == 6  # Excluding Antarctica
