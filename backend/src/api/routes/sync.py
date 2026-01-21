"""Sync API routes for offline-first functionality."""

from datetime import UTC, datetime

from fastapi import APIRouter, Depends
from pydantic import BaseModel

from src.api.routes.auth import get_current_user
from src.services.dynamodb import db_service

router = APIRouter(prefix="/sync", tags=["sync"])


class SyncOperation(BaseModel):
    """Single sync operation from client."""

    operation_id: str
    operation_type: str  # create, update, delete
    entity_type: str  # visited_place
    entity_id: str
    entity_data: dict
    client_version: int
    client_timestamp: str


class SyncRequest(BaseModel):
    """Client sync request."""

    device_id: str
    last_sync_version: int
    operations: list[SyncOperation]


class SyncConflict(BaseModel):
    """Sync conflict information."""

    operation_id: str
    entity_id: str
    conflict_type: str
    client_data: dict
    server_data: dict
    suggested_resolution: str


class ServerOperation(BaseModel):
    """Server operation to send to client."""

    operation_type: str
    entity_type: str
    entity_id: str
    entity_data: dict
    server_version: int


class SyncResponse(BaseModel):
    """Server sync response."""

    success: bool
    new_sync_version: int
    server_operations: list[ServerOperation]
    conflicts: list[SyncConflict]
    errors: list[str]
    sync_timestamp: str


@router.post("", response_model=SyncResponse)
async def sync_data(
    request: SyncRequest,
    current_user: dict = Depends(get_current_user),
):
    """
    Sync client data with server.

    Processes client operations and returns server changes since last sync.
    Uses last-write-wins conflict resolution by default.
    """
    user_id = current_user["user_id"]
    errors: list[str] = []
    conflicts: list[SyncConflict] = []
    processed_count = 0

    # Process client operations
    for op in request.operations:
        try:
            if op.entity_type == "visited_place":
                _process_place_operation(user_id, op, conflicts)
                processed_count += 1
        except Exception as e:
            errors.append(f"Error processing operation {op.operation_id}: {str(e)}")

    # Get server changes since last sync
    server_changes = db_service.get_changes_since(user_id, request.last_sync_version)

    server_operations: list[ServerOperation] = []
    for change in server_changes:
        server_operations.append(
            ServerOperation(
                operation_type="update" if not change.get("is_deleted") else "delete",
                entity_type="visited_place",
                entity_id=f"{change.get('region_type')}#{change.get('region_code')}",
                entity_data=change,
                server_version=change.get("sync_version", 1),
            )
        )

    # Calculate new sync version
    current_sync_version = current_user.get("sync_version", 1)
    new_sync_version = current_sync_version + 1

    # Update user's sync version
    db_service.update_user(
        user_id,
        {
            "sync_version": new_sync_version,
            "last_sync_at": datetime.now(UTC).isoformat(),
            "last_sync_device": request.device_id,
        },
    )

    return SyncResponse(
        success=len(errors) == 0,
        new_sync_version=new_sync_version,
        server_operations=server_operations,
        conflicts=conflicts,
        errors=errors,
        sync_timestamp=datetime.now(UTC).isoformat(),
    )


def _process_place_operation(
    user_id: str, op: SyncOperation, conflicts: list[SyncConflict]
) -> None:
    """Process a visited place sync operation."""
    entity_parts = op.entity_id.split("#")
    if len(entity_parts) != 2:
        return

    region_type, region_code = entity_parts
    existing = db_service.get_visited_place(user_id, region_type, region_code)

    if op.operation_type == "create":
        if existing and not existing.get("is_deleted", False):
            # Conflict: already exists
            # Check versions for conflict
            server_version = existing.get("sync_version", 1)
            if server_version > op.client_version:
                conflicts.append(
                    SyncConflict(
                        operation_id=op.operation_id,
                        entity_id=op.entity_id,
                        conflict_type="create_exists",
                        client_data=op.entity_data,
                        server_data=existing,
                        suggested_resolution="server_wins",
                    )
                )
                return

        # Create or restore
        place_data = {
            "region_type": region_type,
            "region_code": region_code,
            "region_name": op.entity_data.get("region_name", ""),
            "visited_date": op.entity_data.get("visited_date"),
            "notes": op.entity_data.get("notes"),
            "sync_version": op.client_version + 1,
            "is_deleted": False,
        }

        if existing:
            db_service.update_visited_place(
                user_id, region_type, region_code, place_data
            )
        else:
            db_service.create_visited_place(user_id, place_data)

    elif op.operation_type == "update":
        if not existing:
            # Can't update non-existent record
            return

        # Check for version conflict
        server_version = existing.get("sync_version", 1)
        if server_version > op.client_version:
            conflicts.append(
                SyncConflict(
                    operation_id=op.operation_id,
                    entity_id=op.entity_id,
                    conflict_type="version_mismatch",
                    client_data=op.entity_data,
                    server_data=existing,
                    suggested_resolution="last_write_wins",
                )
            )
            # Last write wins - proceed with update anyway
            # In a more sophisticated system, we'd let the client decide

        update_data = {
            "visited_date": op.entity_data.get("visited_date"),
            "notes": op.entity_data.get("notes"),
            "sync_version": max(server_version, op.client_version) + 1,
        }
        db_service.update_visited_place(user_id, region_type, region_code, update_data)

    elif op.operation_type == "delete":
        if existing and not existing.get("is_deleted", False):
            db_service.delete_visited_place(user_id, region_type, region_code)


@router.get("/status")
async def get_sync_status(current_user: dict = Depends(get_current_user)):
    """
    Get current sync status.

    Returns the user's current sync version and last sync timestamp.
    """
    return {
        "user_id": current_user["user_id"],
        "sync_version": current_user.get("sync_version", 1),
        "last_sync_at": current_user.get("last_sync_at"),
        "last_sync_device": current_user.get("last_sync_device"),
    }
