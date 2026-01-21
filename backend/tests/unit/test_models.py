"""Test cases for Pydantic models."""

from datetime import UTC, datetime

from src.models.geographic import CanadianProvince, ContinentCode, Country, USState
from src.models.sync import ConflictResolutionStrategy, SyncOperation, SyncOperationType
from src.models.user import AuthProvider, User, UserCreate, UserStats, UserUpdate
from src.models.visited_place import RegionType, VisitedPlace, VisitedPlaceCreate


class TestUserModels:
    """Test user-related models."""

    def test_user_creation(self):
        """Test basic user creation."""
        user = User(
            user_id="test-user-123",
            auth_provider=AuthProvider.APPLE,
            auth_provider_id="apple-user-456",
            email="test@example.com",
            display_name="Test User",
        )

        assert user.user_id == "test-user-123"
        assert user.auth_provider == AuthProvider.APPLE
        assert user.email == "test@example.com"
        assert user.countries_visited == 0
        assert user.sync_version == 1

    def test_user_create_model(self):
        """Test UserCreate model validation."""
        user_create = UserCreate(
            auth_provider=AuthProvider.EMAIL,
            auth_provider_id="email-user-789",
            email="create@example.com",
        )

        assert user_create.auth_provider == AuthProvider.EMAIL
        assert user_create.email == "create@example.com"

    def test_user_update_model(self):
        """Test UserUpdate model validation."""
        user_update = UserUpdate(
            display_name="Updated Name", privacy_settings={"share_stats": False}
        )

        assert user_update.display_name == "Updated Name"
        assert user_update.privacy_settings["share_stats"] is False

    def test_user_stats_calculation(self):
        """Test user stats model."""
        stats = UserStats(
            countries_visited=50,
            countries_percentage=25.64,
            us_states_visited=25,
            us_states_percentage=49.02,
            canadian_provinces_visited=5,
            canadian_provinces_percentage=38.46,
            total_regions_visited=80,
            total_regions_percentage=30.89,
        )

        assert stats.countries_visited == 50
        assert stats.countries_percentage == 25.64
        assert stats.total_regions_visited == 80


class TestVisitedPlaceModels:
    """Test visited place models."""

    def test_visited_place_creation(self):
        """Test basic visited place creation."""
        place = VisitedPlace(
            user_id="test-user-123",
            region_type=RegionType.COUNTRY,
            region_code="US",
            region_name="United States",
        )

        assert place.user_id == "test-user-123"
        assert place.region_type == RegionType.COUNTRY
        assert place.region_code == "US"
        assert place.sync_version == 1
        assert place.is_deleted is False

    def test_visited_place_create_model(self):
        """Test VisitedPlaceCreate model."""
        place_create = VisitedPlaceCreate(
            region_type=RegionType.US_STATE,
            region_code="CA",
            region_name="California",
            notes="Amazing trip to San Francisco!",
        )

        assert place_create.region_type == RegionType.US_STATE
        assert place_create.region_code == "CA"
        assert place_create.notes == "Amazing trip to San Francisco!"

    def test_visited_place_with_date(self):
        """Test visited place with visit date."""
        visit_date = datetime(2024, 6, 15, 10, 30, 0)
        place = VisitedPlace(
            user_id="test-user-123",
            region_type=RegionType.CANADIAN_PROVINCE,
            region_code="BC",
            region_name="British Columbia",
            visited_date=visit_date,
        )

        assert place.visited_date == visit_date
        assert place.region_type == RegionType.CANADIAN_PROVINCE


class TestGeographicModels:
    """Test geographic models."""

    def test_country_creation(self):
        """Test country model creation."""
        country = Country(
            code="US",
            name="United States of America",
            display_name="United States",
            iso_alpha_2="US",
            iso_alpha_3="USA",
            iso_numeric="840",
            continent_code=ContinentCode.NA,
            capital="Washington, D.C.",
            bbox_north=71.5388,
            bbox_south=18.7763,
            bbox_east=-66.885444,
            bbox_west=170.5957,
            center_lat=39.8283,
            center_lon=-98.5795,
        )

        assert country.iso_alpha_2 == "US"
        assert country.iso_alpha_3 == "USA"
        assert country.continent_code == ContinentCode.NA
        assert country.capital == "Washington, D.C."

    def test_us_state_creation(self):
        """Test US state model creation."""
        state = USState(
            code="CA",
            name="California",
            display_name="California",
            fips_code="06",
            abbreviation="CA",
            capital="Sacramento",
            bbox_north=42.009518,
            bbox_south=32.534156,
            bbox_east=-114.131211,
            bbox_west=-124.409591,
            center_lat=36.116203,
            center_lon=-119.681564,
        )

        assert state.abbreviation == "CA"
        assert state.fips_code == "06"
        assert state.capital == "Sacramento"

    def test_canadian_province_creation(self):
        """Test Canadian province model creation."""
        province = CanadianProvince(
            code="BC",
            name="British Columbia",
            display_name="British Columbia",
            abbreviation="BC",
            province_type="province",
            capital="Victoria",
            bbox_north=60.0,
            bbox_south=48.2,
            bbox_east=-114.0,
            bbox_west=-139.0,
            center_lat=54.0,
            center_lon=-125.0,
        )

        assert province.abbreviation == "BC"
        assert province.province_type == "province"
        assert province.capital == "Victoria"


class TestSyncModels:
    """Test sync and conflict resolution models."""

    def test_sync_operation_creation(self):
        """Test sync operation model."""
        operation = SyncOperation(
            operation_id="op-123",
            user_id="user-456",
            operation_type=SyncOperationType.CREATE,
            entity_type="visited_place",
            entity_id="place-789",
            entity_data={"region_code": "FR", "region_name": "France"},
            client_version=1,
            client_timestamp=datetime.now(UTC),
        )

        assert operation.operation_id == "op-123"
        assert operation.operation_type == SyncOperationType.CREATE
        assert operation.entity_data["region_code"] == "FR"
        assert operation.has_conflict is False
        assert operation.is_processed is False

    def test_sync_operation_with_conflict(self):
        """Test sync operation with conflict."""
        operation = SyncOperation(
            operation_id="op-conflict-123",
            user_id="user-456",
            operation_type=SyncOperationType.UPDATE,
            entity_type="visited_place",
            entity_id="place-789",
            entity_data={"notes": "Updated notes from client"},
            client_version=2,
            server_version=3,
            client_timestamp=datetime.now(UTC),
            has_conflict=True,
            conflict_details={"field": "notes", "reason": "version_mismatch"},
            resolution_strategy=ConflictResolutionStrategy.CLIENT_WINS,
        )

        assert operation.has_conflict is True
        assert operation.resolution_strategy == ConflictResolutionStrategy.CLIENT_WINS
        assert operation.conflict_details["field"] == "notes"
