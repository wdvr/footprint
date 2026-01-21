"""Tests for DynamoDB service."""

import os

import boto3
import pytest
from moto import mock_aws


@pytest.fixture
def aws_credentials():
    """Mocked AWS credentials for moto."""
    os.environ["AWS_ACCESS_KEY_ID"] = "testing"
    os.environ["AWS_SECRET_ACCESS_KEY"] = "testing"
    os.environ["AWS_SECURITY_TOKEN"] = "testing"
    os.environ["AWS_SESSION_TOKEN"] = "testing"
    os.environ["AWS_DEFAULT_REGION"] = "us-east-1"


@pytest.fixture
def dynamodb_table(aws_credentials):
    """Create mocked DynamoDB table."""
    with mock_aws():
        dynamodb = boto3.resource("dynamodb", region_name="us-east-1")
        table = dynamodb.create_table(
            TableName="skratch-table-dev",
            KeySchema=[
                {"AttributeName": "pk", "KeyType": "HASH"},
                {"AttributeName": "sk", "KeyType": "RANGE"},
            ],
            AttributeDefinitions=[
                {"AttributeName": "pk", "AttributeType": "S"},
                {"AttributeName": "sk", "AttributeType": "S"},
                {"AttributeName": "gsi1pk", "AttributeType": "S"},
                {"AttributeName": "gsi1sk", "AttributeType": "S"},
            ],
            GlobalSecondaryIndexes=[
                {
                    "IndexName": "gsi1",
                    "KeySchema": [
                        {"AttributeName": "gsi1pk", "KeyType": "HASH"},
                        {"AttributeName": "gsi1sk", "KeyType": "RANGE"},
                    ],
                    "Projection": {"ProjectionType": "ALL"},
                    "ProvisionedThroughput": {
                        "ReadCapacityUnits": 5,
                        "WriteCapacityUnits": 5,
                    },
                }
            ],
            ProvisionedThroughput={
                "ReadCapacityUnits": 5,
                "WriteCapacityUnits": 5,
            },
        )
        table.wait_until_exists()
        yield table


@pytest.fixture
def db_service(dynamodb_table):
    """Create DynamoDB service with mocked table."""
    with mock_aws():
        # Import after mocking so it uses the mocked table
        # Need to reload the module to pick up the mocked table
        import importlib

        import src.services.dynamodb as db_module
        importlib.reload(db_module)
        yield db_module.DynamoDBService()


class TestUserOperations:
    """Tests for user operations."""

    def test_create_user(self, db_service):
        """Test creating a new user."""
        user_data = {
            "user_id": "test-user-123",
            "auth_provider": "apple",
            "auth_provider_id": "apple-123",
            "email": "test@example.com",
            "countries_visited": 0,
            "us_states_visited": 0,
            "canadian_provinces_visited": 0,
        }

        result = db_service.create_user(user_data)

        assert result["user_id"] == "test-user-123"
        assert result["pk"] == "USER#test-user-123"
        assert result["sk"] == "PROFILE"
        assert result["gsi1pk"] == "AUTH#apple"
        assert result["gsi1sk"] == "apple-123"
        assert "created_at" in result
        assert "updated_at" in result

    def test_get_user(self, db_service):
        """Test getting user by ID."""
        user_data = {
            "user_id": "test-user-456",
            "auth_provider": "apple",
            "auth_provider_id": "apple-456",
            "email": "test2@example.com",
        }
        db_service.create_user(user_data)

        result = db_service.get_user("test-user-456")

        assert result is not None
        assert result["user_id"] == "test-user-456"
        assert result["email"] == "test2@example.com"

    def test_get_user_not_found(self, db_service):
        """Test getting non-existent user returns None."""
        result = db_service.get_user("non-existent-user")
        assert result is None

    def test_get_user_by_auth(self, db_service):
        """Test getting user by auth provider."""
        user_data = {
            "user_id": "test-user-789",
            "auth_provider": "apple",
            "auth_provider_id": "apple-789",
            "email": "auth@example.com",
        }
        db_service.create_user(user_data)

        result = db_service.get_user_by_auth("apple", "apple-789")

        assert result is not None
        assert result["user_id"] == "test-user-789"

    def test_get_user_by_auth_not_found(self, db_service):
        """Test getting user by non-existent auth returns None."""
        result = db_service.get_user_by_auth("apple", "non-existent")
        assert result is None

    def test_update_user(self, db_service):
        """Test updating user data."""
        user_data = {
            "user_id": "update-user",
            "auth_provider": "apple",
            "auth_provider_id": "apple-update",
            "email": "update@example.com",
            "display_name": None,
        }
        db_service.create_user(user_data)

        result = db_service.update_user("update-user", {
            "display_name": "John Doe",
            "countries_visited": 5,
        })

        assert result["display_name"] == "John Doe"
        assert result["countries_visited"] == 5
        assert "updated_at" in result


