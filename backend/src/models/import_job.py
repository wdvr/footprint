"""Import job models for async Gmail/Calendar scanning."""

from datetime import datetime
from enum import Enum

from pydantic import BaseModel, Field


class JobStatus(str, Enum):
    """Import job status."""

    PENDING = "pending"
    SCANNING_EMAILS = "scanning_emails"
    SCANNING_CALENDAR = "scanning_calendar"
    PROCESSING = "processing"
    COMPLETED = "completed"
    FAILED = "failed"


class ImportJobProgress(BaseModel):
    """Progress information for an import job."""

    emails_scanned: int = 0
    emails_total: int = 0
    events_scanned: int = 0
    events_total: int = 0
    calendar_year: int | None = None
    current_step: str = "initializing"


class ImportJob(BaseModel):
    """Import job record."""

    job_id: str
    user_id: str
    status: JobStatus = JobStatus.PENDING
    progress: ImportJobProgress = Field(default_factory=ImportJobProgress)
    created_at: str = Field(default_factory=lambda: datetime.utcnow().isoformat())
    updated_at: str = Field(default_factory=lambda: datetime.utcnow().isoformat())
    completed_at: str | None = None
    error_message: str | None = None
    # Results stored when completed
    candidates_count: int = 0
    scanned_emails: int = 0
    scanned_events: int = 0


class StartImportResponse(BaseModel):
    """Response when starting an async import job."""

    job_id: str
    status: JobStatus
    message: str


class JobStatusResponse(BaseModel):
    """Response for job status check."""

    job_id: str
    status: JobStatus
    progress: ImportJobProgress
    created_at: str
    updated_at: str
    completed_at: str | None = None
    error_message: str | None = None
    candidates_count: int = 0


class DeviceTokenRequest(BaseModel):
    """Request to register device token for push notifications."""

    device_token: str
    platform: str = "ios"  # ios, android


class DeviceTokenResponse(BaseModel):
    """Response for device token registration."""

    registered: bool
    message: str
