"""Calendar parsing service for extracting travel information from Google Calendar."""

from dataclasses import dataclass
from datetime import datetime, timedelta

from src.services.country_extractor import extract_countries_comprehensive


@dataclass
class CalendarEventResult:
    """Parsed calendar event with extracted travel information."""

    id: str
    title: str
    location: str | None
    start_date: str | None
    end_date: str | None
    countries: set[str]


def get_calendar_events(
    calendar_service,
    years_back: int = 10,
    max_events: int = 1000,
) -> list[dict]:
    """
    Get calendar events from the past N years.

    Returns list of event data.
    """
    all_events = []

    # Calculate time range
    now = datetime.utcnow()
    time_min = (now - timedelta(days=365 * years_back)).isoformat() + "Z"
    time_max = now.isoformat() + "Z"

    try:
        # Get list of calendars
        calendar_list = calendar_service.calendarList().list().execute()
        calendars = calendar_list.get("items", [])

        for calendar in calendars:
            calendar_id = calendar.get("id")
            if not calendar_id:
                continue

            try:
                page_token = None
                while True:
                    events_result = (
                        calendar_service.events()
                        .list(
                            calendarId=calendar_id,
                            timeMin=time_min,
                            timeMax=time_max,
                            maxResults=min(250, max_events - len(all_events)),
                            singleEvents=True,
                            orderBy="startTime",
                            pageToken=page_token,
                        )
                        .execute()
                    )

                    events = events_result.get("items", [])
                    all_events.extend(events)

                    if len(all_events) >= max_events:
                        break

                    page_token = events_result.get("nextPageToken")
                    if not page_token:
                        break

            except Exception:
                # Skip calendars that fail
                continue

            if len(all_events) >= max_events:
                break

    except Exception:
        pass

    return all_events[:max_events]


def is_travel_event(event: dict) -> bool:
    """
    Determine if a calendar event is likely travel-related.

    Travel events typically have:
    - A location field set
    - Keywords in title like "flight", "hotel", "trip"
    - Multi-day duration (vacations)
    """
    title = event.get("summary", "").lower()
    location = event.get("location", "")

    # Travel keywords in title
    travel_keywords = [
        "flight",
        "fly",
        "airport",
        "travel",
        "trip",
        "vacation",
        "holiday",
        "hotel",
        "booking",
        "train",
        "bus",
        "tour",
        "visit",
        "conference",
        "meeting",  # Business travel
    ]

    # Check for travel keywords in title
    for keyword in travel_keywords:
        if keyword in title:
            return True

    # Events with location set might be travel
    if location and len(location) > 5:
        # Check if location contains country/city indicators
        location_lower = location.lower()
        # Skip common local location patterns
        local_patterns = ["room", "office", "building", "floor", "conference"]
        if not any(pattern in location_lower for pattern in local_patterns):
            return True

    # Check for multi-day events (likely vacations)
    start = event.get("start", {})
    end = event.get("end", {})

    # All-day events spanning multiple days are often travel
    if "date" in start and "date" in end:
        try:
            start_date = datetime.fromisoformat(start["date"])
            end_date = datetime.fromisoformat(end["date"])
            if (end_date - start_date).days >= 2:
                return True
        except (ValueError, TypeError):
            pass

    return False


def extract_event_dates(event: dict) -> tuple[str | None, str | None]:
    """Extract start and end dates from calendar event."""
    start = event.get("start", {})
    end = event.get("end", {})

    start_date = start.get("dateTime") or start.get("date")
    end_date = end.get("dateTime") or end.get("date")

    return start_date, end_date


def parse_calendar_events(
    calendar_service,
    max_events: int = 1000,
) -> list[CalendarEventResult]:
    """
    Get and parse calendar events for travel information.

    Returns list of CalendarEventResult with extracted country information.
    """
    return parse_calendar_events_with_progress(calendar_service, max_events, None)


def parse_calendar_events_with_progress(
    calendar_service,
    max_events: int = 1000,
    progress_callback: callable = None,
) -> list[CalendarEventResult]:
    """
    Get and parse calendar events with progress updates.

    Args:
        calendar_service: Google Calendar API service
        max_events: Maximum events to process
        progress_callback: Optional callback(year, scanned, total) for progress

    Returns list of CalendarEventResult with extracted country information.
    """
    results = []

    events = get_calendar_events(calendar_service, max_events=max_events)
    total = len(events)

    for i, event in enumerate(events):
        # Extract year from event for progress
        if progress_callback:
            start = event.get("start", {})
            date_str = start.get("dateTime") or start.get("date") or ""
            try:
                year = int(date_str[:4]) if len(date_str) >= 4 else None
            except (ValueError, TypeError):
                year = None
            progress_callback(year, i + 1, total)

        # Only process travel-related events
        if not is_travel_event(event):
            continue

        title = event.get("summary", "")
        location = event.get("location", "")
        description = event.get("description", "")

        # Combine text fields for country extraction
        text = f"{title} {location} {description}"
        countries = extract_countries_comprehensive(text, use_nlp=False)

        # Also try to extract from location specifically
        if location:
            location_countries = extract_countries_comprehensive(
                location, use_nlp=False
            )
            countries.update(location_countries)

        if countries:
            start_date, end_date = extract_event_dates(event)

            results.append(
                CalendarEventResult(
                    id=event.get("id", ""),
                    title=title,
                    location=location,
                    start_date=start_date,
                    end_date=end_date,
                    countries=countries,
                )
            )

    return results


def aggregate_calendar_countries(
    events: list[CalendarEventResult],
) -> dict[str, dict]:
    """
    Aggregate countries from parsed calendar events.

    Returns dict mapping country code to aggregated data.
    """
    countries = {}

    for event in events:
        for country_code in event.countries:
            if country_code not in countries:
                countries[country_code] = {
                    "count": 0,
                    "samples": [],
                }

            countries[country_code]["count"] += 1

            # Keep up to 5 sample sources per country
            if len(countries[country_code]["samples"]) < 5:
                countries[country_code]["samples"].append(
                    {
                        "id": event.id,
                        "source_type": "calendar",
                        "title": event.title[:100] if event.title else "Event",
                        "date": event.start_date,
                        "snippet": event.location[:100] if event.location else None,
                    }
                )

    return countries
