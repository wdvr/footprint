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

    # Google tokens operations
    GOOGLE_TOKENS_SK = "GOOGLE_TOKENS"

    def store_google_tokens(
        self, user_id: str, token_data: dict[str, Any]
    ) -> dict[str, Any]:
        """Store Google OAuth tokens for a user."""
        now = datetime.now(UTC).isoformat()
        item = {
            "pk": self._get_user_pk(user_id),
            "sk": self.GOOGLE_TOKENS_SK,
            "entity_type": "google_tokens",
            "user_id": user_id,
            "access_token": token_data.get("access_token", ""),
            "refresh_token": token_data.get("refresh_token", ""),
            "token_expiry": token_data.get("token_expiry", ""),
            "email": token_data.get("email", ""),
            "scopes": token_data.get("scopes", []),
            "created_at": now,
            "updated_at": now,
        }
        table.put_item(Item=item)
        return item

    def get_google_tokens(self, user_id: str) -> dict[str, Any] | None:
        """Get Google OAuth tokens for a user."""
        response = table.get_item(
            Key={"pk": self._get_user_pk(user_id), "sk": self.GOOGLE_TOKENS_SK}
        )
        return response.get("Item")

    def update_google_tokens(
        self, user_id: str, updates: dict[str, Any]
    ) -> dict[str, Any]:
        """Update Google OAuth tokens."""
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
            Key={"pk": self._get_user_pk(user_id), "sk": self.GOOGLE_TOKENS_SK},
            UpdateExpression="SET " + ", ".join(update_expr_parts),
            ExpressionAttributeNames=expr_attr_names,
            ExpressionAttributeValues=expr_attr_values,
            ReturnValues="ALL_NEW",
        )
        return response.get("Attributes", {})

    def delete_google_tokens(self, user_id: str) -> bool:
        """Delete Google OAuth tokens for a user."""
        table.delete_item(
            Key={"pk": self._get_user_pk(user_id), "sk": self.GOOGLE_TOKENS_SK}
        )
        return True

    # Import job operations
    IMPORT_JOB_SK = "IMPORT_JOB#{job_id}"

    @staticmethod
    def _get_import_job_sk(job_id: str) -> str:
        return f"IMPORT_JOB#{job_id}"

    def create_import_job(
        self, user_id: str, job_id: str, job_data: dict[str, Any]
    ) -> dict[str, Any]:
        """Create an import job record."""
        now = datetime.now(UTC).isoformat()
        item = {
            "pk": self._get_user_pk(user_id),
            "sk": self._get_import_job_sk(job_id),
            "gsi1pk": "IMPORT_JOB",
            "gsi1sk": f"{user_id}#{job_id}",
            "entity_type": "import_job",
            "job_id": job_id,
            "user_id": user_id,
            "status": job_data.get("status", "pending"),
            "progress": job_data.get("progress", {}),
            "created_at": now,
            "updated_at": now,
            **{k: v for k, v in job_data.items() if k not in ["status", "progress"]},
        }
        table.put_item(Item=item)
        return item

    def get_import_job(self, user_id: str, job_id: str) -> dict[str, Any] | None:
        """Get an import job by ID."""
        response = table.get_item(
            Key={
                "pk": self._get_user_pk(user_id),
                "sk": self._get_import_job_sk(job_id),
            }
        )
        return response.get("Item")

    def get_user_import_jobs(
        self, user_id: str, limit: int = 10
    ) -> list[dict[str, Any]]:
        """Get recent import jobs for a user."""
        response = table.query(
            KeyConditionExpression=Key("pk").eq(self._get_user_pk(user_id))
            & Key("sk").begins_with("IMPORT_JOB#"),
            ScanIndexForward=False,
            Limit=limit,
        )
        return response.get("Items", [])

    def update_import_job(
        self, user_id: str, job_id: str, updates: dict[str, Any]
    ) -> dict[str, Any]:
        """Update an import job."""
        update_expr_parts = []
        expr_attr_names = {}
        expr_attr_values = {}

        for key, value in updates.items():
            safe_key = f"#{key}"
            expr_attr_names[safe_key] = key
            expr_attr_values[f":{key}"] = value
            update_expr_parts.append(f"{safe_key} = :{key}")

        # Always update updated_at (if not already in updates)
        if "updated_at" not in updates:
            expr_attr_names["#updated_at"] = "updated_at"
            expr_attr_values[":updated_at"] = datetime.now(UTC).isoformat()
            update_expr_parts.append("#updated_at = :updated_at")

        response = table.update_item(
            Key={
                "pk": self._get_user_pk(user_id),
                "sk": self._get_import_job_sk(job_id),
            },
            UpdateExpression="SET " + ", ".join(update_expr_parts),
            ExpressionAttributeNames=expr_attr_names,
            ExpressionAttributeValues=expr_attr_values,
            ReturnValues="ALL_NEW",
        )
        return response.get("Attributes", {})

    # Device token operations for push notifications
    DEVICE_TOKEN_SK = "DEVICE_TOKEN#{device_token}"

    @staticmethod
    def _get_device_token_sk(device_token: str) -> str:
        # Use hash of token to keep SK short
        import hashlib

        token_hash = hashlib.sha256(device_token.encode()).hexdigest()[:16]
        return f"DEVICE_TOKEN#{token_hash}"

    def register_device_token(
        self, user_id: str, device_token: str, platform: str = "ios"
    ) -> dict[str, Any]:
        """Register a device token for push notifications."""
        now = datetime.now(UTC).isoformat()
        item = {
            "pk": self._get_user_pk(user_id),
            "sk": self._get_device_token_sk(device_token),
            "gsi1pk": "DEVICE_TOKEN",
            "gsi1sk": device_token,
            "entity_type": "device_token",
            "user_id": user_id,
            "device_token": device_token,
            "platform": platform,
            "created_at": now,
            "updated_at": now,
        }
        table.put_item(Item=item)
        return item

    def get_user_device_tokens(self, user_id: str) -> list[dict[str, Any]]:
        """Get all device tokens for a user."""
        response = table.query(
            KeyConditionExpression=Key("pk").eq(self._get_user_pk(user_id))
            & Key("sk").begins_with("DEVICE_TOKEN#")
        )
        return response.get("Items", [])

    def delete_device_token(self, user_id: str, device_token: str) -> bool:
        """Delete a device token."""
        table.delete_item(
            Key={
                "pk": self._get_user_pk(user_id),
                "sk": self._get_device_token_sk(device_token),
            }
        )
        return True

    # Store import results for async jobs
    IMPORT_RESULTS_SK = "IMPORT_RESULTS#{job_id}"

    @staticmethod
    def _get_import_results_sk(job_id: str) -> str:
        return f"IMPORT_RESULTS#{job_id}"

    def store_import_results(
        self, user_id: str, job_id: str, results: dict[str, Any]
    ) -> dict[str, Any]:
        """Store import scan results for a job."""
        now = datetime.now(UTC).isoformat()
        item = {
            "pk": self._get_user_pk(user_id),
            "sk": self._get_import_results_sk(job_id),
            "entity_type": "import_results",
            "job_id": job_id,
            "user_id": user_id,
            "candidates": results.get("candidates", []),
            "scanned_emails": results.get("scanned_emails", 0),
            "scanned_events": results.get("scanned_events", 0),
            "created_at": now,
            # TTL - expire after 24 hours
            "ttl": int(datetime.now(UTC).timestamp()) + 86400,
        }
        table.put_item(Item=item)
        return item

    def get_import_results(self, user_id: str, job_id: str) -> dict[str, Any] | None:
        """Get import scan results for a job."""
        response = table.get_item(
            Key={
                "pk": self._get_user_pk(user_id),
                "sk": self._get_import_results_sk(job_id),
            }
        )
        return response.get("Item")


# Singleton instance
db_service = DynamoDBService()
