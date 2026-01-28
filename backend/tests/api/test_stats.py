"""Tests for statistics API routes."""

from unittest.mock import patch

import pytest
from fastapi.testclient import TestClient

from src.api.main import app
from src.api.routes.auth import get_current_user


@pytest.fixture
def mock_user():
    """Mock authenticated user."""
    return {
        "user_id": "test-user-123",
        "email": "test@example.com",
        "display_name": "Test User",
        "countries_visited": 15,
        "us_states_visited": 10,
        "canadian_provinces_visited": 3,
    }


@pytest.fixture
def mock_db_service():
    """Mock DynamoDB service."""
    with patch("src.api.routes.stats.db_service") as mock:
        yield mock


@pytest.fixture
def client(mock_user):
    """Create test client with mocked auth."""
    app.dependency_overrides[get_current_user] = lambda: mock_user
    client = TestClient(app)
    yield client
    app.dependency_overrides.clear()


class TestContinentStats:
    """Tests for GET /stats/continents endpoint."""

    def test_get_continent_stats_empty(self, client, mock_db_service):
        """Test continent stats when user has no visited places."""
        mock_db_service.get_user_visited_places.return_value = []

        response = client.get(
            "/stats/continents",
            headers={"Authorization": "Bearer test-token"},
        )

        assert response.status_code == 200
        data = response.json()
        assert data["total_continents_visited"] == 0
        assert len(data["continents"]) == 6  # Excluding Antarctica

    def test_get_continent_stats_with_data(self, client, mock_db_service):
        """Test continent stats with visited places."""
        mock_db_service.get_user_visited_places.return_value = [
            {"region_code": "FR", "status": "visited", "is_deleted": False},  # Europe
            {"region_code": "DE", "status": "visited", "is_deleted": False},  # Europe
            {"region_code": "JP", "status": "visited", "is_deleted": False},  # Asia
            {"region_code": "US", "status": "visited", "is_deleted": False},  # N. America
            {"region_code": "BR", "status": "visited", "is_deleted": False},  # S. America
        ]

        response = client.get(
            "/stats/continents",
            headers={"Authorization": "Bearer test-token"},
        )

        assert response.status_code == 200
        data = response.json()
        assert data["total_continents_visited"] == 4

        # Check Europe stats
        europe = next(c for c in data["continents"] if c["continent"] == "Europe")
        assert europe["countries_visited"] == 2
        assert europe["countries_total"] == 44
        assert "FR" in europe["visited_countries"]
        assert "DE" in europe["visited_countries"]

    def test_get_continent_stats_excludes_deleted(self, client, mock_db_service):
        """Test that deleted places are excluded."""
        mock_db_service.get_user_visited_places.return_value = [
            {"region_code": "FR", "status": "visited", "is_deleted": False},
            {"region_code": "DE", "status": "visited", "is_deleted": True},  # Deleted
        ]

        response = client.get(
            "/stats/continents",
            headers={"Authorization": "Bearer test-token"},
        )

        assert response.status_code == 200
        data = response.json()
        europe = next(c for c in data["continents"] if c["continent"] == "Europe")
        assert europe["countries_visited"] == 1
        assert "FR" in europe["visited_countries"]
        assert "DE" not in europe["visited_countries"]

    def test_get_continent_stats_excludes_bucket_list(self, client, mock_db_service):
        """Test that bucket list places are excluded."""
        mock_db_service.get_user_visited_places.return_value = [
            {"region_code": "FR", "status": "visited", "is_deleted": False},
            {"region_code": "IT", "status": "bucket_list", "is_deleted": False},
        ]

        response = client.get(
            "/stats/continents",
            headers={"Authorization": "Bearer test-token"},
        )

        assert response.status_code == 200
        data = response.json()
        europe = next(c for c in data["continents"] if c["continent"] == "Europe")
        assert europe["countries_visited"] == 1


