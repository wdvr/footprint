"""Async import job processor for Gmail/Calendar scanning."""

import asyncio
import time
import uuid
from datetime import UTC, datetime

from src.models.google_tokens import ImportCandidate, SourceSample
from src.models.import_job import ImportJobProgress, JobStatus
from src.services.calendar_parser import parse_calendar_events_with_progress
from src.services.country_extractor import get_confidence_score, get_country_name
from src.services.dynamodb import db_service
from src.services.email_parser import parse_emails_with_progress
from src.services.google_service import google_service
from src.services.push_notifications import (
    apns_service,
    import_completed_notification,
    import_failed_notification,
)


class ImportJobProcessor:
    """Processes import jobs asynchronously with progress updates."""

    def __init__(self, user_id: str, job_id: str):
        self.user_id = user_id
        self.job_id = job_id
        self.progress = ImportJobProgress()
        self._last_update_time = 0.0
        self._update_interval = 2.0  # Update DB every 2 seconds max

    def _update_progress(self, force: bool = False) -> None:
        """Update job progress in database (throttled)."""
        now = time.time()
        if not force and (now - self._last_update_time) < self._update_interval:
            return

        self._last_update_time = now
        db_service.update_import_job(
            self.user_id,
            self.job_id,
            {
                "progress": self.progress.model_dump(),
                "updated_at": datetime.now(UTC).isoformat(),
            },
        )

    def _update_status(self, status: JobStatus) -> None:
        """Update job status in database."""
        db_service.update_import_job(
            self.user_id,
            self.job_id,
            {
                "status": status.value,
                "progress": self.progress.model_dump(),
                "updated_at": datetime.now(UTC).isoformat(),
            },
        )

    async def process(self) -> None:
        """Process the import job."""
        try:
            # Check Google connection
            connection_status = google_service.get_connection_status(self.user_id)
            if not connection_status["is_connected"]:
                await self._fail("Google account not connected")
                return

            # Get existing visited places to exclude
            existing_places = db_service.get_user_visited_places(
                self.user_id, region_type="country"
            )
            existing_countries = {place["region_code"] for place in existing_places}

            # Scan emails
            email_countries = await self._scan_emails()

            # Scan calendar
            calendar_countries = await self._scan_calendar()

            # Process results
            self._update_status(JobStatus.PROCESSING)
            self.progress.current_step = "aggregating_results"
            self._update_progress(force=True)

            # Merge and filter results
            candidates = self._build_candidates(
                email_countries, calendar_countries, existing_countries
            )

            # Store results
            results = {
                "candidates": [c.model_dump() for c in candidates],
                "scanned_emails": self.progress.emails_scanned,
                "scanned_events": self.progress.events_scanned,
            }
            db_service.store_import_results(self.user_id, self.job_id, results)

            # Mark as completed
            db_service.update_import_job(
                self.user_id,
                self.job_id,
                {
                    "status": JobStatus.COMPLETED.value,
                    "completed_at": datetime.now(UTC).isoformat(),
                    "candidates_count": len(candidates),
                    "scanned_emails": self.progress.emails_scanned,
                    "scanned_events": self.progress.events_scanned,
                    "progress": self.progress.model_dump(),
                },
            )

            # Send push notification
            country_names = [c.country_name for c in candidates]
            notification = import_completed_notification(len(candidates), country_names)
            await apns_service.send_to_user(self.user_id, notification)

        except Exception as e:
            await self._fail(str(e))

    async def _scan_emails(self) -> dict:
        """Scan Gmail for travel emails."""
        self._update_status(JobStatus.SCANNING_EMAILS)
        self.progress.current_step = "scanning_emails"
        self._update_progress(force=True)

        email_countries = {}
        try:
            gmail_service = google_service.get_gmail_service(self.user_id)

            def on_email_progress(scanned: int, total: int):
                self.progress.emails_scanned = scanned
                self.progress.emails_total = total
                self._update_progress()

            emails = await asyncio.to_thread(
                parse_emails_with_progress,
                gmail_service,
                max_emails=2000,
                progress_callback=on_email_progress,
            )

            self.progress.emails_scanned = len(emails)
            self._update_progress(force=True)

            email_countries = aggregate_email_countries(emails)

        except Exception as e:
            print(f"[Import] Email scan error: {e}")
            # Continue without emails

        return email_countries

    async def _scan_calendar(self) -> dict:
        """Scan Google Calendar for events with locations."""
        self._update_status(JobStatus.SCANNING_CALENDAR)
        self.progress.current_step = "scanning_calendar"
        self._update_progress(force=True)

        calendar_countries = {}
        try:
            calendar_service = google_service.get_calendar_service(self.user_id)

            def on_calendar_progress(year: int, scanned: int, total: int):
                self.progress.calendar_year = year
                self.progress.events_scanned = scanned
                self.progress.events_total = total
                self._update_progress()

            events = await asyncio.to_thread(
                parse_calendar_events_with_progress,
                calendar_service,
                max_events=5000,
                progress_callback=on_calendar_progress,
            )

            self.progress.events_scanned = len(events)
            self._update_progress(force=True)

            calendar_countries = aggregate_calendar_countries(events)

        except Exception as e:
            print(f"[Import] Calendar scan error: {e}")
            # Continue without calendar

        return calendar_countries

    def _build_candidates(
        self,
        email_countries: dict,
        calendar_countries: dict,
        existing_countries: set,
    ) -> list[ImportCandidate]:
        """Build import candidates from aggregated data."""
        all_countries = set(email_countries.keys()) | set(calendar_countries.keys())
        new_countries = all_countries - existing_countries

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

            # Combine samples
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

        # Sort by evidence
        candidates.sort(
            key=lambda c: c.email_count + c.calendar_event_count, reverse=True
        )

        return candidates

    async def _fail(self, error: str) -> None:
        """Mark job as failed."""
        db_service.update_import_job(
            self.user_id,
            self.job_id,
            {
                "status": JobStatus.FAILED.value,
                "error_message": error,
                "completed_at": datetime.now(UTC).isoformat(),
            },
        )

        # Send push notification
        notification = import_failed_notification(error)
        await apns_service.send_to_user(self.user_id, notification)


