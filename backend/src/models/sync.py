"""Sync and conflict resolution models."""

from datetime import datetime
from typing import Optional, Dict, Any, List
from pydantic import BaseModel, Field, ConfigDict
from enum import Enum


class SyncOperationType(str, Enum):
    """Types of sync operations."""
    CREATE = "create"
    UPDATE = "update"
    DELETE = "delete"
    BATCH_CREATE = "batch_create"
    BATCH_UPDATE = "batch_update"
    BATCH_DELETE = "batch_delete"


class ConflictResolutionStrategy(str, Enum):
    """Conflict resolution strategies."""
    CLIENT_WINS = "client_wins"  # Client data overrides server
    SERVER_WINS = "server_wins"  # Server data overrides client
    MERGE = "merge"              # Intelligent merge of both
    MANUAL = "manual"            # Require user intervention


class SyncOperation(BaseModel):
    """Individual sync operation."""
    model_config = ConfigDict(from_attributes=True)

    operation_id: str = Field(..., description="Unique operation identifier")
    user_id: str = Field(..., description="User performing the operation")
    operation_type: SyncOperationType = Field(..., description="Type of operation")

    # Target data
    entity_type: str = Field(..., description="Type of entity (visited_place, user)")
    entity_id: str = Field(..., description="Entity identifier")
    entity_data: Dict[str, Any] = Field(..., description="Entity data payload")

    # Versioning
    client_version: int = Field(..., description="Client-side version number")
    server_version: Optional[int] = Field(None, description="Server-side version number")

    # Timestamps
    client_timestamp: datetime = Field(..., description="When operation was created on client")
    server_timestamp: Optional[datetime] = Field(None, description="When operation was processed on server")

    # Conflict resolution
    has_conflict: bool = Field(default=False, description="Whether operation has conflicts")
    conflict_details: Optional[Dict[str, Any]] = Field(None, description="Conflict information")
    resolution_strategy: Optional[ConflictResolutionStrategy] = Field(None, description="How to resolve conflicts")

    # Processing status
    is_processed: bool = Field(default=False, description="Whether operation has been processed")
    processing_error: Optional[str] = Field(None, description="Error message if processing failed")


class SyncBatch(BaseModel):
    """Batch of sync operations."""
    batch_id: str = Field(..., description="Unique batch identifier")
    user_id: str = Field(..., description="User performing the batch")
    operations: List[SyncOperation] = Field(..., max_items=100, description="Operations in the batch")

    # Batch metadata
    created_at: datetime = Field(default_factory=datetime.utcnow, description="Batch creation time")
    processed_at: Optional[datetime] = Field(None, description="When batch was processed")

    # Status tracking
    total_operations: int = Field(..., description="Total number of operations")
    successful_operations: int = Field(default=0, description="Number of successful operations")
    failed_operations: int = Field(default=0, description="Number of failed operations")
    conflicted_operations: int = Field(default=0, description="Number of operations with conflicts")


class ConflictResolution(BaseModel):
    """Conflict resolution information."""
    operation_id: str = Field(..., description="Operation with conflict")
    conflict_type: str = Field(..., description="Type of conflict detected")

    # Conflicting data
    client_data: Dict[str, Any] = Field(..., description="Client-side data")
    server_data: Dict[str, Any] = Field(..., description="Server-side data")

    # Resolution options
    suggested_strategy: ConflictResolutionStrategy = Field(..., description="Suggested resolution strategy")
    available_strategies: List[ConflictResolutionStrategy] = Field(..., description="Available resolution options")

    # Timestamps
    detected_at: datetime = Field(default_factory=datetime.utcnow, description="When conflict was detected")
    resolved_at: Optional[datetime] = Field(None, description="When conflict was resolved")
    resolution_chosen: Optional[ConflictResolutionStrategy] = Field(None, description="Chosen resolution strategy")
    resolved_data: Optional[Dict[str, Any]] = Field(None, description="Final resolved data")


class SyncStatus(BaseModel):
    """Overall sync status for a user."""
    user_id: str
    last_sync_at: Optional[datetime] = None
    pending_operations: int = 0
    unresolved_conflicts: int = 0
    sync_version: int = 1
    device_id: Optional[str] = None
    device_name: Optional[str] = None


class SyncRequest(BaseModel):
    """Client sync request."""
    user_id: str
    device_id: str
    last_sync_version: int
    operations: List[SyncOperation] = Field(max_items=100)


class SyncResponse(BaseModel):
    """Server sync response."""
    success: bool
    new_sync_version: int
    server_operations: List[SyncOperation] = Field(default_factory=list)
    conflicts: List[ConflictResolution] = Field(default_factory=list)
    errors: List[str] = Field(default_factory=list)
    sync_timestamp: datetime = Field(default_factory=datetime.utcnow)