class TestTimeZoneStats:
    """Tests for GET /stats/timezones endpoint."""

    def test_get_timezone_stats_empty(self, client, mock_db_service):
        """Test timezone stats when user has no visited places."""
        mock_db_service.get_user_visited_places.return_value = []

        response = client.get(
            "/stats/timezones",
            headers={"Authorization": "Bearer test-token"},
        )

        assert response.status_code == 200
        data = response.json()
        assert data["zones_visited"] == 0
        assert data["total_zones"] == 24
        assert data["percentage"] == 0.0
        assert data["farthest_east"] is None
        assert data["farthest_west"] is None

    def test_get_timezone_stats_with_data(self, client, mock_db_service):
        """Test timezone stats with visited places."""
        mock_db_service.get_user_visited_places.return_value = [
            {"region_code": "GB", "status": "visited", "is_deleted": False},  # UTC+0
            {"region_code": "FR", "status": "visited", "is_deleted": False},  # UTC+1
            {"region_code": "JP", "status": "visited", "is_deleted": False},  # UTC+9
            {"region_code": "US", "status": "visited", "is_deleted": False},  # UTC-5 to -10
        ]

        response = client.get(
            "/stats/timezones",
            headers={"Authorization": "Bearer test-token"},
        )

        assert response.status_code == 200
        data = response.json()
        assert data["zones_visited"] >= 4  # At least GB, FR, JP, US zones
        assert data["farthest_east"] == 9  # Japan
        assert data["farthest_west"] == -10  # US (Hawaii)

    def test_get_timezone_stats_multi_zone_countries(self, client, mock_db_service):
        """Test that multi-zone countries count all their zones."""
        mock_db_service.get_user_visited_places.return_value = [
            {"region_code": "RU", "status": "visited", "is_deleted": False},  # UTC+2 to +12
        ]

        response = client.get(
            "/stats/timezones",
            headers={"Authorization": "Bearer test-token"},
        )

        assert response.status_code == 200
        data = response.json()
        # Russia spans 11 time zones
        assert data["zones_visited"] >= 10


class TestBadges:
    """Tests for GET /stats/badges endpoint."""

    def test_get_badges_empty(self, client, mock_db_service):
        """Test badges when user has no visited places."""
        mock_db_service.get_user_visited_places.return_value = []

        response = client.get(
            "/stats/badges",
            headers={"Authorization": "Bearer test-token"},
        )

        assert response.status_code == 200
        data = response.json()
        assert data["total_earned"] == 0
        assert data["total_badges"] > 0
        assert len(data["earned"]) == 0
        assert len(data["in_progress"]) > 0

    def test_get_badges_first_steps(self, client, mock_db_service):
        """Test earning the First Steps badge (1 country)."""
        mock_db_service.get_user_visited_places.return_value = [
            {
                "region_code": "FR",
                "region_type": "country",
                "status": "visited",
                "is_deleted": False,
            },
        ]

        response = client.get(
            "/stats/badges",
            headers={"Authorization": "Bearer test-token"},
        )

        assert response.status_code == 200
        data = response.json()
        assert data["total_earned"] >= 1

        # Check First Steps badge is earned
        earned_ids = [b["badge"]["id"] for b in data["earned"]]
        assert "first_steps" in earned_ids

    def test_get_badges_explorer(self, client, mock_db_service):
        """Test earning the Explorer badge (10 countries)."""
        places = [
            {
                "region_code": code,
                "region_type": "country",
                "status": "visited",
                "is_deleted": False,
            }
            for code in ["FR", "DE", "IT", "ES", "PT", "NL", "BE", "AT", "CH", "GB"]
        ]
        mock_db_service.get_user_visited_places.return_value = places

        response = client.get(
            "/stats/badges",
            headers={"Authorization": "Bearer test-token"},
        )

        assert response.status_code == 200
        data = response.json()

        earned_ids = [b["badge"]["id"] for b in data["earned"]]
        assert "first_steps" in earned_ids
        assert "explorer_10" in earned_ids

    def test_get_badges_us_states(self, client, mock_db_service):
        """Test US state badges."""
        places = [
            {
                "region_code": code,
                "region_type": "us_state",
                "status": "visited",
                "is_deleted": False,
            }
            for code in ["CA", "NY", "TX", "FL", "WA", "OR", "NV", "AZ", "CO", "UT"]
        ]
        mock_db_service.get_user_visited_places.return_value = places

        response = client.get(
            "/stats/badges",
            headers={"Authorization": "Bearer test-token"},
        )

        assert response.status_code == 200
        data = response.json()

        earned_ids = [b["badge"]["id"] for b in data["earned"]]
        assert "us_starter" in earned_ids  # 10 US states

    def test_get_badges_progress_tracking(self, client, mock_db_service):
        """Test that badge progress is tracked correctly."""
        places = [
            {
                "region_code": code,
                "region_type": "country",
                "status": "visited",
                "is_deleted": False,
            }
            for code in ["FR", "DE", "IT", "ES", "PT"]  # 5 countries
        ]
        mock_db_service.get_user_visited_places.return_value = places

        response = client.get(
            "/stats/badges",
            headers={"Authorization": "Bearer test-token"},
        )

        assert response.status_code == 200
        data = response.json()

        # Find explorer_10 badge (in progress)
        explorer_badge = next(
            (b for b in data["in_progress"] if b["badge"]["id"] == "explorer_10"), None
        )
        assert explorer_badge is not None
        assert explorer_badge["progress"] == 5
        assert explorer_badge["progress_total"] == 10
        assert explorer_badge["progress_percentage"] == 50.0


