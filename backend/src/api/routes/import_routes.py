"""Import API routes for Gmail/Calendar integration."""

import logging
import time

from fastapi import APIRouter, Depends, HTTPException, Query, status
from fastapi.responses import RedirectResponse

from src.api.routes.auth import get_current_user
from src.models.google_tokens import (
    CalendarScanResponse,
    GmailScanResponse,
    GoogleConnectionStatus,
    GoogleConnectRequest,
    GoogleConnectResponse,
    ImportCandidate,
    ImportConfirmRequest,
    ImportConfirmResponse,
    ImportScanResponse,
    SourceSample,
)
from src.models.import_job import (
    DeviceTokenRequest,
    DeviceTokenResponse,
    JobStatus,
    JobStatusResponse,
    StartImportResponse,
)
from src.services.calendar_parser import (
    aggregate_calendar_countries,
    parse_calendar_events,
)
from src.services.country_extractor import get_confidence_score, get_country_name
from src.services.dynamodb import db_service
from src.services.email_parser import aggregate_email_countries, parse_emails
from src.services.google_service import google_service
from src.services.import_processor import start_import_job

logger = logging.getLogger(__name__)
logger.setLevel(logging.INFO)

router = APIRouter(prefix="/import/google", tags=["import"])

# App URL scheme for OAuth callback redirect
APP_URL_SCHEME = "com.wd.footprint.app"


@router.get("/oauth/callback")
async def oauth_callback(
    code: str | None = Query(None),
    error: str | None = Query(None),
    error_description: str | None = Query(None),
):
    """
    OAuth callback endpoint for Google Sign-In.

    Google redirects here after user authenticates. This endpoint then
    redirects to the iOS app using its custom URL scheme, passing along
    the authorization code.
    """
    logger.info(f"[OAuth Callback] Received - code: {code is not None}, error: {error}")

    if error:
        # Redirect to app with error
        logger.error(
            f"[OAuth Callback] Error from Google: {error} - {error_description}"
        )
        redirect_url = f"{APP_URL_SCHEME}://oauth?error={error}"
        if error_description:
            redirect_url += f"&error_description={error_description}"
        return RedirectResponse(url=redirect_url)

    if not code:
        logger.error("[OAuth Callback] No code received")
        return RedirectResponse(url=f"{APP_URL_SCHEME}://oauth?error=no_code")

    # Redirect to app with the authorization code
    logger.info("[OAuth Callback] Redirecting to app with code")
    redirect_url = f"{APP_URL_SCHEME}://oauth?code={code}"
    return RedirectResponse(url=redirect_url)


@router.get("/status", response_model=GoogleConnectionStatus)
async def get_connection_status(current_user: dict = Depends(get_current_user)):
    """Check if user has a connected Google account."""
    user_id = current_user["user_id"]
    return google_service.get_connection_status(user_id)


@router.post("/connect", response_model=GoogleConnectResponse)
async def connect_google(
    request: GoogleConnectRequest, current_user: dict = Depends(get_current_user)
):
    """
    Connect Google account by exchanging authorization code for tokens.

    The iOS app obtains an authorization code via Google Sign-In OAuth flow,
    then sends it here to exchange for access/refresh tokens which are stored
    server-side.
    """
    user_id = current_user["user_id"]

    try:
        result = google_service.exchange_auth_code(request.authorization_code, user_id)
        return GoogleConnectResponse(email=result["email"], connected=True)
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Failed to connect Google account: {str(e)}",
        ) from e


@router.delete("/disconnect", status_code=status.HTTP_204_NO_CONTENT)
async def disconnect_google(current_user: dict = Depends(get_current_user)):
    """
    Disconnect Google account by removing stored tokens.

    This revokes the app's access to the user's Gmail and Calendar.
    """
    user_id = current_user["user_id"]
    google_service.disconnect(user_id)


