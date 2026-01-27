"""Google OAuth tokens model."""

from pydantic import BaseModel


class GoogleTokens(BaseModel):
    """Google OAuth tokens stored in DynamoDB."""

    user_id: str
    access_token: str
    refresh_token: str
    token_expiry: str  # ISO 8601 datetime
    email: str
    scopes: list[str]


class GoogleConnectRequest(BaseModel):
    """Request to connect Google account."""

    authorization_code: str


class GoogleConnectResponse(BaseModel):
    """Response after connecting Google account."""

    email: str
    connected: bool


class GoogleConnectionStatus(BaseModel):
    """Google connection status."""

    is_connected: bool
    email: str | None = None


class ImportCandidate(BaseModel):
    """A country candidate for import."""

    country_code: str
    country_name: str
    email_count: int
    calendar_event_count: int
    sample_sources: list["SourceSample"]
    confidence: float


class SourceSample(BaseModel):
    """A sample source (email or calendar event)."""

    id: str
    source_type: str  # "email" or "calendar"
    title: str
    date: str | None = None
    snippet: str | None = None


class ImportScanResponse(BaseModel):
    """Response from scanning Gmail/Calendar."""

    candidates: list[ImportCandidate]
    scanned_emails: int
    scanned_events: int
    scan_duration_seconds: float


class GmailScanResponse(BaseModel):
    """Response from scanning Gmail only."""

    candidates: list[ImportCandidate]
    scanned_emails: int
    scan_duration_seconds: float


class CalendarScanResponse(BaseModel):
    """Response from scanning Calendar only."""

    candidates: list[ImportCandidate]
    scanned_events: int
    scan_duration_seconds: float


class ImportConfirmRequest(BaseModel):
    """Request to confirm import of selected countries."""

    country_codes: list[str]


class ImportConfirmResponse(BaseModel):
    """Response after confirming import."""

    imported: int
    countries: list[dict]


# Resolve forward reference
ImportCandidate.model_rebuild()