class TestPlaceOperations:
    """Tests for visited place operations."""

    def test_create_visited_place(self, db_service):
        """Test creating a visited place."""
        place_data = {
            "region_type": "country",
            "region_code": "US",
            "region_name": "United States",
            "sync_version": 1,
            "is_deleted": False,
        }

        result = db_service.create_visited_place("test-user", place_data)

        assert result["user_id"] == "test-user"
        assert result["region_type"] == "country"
        assert result["region_code"] == "US"
        assert result["pk"] == "USER#test-user"
        assert result["sk"] == "PLACE#country#US"
        assert result["gsi1pk"] == "REGION#country"
        assert "created_at" in result

    def test_get_visited_place(self, db_service):
        """Test getting a specific visited place."""
        place_data = {
            "region_type": "us_state",
            "region_code": "CA",
            "region_name": "California",
            "sync_version": 1,
            "is_deleted": False,
        }
        db_service.create_visited_place("test-user", place_data)

        result = db_service.get_visited_place("test-user", "us_state", "CA")

        assert result is not None
        assert result["region_code"] == "CA"
        assert result["region_name"] == "California"

    def test_get_visited_place_not_found(self, db_service):
        """Test getting non-existent place returns None."""
        result = db_service.get_visited_place("test-user", "country", "ZZ")
        assert result is None

    def test_get_user_visited_places(self, db_service):
        """Test getting all visited places for a user."""
        places = [
            {"region_type": "country", "region_code": "US", "region_name": "United States"},
            {"region_type": "country", "region_code": "FR", "region_name": "France"},
            {"region_type": "us_state", "region_code": "CA", "region_name": "California"},
        ]
        for place in places:
            db_service.create_visited_place("test-user", {**place, "sync_version": 1, "is_deleted": False})

        result = db_service.get_user_visited_places("test-user")

        assert len(result) == 3

    def test_get_user_visited_places_filtered(self, db_service):
        """Test filtering visited places by region type."""
        places = [
            {"region_type": "country", "region_code": "US", "region_name": "United States"},
            {"region_type": "country", "region_code": "FR", "region_name": "France"},
            {"region_type": "us_state", "region_code": "CA", "region_name": "California"},
        ]
        for place in places:
            db_service.create_visited_place("filter-user", {**place, "sync_version": 1, "is_deleted": False})

        result = db_service.get_user_visited_places("filter-user", "country")

        assert len(result) == 2
        assert all(p["region_type"] == "country" for p in result)

    def test_update_visited_place(self, db_service):
        """Test updating a visited place."""
        place_data = {
            "region_type": "country",
            "region_code": "JP",
            "region_name": "Japan",
            "sync_version": 1,
            "is_deleted": False,
        }
        db_service.create_visited_place("update-place-user", place_data)

        result = db_service.update_visited_place(
            "update-place-user", "country", "JP",
            {"visited_date": "2024-01-15", "notes": "Great trip!"}
        )

        assert result["visited_date"] == "2024-01-15"
        assert result["notes"] == "Great trip!"

    def test_delete_visited_place_soft(self, db_service):
        """Test soft deleting a visited place."""
        place_data = {
            "region_type": "country",
            "region_code": "IT",
            "region_name": "Italy",
            "sync_version": 1,
            "is_deleted": False,
        }
        db_service.create_visited_place("delete-user", place_data)

        result = db_service.delete_visited_place("delete-user", "country", "IT", soft_delete=True)

        assert result is True
        # Verify it's soft deleted
        place = db_service.get_visited_place("delete-user", "country", "IT")
        assert place["is_deleted"] is True

    def test_delete_visited_place_hard(self, db_service):
        """Test hard deleting a visited place."""
        place_data = {
            "region_type": "country",
            "region_code": "DE",
            "region_name": "Germany",
            "sync_version": 1,
            "is_deleted": False,
        }
        db_service.create_visited_place("hard-delete-user", place_data)

        result = db_service.delete_visited_place("hard-delete-user", "country", "DE", soft_delete=False)

        assert result is True
        # Verify it's gone
        place = db_service.get_visited_place("hard-delete-user", "country", "DE")
        assert place is None


class TestBatchOperations:
    """Tests for batch operations."""

    def test_batch_create_places(self, db_service):
        """Test batch creating multiple places."""
        places = [
            {"region_type": "country", "region_code": "JP", "region_name": "Japan", "sync_version": 1, "is_deleted": False},
            {"region_type": "country", "region_code": "KR", "region_name": "South Korea", "sync_version": 1, "is_deleted": False},
            {"region_type": "country", "region_code": "CN", "region_name": "China", "sync_version": 1, "is_deleted": False},
        ]

        result = db_service.batch_create_places("batch-user", places)

        assert len(result) == 3
        # Verify all were created
        all_places = db_service.get_user_visited_places("batch-user")
        assert len(all_places) == 3


class TestSyncOperations:
    """Tests for sync operations."""

    def test_get_changes_since(self, db_service):
        """Test getting changes since a version."""
        places = [
            {"region_type": "country", "region_code": "US", "sync_version": 1, "region_name": "USA", "is_deleted": False},
            {"region_type": "country", "region_code": "FR", "sync_version": 3, "region_name": "France", "is_deleted": False},
            {"region_type": "country", "region_code": "DE", "sync_version": 5, "region_name": "Germany", "is_deleted": False},
        ]
        for place in places:
            db_service.create_visited_place("sync-user", place)

        result = db_service.get_changes_since("sync-user", 2)

        # Should return places with sync_version > 2 (FR and DE)
        assert len(result) == 2
        codes = {p["region_code"] for p in result}
        assert codes == {"FR", "DE"}

    def test_get_changes_since_empty(self, db_service):
        """Test getting changes when there are none."""
        result = db_service.get_changes_since("empty-user", 0)
        assert result == []