@router.post("/scan", response_model=ImportScanResponse)
async def scan_google_imports(current_user: dict = Depends(get_current_user)):
    """
    Scan Gmail and Calendar for travel history.

    This searches the user's Gmail for travel-related emails (flights, hotels,
    trains, car rentals) and Calendar for events with locations. Countries
    are extracted using NLP and geocoding, then aggregated and returned as
    candidates for import.
    """
    user_id = current_user["user_id"]
    start_time = time.time()

    # Check if Google is connected
    connection_status = google_service.get_connection_status(user_id)
    if not connection_status["is_connected"]:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Google account not connected",
        )

    # Get existing visited places to exclude
    existing_places = db_service.get_user_visited_places(user_id, region_type="country")
    existing_countries = {place["region_code"] for place in existing_places}

    # Parse emails
    scanned_emails = 0
    email_countries = {}
    try:
        gmail_service = google_service.get_gmail_service(user_id)
        emails = parse_emails(gmail_service, max_emails=500)
        scanned_emails = len(emails)
        email_countries = aggregate_email_countries(emails)
    except Exception:
        # Continue without emails if Gmail access fails
        pass

    # Parse calendar events
    scanned_events = 0
    calendar_countries = {}
    try:
        calendar_service = google_service.get_calendar_service(user_id)
        events = parse_calendar_events(calendar_service, max_events=1000)
        scanned_events = len(events)
        calendar_countries = aggregate_calendar_countries(events)
    except Exception:
        # Continue without calendar if access fails
        pass

    # Merge results from emails and calendar
    all_countries = set(email_countries.keys()) | set(calendar_countries.keys())

    # Filter out already visited countries
    new_countries = all_countries - existing_countries

    # Build candidates
    candidates = []
    for country_code in new_countries:
        country_name = get_country_name(country_code)
        if not country_name:
            continue

        email_data = email_countries.get(country_code, {"count": 0, "samples": []})
        calendar_data = calendar_countries.get(
            country_code, {"count": 0, "samples": []}
        )

        email_count = email_data["count"]
        calendar_count = calendar_data["count"]

        # Combine samples from both sources
        samples = []
        for sample in email_data.get("samples", [])[:3]:
            samples.append(
                SourceSample(
                    id=sample["id"],
                    source_type="email",
                    title=sample["title"],
                    date=sample.get("date"),
                    snippet=sample.get("snippet"),
                )
            )
        for sample in calendar_data.get("samples", [])[:2]:
            samples.append(
                SourceSample(
                    id=sample["id"],
                    source_type="calendar",
                    title=sample["title"],
                    date=sample.get("date"),
                    snippet=sample.get("snippet"),
                )
            )

        confidence = get_confidence_score(
            email_count,
            calendar_count,
            has_flight="flight" in " ".join(s.title.lower() for s in samples),
        )

        candidates.append(
            ImportCandidate(
                country_code=country_code,
                country_name=country_name,
                email_count=email_count,
                calendar_event_count=calendar_count,
                sample_sources=samples,
                confidence=confidence,
            )
        )

    # Sort by total evidence (emails + events)
    candidates.sort(key=lambda c: c.email_count + c.calendar_event_count, reverse=True)

    scan_duration = time.time() - start_time

    return ImportScanResponse(
        candidates=candidates,
        scanned_emails=scanned_emails,
        scanned_events=scanned_events,
        scan_duration_seconds=round(scan_duration, 2),
    )


@router.post("/scan/gmail", response_model=GmailScanResponse)
async def scan_gmail_only(current_user: dict = Depends(get_current_user)):
    """
    Scan Gmail only for travel history.

    Searches for flight bookings, hotel reservations, train tickets, etc.
    Returns country candidates found in emails.
    """
    user_id = current_user["user_id"]
    start_time = time.time()
    logger.info(f"[Gmail Scan] Starting for user {user_id}")

    # Check if Google is connected
    connection_status = google_service.get_connection_status(user_id)
    logger.info(f"[Gmail Scan] Connection status: {connection_status}")
    if not connection_status["is_connected"]:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Google account not connected",
        )

    # Get existing visited places to exclude
    existing_places = db_service.get_user_visited_places(user_id, region_type="country")
    existing_countries = {place["region_code"] for place in existing_places}
    logger.info(f"[Gmail Scan] User has {len(existing_countries)} existing countries")

    # Parse emails
    scanned_emails = 0
    email_countries = {}
    try:
        gmail_service = google_service.get_gmail_service(user_id)
        logger.info("[Gmail Scan] Got Gmail service, starting parse...")
        emails = parse_emails(gmail_service, max_emails=500)
        scanned_emails = len(emails)
        logger.info(f"[Gmail Scan] Parsed {scanned_emails} emails")
        email_countries = aggregate_email_countries(emails)
        logger.info(f"[Gmail Scan] Found {len(email_countries)} countries")
    except Exception as e:
        logger.error(f"[Gmail Scan] Error: {e}", exc_info=True)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to scan Gmail: {str(e)}",
        ) from e

    # Filter out already visited countries
    new_countries = set(email_countries.keys()) - existing_countries

    # Build candidates
    candidates = []
    for country_code in new_countries:
        country_name = get_country_name(country_code)
        if not country_name:
            continue

        email_data = email_countries.get(country_code, {"count": 0, "samples": []})
        email_count = email_data["count"]

        samples = []
        for sample in email_data.get("samples", [])[:5]:
            samples.append(
                SourceSample(
                    id=sample["id"],
                    source_type="email",
                    title=sample["title"],
                    date=sample.get("date"),
                    snippet=sample.get("snippet"),
                )
            )

        confidence = get_confidence_score(
            email_count,
            0,  # No calendar events
            has_flight="flight" in " ".join(s.title.lower() for s in samples),
        )

        candidates.append(
            ImportCandidate(
                country_code=country_code,
                country_name=country_name,
                email_count=email_count,
                calendar_event_count=0,
                sample_sources=samples,
                confidence=confidence,
            )
        )

    candidates.sort(key=lambda c: c.email_count, reverse=True)
    scan_duration = time.time() - start_time
    logger.info(
        f"[Gmail Scan] Complete in {scan_duration:.2f}s, {len(candidates)} candidates"
    )

    return GmailScanResponse(
        candidates=candidates,
        scanned_emails=scanned_emails,
        scan_duration_seconds=round(scan_duration, 2),
    )