def aggregate_email_countries(emails: list) -> dict[str, dict]:
    """Aggregate countries from parsed emails."""
    countries = {}

    for email in emails:
        for country_code in email.countries:
            if country_code not in countries:
                countries[country_code] = {"count": 0, "samples": []}

            countries[country_code]["count"] += 1

            if len(countries[country_code]["samples"]) < 5:
                countries[country_code]["samples"].append(
                    {
                        "id": email.id,
                        "source_type": "email",
                        "title": email.subject[:100] if email.subject else "Email",
                        "date": email.date,
                        "snippet": email.snippet[:100] if email.snippet else None,
                    }
                )

    return countries


def aggregate_calendar_countries(events: list) -> dict[str, dict]:
    """Aggregate countries from parsed calendar events."""
    countries = {}

    for event in events:
        for country_code in event.countries:
            if country_code not in countries:
                countries[country_code] = {"count": 0, "samples": []}

            countries[country_code]["count"] += 1

            if len(countries[country_code]["samples"]) < 5:
                countries[country_code]["samples"].append(
                    {
                        "id": event.id,
                        "source_type": "calendar",
                        "title": event.summary[:100] if event.summary else "Event",
                        "date": event.start_date,
                        "snippet": event.location[:100] if event.location else None,
                    }
                )

    return countries


async def start_import_job(user_id: str) -> str:
    """Start a new async import job."""
    job_id = str(uuid.uuid4())

    # Create job record
    db_service.create_import_job(
        user_id,
        job_id,
        {
            "status": JobStatus.PENDING.value,
            "progress": ImportJobProgress().model_dump(),
        },
    )

    # Start processing in background
    processor = ImportJobProcessor(user_id, job_id)
    asyncio.create_task(processor.process())

    return job_id
