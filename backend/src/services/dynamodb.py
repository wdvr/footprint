"""DynamoDB service for data persistence."""

import os
from datetime import UTC, datetime
from typing import Any

import boto3
from boto3.dynamodb.conditions import Key

# Initialize DynamoDB resource
dynamodb = boto3.resource(
    "dynamodb", region_name=os.environ.get("AWS_REGION", "us-east-1")
)
table_name = os.environ.get("DYNAMODB_TABLE", "footprint-table-dev")
table = dynamodb.Table(table_name)


class DynamoDBService:
    """Service for DynamoDB operations using single-table design."""

    # Primary key patterns
    USER_PK = "USER#{user_id}"
    USER_SK = "PROFILE"
    PLACE_SK = "PLACE#{region_type}#{region_code}"
    SYNC_SK = "SYNC#{operation_id}"

    @staticmethod
    def _get_user_pk(user_id: str) -> str:
        return f"USER#{user_id}"

    @staticmethod
    def _get_place_sk(region_type: str, region_code: str) -> str:
        return f"PLACE#{region_type}#{region_code}"

    @staticmethod
    def _get_sync_sk(operation_id: str) -> str:
        return f"SYNC#{operation_id}"

    # User operations
    def create_user(self, user_data: dict[str, Any]) -> dict[str, Any]:
        """Create a new user."""
        user_id = user_data["user_id"]
        item = {
            "pk": self._get_user_pk(user_id),
            "sk": "PROFILE",
            "gsi1pk": f"AUTH#{user_data['auth_provider']}",
            "gsi1sk": user_data["auth_provider_id"],
            "entity_type": "user",
            "created_at": datetime.now(UTC).isoformat(),
            "updated_at": datetime.now(UTC).isoformat(),
            **user_data,
        }
        table.put_item(Item=item)
        return item

    def get_user(self, user_id: str) -> dict[str, Any] | None:
        """Get user by ID."""
        response = table.get_item(
            Key={"pk": self._get_user_pk(user_id), "sk": "PROFILE"}
        )
        return response.get("Item")

    def get_user_by_auth(
        self, auth_provider: str, auth_provider_id: str
    ) -> dict[str, Any] | None:
        """Get user by auth provider and ID."""
        response = table.query(
            IndexName="gsi1",
            KeyConditionExpression=Key("gsi1pk").eq(f"AUTH#{auth_provider}")
            & Key("gsi1sk").eq(auth_provider_id),
        )
        items = response.get("Items", [])
        return items[0] if items else None

    def update_user(self, user_id: str, updates: dict[str, Any]) -> dict[str, Any]:
        """Update user data."""
        update_expr_parts = []
        expr_attr_names = {}
        expr_attr_values = {}

        for key, value in updates.items():
            safe_key = f"#{key}"
            expr_attr_names[safe_key] = key
            expr_attr_values[f":{key}"] = value
            update_expr_parts.append(f"{safe_key} = :{key}")

        # Always update updated_at
        expr_attr_names["#updated_at"] = "updated_at"
        expr_attr_values[":updated_at"] = datetime.now(UTC).isoformat()
        update_expr_parts.append("#updated_at = :updated_at")

        response = table.update_item(
            Key={"pk": self._get_user_pk(user_id), "sk": "PROFILE"},
            UpdateExpression="SET " + ", ".join(update_expr_parts),
            ExpressionAttributeNames=expr_attr_names,
            ExpressionAttributeValues=expr_attr_values,
            ReturnValues="ALL_NEW",
        )
        return response.get("Attributes", {})

    # Visited place operations
    def create_visited_place(
        self, user_id: str, place_data: dict[str, Any]
    ) -> dict[str, Any]:
        """Create a visited place record."""
        region_type = place_data["region_type"]
        region_code = place_data["region_code"]

        item = {
            "pk": self._get_user_pk(user_id),
            "sk": self._get_place_sk(region_type, region_code),
            "gsi1pk": f"REGION#{region_type}",
            "gsi1sk": region_code,
            "entity_type": "visited_place",
            "user_id": user_id,
            "created_at": datetime.now(UTC).isoformat(),
            "updated_at": datetime.now(UTC).isoformat(),
            **place_data,
        }
        table.put_item(Item=item)
        return item

    def get_visited_place(
        self, user_id: str, region_type: str, region_code: str
    ) -> dict[str, Any] | None:
        """Get a specific visited place."""
        response = table.get_item(
            Key={
                "pk": self._get_user_pk(user_id),
                "sk": self._get_place_sk(region_type, region_code),
            }
        )
        return response.get("Item")

    def get_user_visited_places(
        self, user_id: str, region_type: str | None = None
    ) -> list[dict[str, Any]]:
        """Get all visited places for a user, optionally filtered by region type."""
        if region_type:
            response = table.query(
                KeyConditionExpression=Key("pk").eq(self._get_user_pk(user_id))
                & Key("sk").begins_with(f"PLACE#{region_type}#")
            )
        else:
            response = table.query(
                KeyConditionExpression=Key("pk").eq(self._get_user_pk(user_id))
                & Key("sk").begins_with("PLACE#")
            )
        return response.get("Items", [])

    def update_visited_place(
        self, user_id: str, region_type: str, region_code: str, updates: dict[str, Any]
    ) -> dict[str, Any]:
        """Update a visited place."""
        update_expr_parts = []
        expr_attr_names = {}
        expr_attr_values = {}

        for key, value in updates.items():
            safe_key = f"#{key}"
            expr_attr_names[safe_key] = key
            expr_attr_values[f":{key}"] = value
            update_expr_parts.append(f"{safe_key} = :{key}")

        # Always update updated_at and sync_version
        expr_attr_names["#updated_at"] = "updated_at"
        expr_attr_values[":updated_at"] = datetime.now(UTC).isoformat()
        update_expr_parts.append("#updated_at = :updated_at")

        response = table.update_item(
            Key={
                "pk": self._get_user_pk(user_id),
                "sk": self._get_place_sk(region_type, region_code),
            },
            UpdateExpression="SET " + ", ".join(update_expr_parts),
            ExpressionAttributeNames=expr_attr_names,
            ExpressionAttributeValues=expr_attr_values,
            ReturnValues="ALL_NEW",
        )
        return response.get("Attributes", {})

    def delete_visited_place(
        self, user_id: str, region_type: str, region_code: str, soft_delete: bool = True
    ) -> bool:
        """Delete a visited place (soft delete by default for sync)."""
        if soft_delete:
            self.update_visited_place(
                user_id, region_type, region_code, {"is_deleted": True}
            )
        else:
            table.delete_item(
                Key={
                    "pk": self._get_user_pk(user_id),
                    "sk": self._get_place_sk(region_type, region_code),
                }
            )
        return True

    # Batch operations
    def batch_create_places(
        self, user_id: str, places: list[dict[str, Any]]
    ) -> list[dict[str, Any]]:
        """Batch create visited places."""
        created_items = []
        with table.batch_writer() as batch:
            for place_data in places:
                region_type = place_data["region_type"]
                region_code = place_data["region_code"]

                item = {
                    "pk": self._get_user_pk(user_id),
                    "sk": self._get_place_sk(region_type, region_code),
                    "gsi1pk": f"REGION#{region_type}",
                    "gsi1sk": region_code,
                    "entity_type": "visited_place",
                    "user_id": user_id,
                    "created_at": datetime.now(UTC).isoformat(),
                    "updated_at": datetime.now(UTC).isoformat(),
                    **place_data,
                }
                batch.put_item(Item=item)
                created_items.append(item)
        return created_items

    # Sync operations
    def get_changes_since(
        self, user_id: str, since_version: int
    ) -> list[dict[str, Any]]:
        """Get all changes since a specific sync version."""
        response = table.query(
            KeyConditionExpression=Key("pk").eq(self._get_user_pk(user_id))
            & Key("sk").begins_with("PLACE#"),
            FilterExpression="sync_version > :version",
            ExpressionAttributeValues={":version": since_version},
        )
        return response.get("Items", [])

    # Friend operations
    FRIEND_SK = "FRIEND#{friend_id}"
    FRIEND_REQUEST_SK = "FRIEND_REQUEST#{request_id}"

    @staticmethod
    def _get_friend_sk(friend_id: str) -> str:
        return f"FRIEND#{friend_id}"

    @staticmethod
    def _get_friend_request_sk(request_id: str) -> str:
        return f"FRIEND_REQUEST#{request_id}"

    def create_friend_request(
        self,
        from_user_id: str,
        to_user_id: str,
        request_id: str,
        message: str | None = None,
    ) -> dict[str, Any]:
        """Create a friend request."""
        item = {
            "pk": self._get_user_pk(to_user_id),
            "sk": self._get_friend_request_sk(request_id),
            "gsi1pk": f"FRIEND_REQUEST#{from_user_id}",
            "gsi1sk": to_user_id,
            "entity_type": "friend_request",
            "request_id": request_id,
            "from_user_id": from_user_id,
            "to_user_id": to_user_id,
            "status": "pending",
            "message": message,
            "created_at": datetime.now(UTC).isoformat(),
            "updated_at": datetime.now(UTC).isoformat(),
        }
        table.put_item(Item=item)
        return item

    def get_friend_requests(self, user_id: str) -> list[dict[str, Any]]:
        """Get pending friend requests for a user."""
        response = table.query(
            KeyConditionExpression=Key("pk").eq(self._get_user_pk(user_id))
            & Key("sk").begins_with("FRIEND_REQUEST#"),
            FilterExpression="status = :status",
            ExpressionAttributeValues={":status": "pending"},
        )
        return response.get("Items", [])

    def update_friend_request(
        self, user_id: str, request_id: str, status: str
    ) -> dict[str, Any]:
        """Update friend request status."""
        response = table.update_item(
            Key={
                "pk": self._get_user_pk(user_id),
                "sk": self._get_friend_request_sk(request_id),
            },
            UpdateExpression="SET #status = :status, #updated_at = :updated_at",
            ExpressionAttributeNames={"#status": "status", "#updated_at": "updated_at"},
            ExpressionAttributeValues={
                ":status": status,
                ":updated_at": datetime.now(UTC).isoformat(),
            },
            ReturnValues="ALL_NEW",
        )
        return response.get("Attributes", {})

    def create_friendship(self, user_id: str, friend_id: str) -> None:
        """Create a bidirectional friendship."""
        now = datetime.now(UTC).isoformat()

        # Create friendship for user -> friend
        table.put_item(
            Item={
                "pk": self._get_user_pk(user_id),
                "sk": self._get_friend_sk(friend_id),
                "gsi1pk": "FRIENDS",
                "gsi1sk": f"{user_id}#{friend_id}",
                "entity_type": "friendship",
                "user_id": user_id,
                "friend_id": friend_id,
                "created_at": now,
            }
        )

        # Create friendship for friend -> user
        table.put_item(
            Item={
                "pk": self._get_user_pk(friend_id),
                "sk": self._get_friend_sk(user_id),
                "gsi1pk": "FRIENDS",
                "gsi1sk": f"{friend_id}#{user_id}",
                "entity_type": "friendship",
                "user_id": friend_id,
                "friend_id": user_id,
                "created_at": now,
            }
        )

    def get_friends(self, user_id: str) -> list[dict[str, Any]]:
        """Get all friends for a user."""
        response = table.query(
            KeyConditionExpression=Key("pk").eq(self._get_user_pk(user_id))
            & Key("sk").begins_with("FRIEND#")
        )
        return response.get("Items", [])

    def remove_friendship(self, user_id: str, friend_id: str) -> None:
        """Remove a bidirectional friendship."""
        # Remove user -> friend
        table.delete_item(
            Key={
                "pk": self._get_user_pk(user_id),
                "sk": self._get_friend_sk(friend_id),
            }
        )
        # Remove friend -> user
        table.delete_item(
            Key={
                "pk": self._get_user_pk(friend_id),
                "sk": self._get_friend_sk(user_id),
            }
        )

    # Feedback operations
    FEEDBACK_SK = "FEEDBACK#{feedback_id}"

    @staticmethod
    def _get_feedback_sk(feedback_id: str) -> str:
        return f"FEEDBACK#{feedback_id}"

    def create_feedback(
        self,
        user_id: str,
        feedback_id: str,
        feedback_type: str,
        title: str,
        description: str,
        app_version: str | None = None,
        device_info: str | None = None,
    ) -> dict[str, Any]:
        """Create a feedback submission."""
        now = datetime.now(UTC).isoformat()
        item = {
            "pk": self._get_user_pk(user_id),
            "sk": self._get_feedback_sk(feedback_id),
            "gsi1pk": "FEEDBACK",
            "gsi1sk": f"{now}#{feedback_id}",
            "entity_type": "feedback",
            "feedback_id": feedback_id,
            "user_id": user_id,
            "type": feedback_type,
            "title": title,
            "description": description,
            "status": "new",
            "app_version": app_version,
            "device_info": device_info,
            "created_at": now,
            "updated_at": now,
        }
        table.put_item(Item=item)
        return item

    def get_user_feedback(self, user_id: str) -> list[dict[str, Any]]:
        """Get all feedback submitted by a user."""
        response = table.query(
            KeyConditionExpression=Key("pk").eq(self._get_user_pk(user_id))
            & Key("sk").begins_with("FEEDBACK#")
        )
        return response.get("Items", [])

    def get_all_feedback(self, limit: int = 50) -> list[dict[str, Any]]:
        """Get all feedback (for admin review)."""
        response = table.query(
            IndexName="gsi1",
            KeyConditionExpression=Key("gsi1pk").eq("FEEDBACK"),
            ScanIndexForward=False,  # Most recent first
            Limit=limit,
        )
        return response.get("Items", [])

    def update_feedback_status(
        self, user_id: str, feedback_id: str, status: str
    ) -> dict[str, Any]:
        """Update feedback status."""
        response = table.update_item(
            Key={
                "pk": self._get_user_pk(user_id),
                "sk": self._get_feedback_sk(feedback_id),
            },
            UpdateExpression="SET #status = :status, #updated_at = :updated_at",
            ExpressionAttributeNames={"#status": "status", "#updated_at": "updated_at"},
            ExpressionAttributeValues={
                ":status": status,
                ":updated_at": datetime.now(UTC).isoformat(),
            },
            ReturnValues="ALL_NEW",
        )
        return response.get("Attributes", {})


# Singleton instance
db_service = DynamoDBService()