@router.post("/scan/calendar", response_model=CalendarScanResponse)
async def scan_calendar_only(current_user: dict = Depends(get_current_user)):
    """
    Scan Google Calendar only for travel history.

    Searches for events with locations that indicate travel.
    Returns country candidates found in calendar events.
    """
    user_id = current_user["user_id"]
    start_time = time.time()
    logger.info(f"[Calendar Scan] Starting for user {user_id}")

    # Check if Google is connected
    connection_status = google_service.get_connection_status(user_id)
    logger.info(f"[Calendar Scan] Connection status: {connection_status}")
    if not connection_status["is_connected"]:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Google account not connected",
        )

    # Get existing visited places to exclude
    existing_places = db_service.get_user_visited_places(user_id, region_type="country")
    existing_countries = {place["region_code"] for place in existing_places}
    logger.info(
        f"[Calendar Scan] User has {len(existing_countries)} existing countries"
    )

    # Parse calendar events
    scanned_events = 0
    calendar_countries = {}
    try:
        calendar_service = google_service.get_calendar_service(user_id)
        logger.info("[Calendar Scan] Got Calendar service, starting parse...")
        events = parse_calendar_events(calendar_service, max_events=1000)
        scanned_events = len(events)
        logger.info(f"[Calendar Scan] Parsed {scanned_events} events")
        calendar_countries = aggregate_calendar_countries(events)
        logger.info(f"[Calendar Scan] Found {len(calendar_countries)} countries")
    except Exception as e:
        logger.error(f"[Calendar Scan] Error: {e}", exc_info=True)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to scan Calendar: {str(e)}",
        ) from e

    # Filter out already visited countries
    new_countries = set(calendar_countries.keys()) - existing_countries

    # Build candidates
    candidates = []
    for country_code in new_countries:
        country_name = get_country_name(country_code)
        if not country_name:
            continue

        calendar_data = calendar_countries.get(
            country_code, {"count": 0, "samples": []}
        )
        calendar_count = calendar_data["count"]

        samples = []
        for sample in calendar_data.get("samples", [])[:5]:
            samples.append(
                SourceSample(
                    id=sample["id"],
                    source_type="calendar",
                    title=sample["title"],
                    date=sample.get("date"),
                    snippet=sample.get("snippet"),
                )
            )

        confidence = get_confidence_score(
            0,  # No emails
            calendar_count,
            has_flight=False,
        )

        candidates.append(
            ImportCandidate(
                country_code=country_code,
                country_name=country_name,
                email_count=0,
                calendar_event_count=calendar_count,
                sample_sources=samples,
                confidence=confidence,
            )
        )

    candidates.sort(key=lambda c: c.calendar_event_count, reverse=True)
    scan_duration = time.time() - start_time
    logger.info(
        f"[Calendar Scan] Complete in {scan_duration:.2f}s, {len(candidates)} candidates"
    )

    return CalendarScanResponse(
        candidates=candidates,
        scanned_events=scanned_events,
        scan_duration_seconds=round(scan_duration, 2),
    )