class TestLeaderboard:
    """Tests for GET /stats/leaderboard endpoint."""

    def test_get_leaderboard_no_friends(self, client, mock_db_service):
        """Test leaderboard when user has no friends."""
        mock_db_service.get_friends.return_value = []
        mock_db_service.get_user.return_value = {
            "user_id": "test-user-123",
            "display_name": "Test User",
            "countries_visited": 10,
            "us_states_visited": 5,
            "canadian_provinces_visited": 2,
        }

        response = client.get(
            "/stats/leaderboard",
            headers={"Authorization": "Bearer test-token"},
        )

        assert response.status_code == 200
        data = response.json()
        assert data["total_friends"] == 0
        assert len(data["entries"]) == 1
        assert data["user_rank"] == 1

    def test_get_leaderboard_with_friends(self, client, mock_db_service):
        """Test leaderboard with friends."""
        mock_db_service.get_friends.return_value = [
            {"friend_id": "friend-1"},
            {"friend_id": "friend-2"},
        ]
        mock_db_service.get_user.side_effect = [
            # Current user
            {
                "user_id": "test-user-123",
                "display_name": "Test User",
                "countries_visited": 10,
                "us_states_visited": 5,
                "canadian_provinces_visited": 2,
            },
            # Friend 1 - more countries
            {
                "user_id": "friend-1",
                "display_name": "Friend One",
                "countries_visited": 20,
                "us_states_visited": 10,
                "canadian_provinces_visited": 5,
            },
            # Friend 2 - fewer countries
            {
                "user_id": "friend-2",
                "display_name": "Friend Two",
                "countries_visited": 5,
                "us_states_visited": 3,
                "canadian_provinces_visited": 1,
            },
        ]

        response = client.get(
            "/stats/leaderboard",
            headers={"Authorization": "Bearer test-token"},
        )

        assert response.status_code == 200
        data = response.json()
        assert data["total_friends"] == 2
        assert len(data["entries"]) == 3

        # Check ranking order
        assert data["entries"][0]["user_id"] == "friend-1"  # 20 countries
        assert data["entries"][0]["rank"] == 1
        assert data["entries"][1]["user_id"] == "test-user-123"  # 10 countries
        assert data["entries"][1]["rank"] == 2
        assert data["entries"][2]["user_id"] == "friend-2"  # 5 countries
        assert data["entries"][2]["rank"] == 3

        assert data["user_rank"] == 2


class TestExtendedStats:
    """Tests for GET /stats/extended endpoint."""

    def test_get_extended_stats(self, client, mock_db_service):
        """Test extended stats endpoint."""
        mock_db_service.get_user_visited_places.return_value = [
            {
                "region_code": "FR",
                "region_type": "country",
                "status": "visited",
                "visit_type": "visited",
                "visited_date": "2024-01-15",
                "is_deleted": False,
            },
            {
                "region_code": "DE",
                "region_type": "country",
                "status": "visited",
                "visit_type": "transit",  # Transit
                "is_deleted": False,
            },
            {
                "region_code": "CA",
                "region_type": "us_state",
                "status": "visited",
                "visit_type": "visited",
                "is_deleted": False,
            },
        ]
        mock_db_service.get_friends.return_value = []
        mock_db_service.get_user.return_value = {
            "user_id": "test-user-123",
            "countries_visited": 2,
        }

        response = client.get(
            "/stats/extended",
            headers={"Authorization": "Bearer test-token"},
        )

        assert response.status_code == 200
        data = response.json()
        assert data["countries_visited"] == 1  # Only full visits
        assert data["countries_transit"] == 1  # Transit only
        assert data["us_states_visited"] == 1
        assert data["continents"] is not None
        assert data["time_zones"] is not None


class TestVisitTypeStats:
    """Tests for visit type distinction in statistics."""

    def test_stats_distinguish_visit_types(self, client, mock_db_service):
        """Test that stats properly distinguish between visited and transit."""
        mock_db_service.get_user_visited_places.return_value = [
            {
                "region_code": "FR",
                "region_type": "country",
                "status": "visited",
                "visit_type": "visited",
                "is_deleted": False,
            },
            {
                "region_code": "DE",
                "region_type": "country",
                "status": "visited",
                "visit_type": "visited",
                "is_deleted": False,
            },
            {
                "region_code": "NL",
                "region_type": "country",
                "status": "visited",
                "visit_type": "transit",
                "is_deleted": False,
            },
            {
                "region_code": "BE",
                "region_type": "country",
                "status": "visited",
                "visit_type": "transit",
                "is_deleted": False,
            },
            {
                "region_code": "AT",
                "region_type": "country",
                "status": "visited",
                "visit_type": "transit",
                "is_deleted": False,
            },
        ]
        mock_db_service.get_friends.return_value = []
        mock_db_service.get_user.return_value = {"user_id": "test-user-123"}

        response = client.get(
            "/stats/extended",
            headers={"Authorization": "Bearer test-token"},
        )

        assert response.status_code == 200
        data = response.json()
        assert data["countries_visited"] == 2  # FR, DE
        assert data["countries_transit"] == 3  # NL, BE, AT