@router.post("/confirm", response_model=ImportConfirmResponse)
async def confirm_import(
    request: ImportConfirmRequest, current_user: dict = Depends(get_current_user)
):
    """
    Confirm import of selected countries.

    Creates VisitedPlace records for the selected country codes.
    """
    user_id = current_user["user_id"]

    if not request.country_codes:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="No countries selected for import",
        )

    # Create visited places for each country
    imported_countries = []
    for country_code in request.country_codes:
        country_name = get_country_name(country_code)
        if not country_name:
            continue

        # Check if already exists
        existing = db_service.get_visited_place(user_id, "country", country_code)
        if existing and not existing.get("is_deleted"):
            continue

        # Create the visited place
        place_data = {
            "region_type": "country",
            "region_code": country_code,
            "region_name": country_name,
            "notes": "Imported from Gmail/Calendar",
        }

        db_service.create_visited_place(user_id, place_data)

        imported_countries.append(
            {
                "country_code": country_code,
                "country_name": country_name,
                "region_type": "country",
            }
        )

    # Update user stats
    if imported_countries:
        current_count = current_user.get("countries_visited", 0)
        db_service.update_user(
            user_id, {"countries_visited": current_count + len(imported_countries)}
        )

    return ImportConfirmResponse(
        imported=len(imported_countries),
        countries=imported_countries,
    )


# Async import endpoints
@router.post("/scan/start", response_model=StartImportResponse)
async def start_async_scan(current_user: dict = Depends(get_current_user)):
    """
    Start an async import scan job.

    This initiates background scanning of Gmail and Calendar.
    The job processes asynchronously and sends a push notification when done.
    Poll /scan/status/{job_id} for progress updates.
    """
    user_id = current_user["user_id"]

    # Check if Google is connected
    connection_status = google_service.get_connection_status(user_id)
    if not connection_status["is_connected"]:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Google account not connected",
        )

    # Start the async job
    job_id = await start_import_job(user_id)

    return StartImportResponse(
        job_id=job_id,
        status=JobStatus.PENDING,
        message="Import scan started. You will receive a notification when complete.",
    )


@router.get("/scan/status/{job_id}", response_model=JobStatusResponse)
async def get_scan_status(job_id: str, current_user: dict = Depends(get_current_user)):
    """
    Get the status of an import scan job.

    Returns current progress including emails/events scanned and current step.
    """
    user_id = current_user["user_id"]

    job = db_service.get_import_job(user_id, job_id)
    if not job:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Import job not found",
        )

    # Convert progress dict back to model
    from src.models.import_job import ImportJobProgress

    progress_data = job.get("progress", {})
    progress = (
        ImportJobProgress(**progress_data) if progress_data else ImportJobProgress()
    )

    return JobStatusResponse(
        job_id=job_id,
        status=JobStatus(job.get("status", "pending")),
        progress=progress,
        created_at=job.get("created_at", ""),
        updated_at=job.get("updated_at", ""),
        completed_at=job.get("completed_at"),
        error_message=job.get("error_message"),
        candidates_count=job.get("candidates_count", 0),
    )


@router.get("/scan/results/{job_id}", response_model=ImportScanResponse)
async def get_scan_results(job_id: str, current_user: dict = Depends(get_current_user)):
    """
    Get the results of a completed import scan job.

    Only available after the job status is COMPLETED.
    """
    user_id = current_user["user_id"]

    # Check job status
    job = db_service.get_import_job(user_id, job_id)
    if not job:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Import job not found",
        )

    if job.get("status") != JobStatus.COMPLETED.value:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Job not completed. Current status: {job.get('status')}",
        )

    # Get stored results
    results = db_service.get_import_results(user_id, job_id)
    if not results:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Import results not found or expired",
        )

    # Convert stored candidates to models
    candidates = []
    for c in results.get("candidates", []):
        samples = [SourceSample(**s) for s in c.get("sample_sources", [])]
        candidates.append(
            ImportCandidate(
                country_code=c["country_code"],
                country_name=c["country_name"],
                email_count=c.get("email_count", 0),
                calendar_event_count=c.get("calendar_event_count", 0),
                sample_sources=samples,
                confidence=c.get("confidence", 0.5),
            )
        )

    return ImportScanResponse(
        candidates=candidates,
        scanned_emails=results.get("scanned_emails", 0),
        scanned_events=results.get("scanned_events", 0),
        scan_duration_seconds=0,  # Not tracked for async
    )


# Push notification device token endpoints
@router.post("/notifications/register", response_model=DeviceTokenResponse)
async def register_device_token(
    request: DeviceTokenRequest, current_user: dict = Depends(get_current_user)
):
    """
    Register a device token for push notifications.

    The iOS app should call this after obtaining an APNs device token.
    """
    user_id = current_user["user_id"]

    db_service.register_device_token(user_id, request.device_token, request.platform)

    return DeviceTokenResponse(
        registered=True,
        message="Device registered for push notifications",
    )


@router.delete("/notifications/unregister")
async def unregister_device_token(
    device_token: str, current_user: dict = Depends(get_current_user)
):
    """
    Unregister a device token for push notifications.
    """
    user_id = current_user["user_id"]
    db_service.delete_device_token(user_id, device_token)
    return {"success": True}
