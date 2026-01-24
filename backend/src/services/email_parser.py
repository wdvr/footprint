"""Email parsing service for extracting travel information from Gmail."""

import re
from dataclasses import dataclass
from datetime import datetime

from src.services.country_extractor import extract_countries_comprehensive


@dataclass
class EmailResult:
    """Parsed email with extracted travel information."""

    id: str
    subject: str
    sender: str
    date: str | None
    snippet: str
    countries: set[str]
    is_travel_related: bool


# Gmail search queries for travel-related emails
TRAVEL_QUERIES = [
    # Flight bookings
    'subject:(flight OR "boarding pass" OR itinerary OR "flight confirmation")',
    "from:(airline OR airways OR airlines)",
    'subject:("e-ticket" OR eticket)',
    # Hotel bookings
    "subject:(reservation OR booking OR confirmation) from:(hotel OR booking.com OR airbnb OR vrbo OR expedia)",
    'subject:("hotel confirmation" OR "reservation confirmed")',
    # Train tickets
    "subject:(train OR railway) (ticket OR booking OR confirmation)",
    "from:(eurostar OR thalys OR sncf OR db OR trenitalia OR amtrak OR renfe)",
    # Car rentals
    'subject:("car rental" OR "rental car") (confirmation OR booking)',
    "from:(hertz OR avis OR enterprise OR sixt OR europcar OR budget)",
    # Travel itineraries
    "from:(tripit OR kayak OR google) subject:(itinerary OR trip)",
    # General travel
    "subject:(travel OR trip) confirmation",
]


def search_travel_emails(gmail_service, max_results: int = 500) -> list[dict]:
    """
    Search Gmail for travel-related emails.

    Returns list of message metadata.
    """
    all_messages = []
    seen_ids = set()

    for query in TRAVEL_QUERIES:
        try:
            results = (
                gmail_service.users()
                .messages()
                .list(
                    userId="me",
                    q=query,
                    maxResults=min(100, max_results - len(all_messages)),
                )
                .execute()
            )

            messages = results.get("messages", [])
            for msg in messages:
                if msg["id"] not in seen_ids:
                    seen_ids.add(msg["id"])
                    all_messages.append(msg)

            if len(all_messages) >= max_results:
                break

        except Exception:
            # Continue with other queries if one fails
            continue

    return all_messages[:max_results]


def get_email_details(gmail_service, message_id: str) -> dict | None:
    """Get full email details including headers and snippet."""
    try:
        message = (
            gmail_service.users()
            .messages()
            .get(userId="me", id=message_id, format="metadata")
            .execute()
        )
        return message
    except Exception:
        return None


def parse_email_headers(headers: list[dict]) -> dict:
    """Extract useful headers from email."""
    result = {}
    for header in headers:
        name = header.get("name", "").lower()
        value = header.get("value", "")

        if name == "subject":
            result["subject"] = value
        elif name == "from":
            result["from"] = value
        elif name == "date":
            result["date"] = value

    return result


def extract_date(date_str: str) -> str | None:
    """Parse email date string to ISO format."""
    if not date_str:
        return None

    # Common email date formats
    formats = [
        "%a, %d %b %Y %H:%M:%S %z",
        "%d %b %Y %H:%M:%S %z",
        "%a, %d %b %Y %H:%M:%S",
        "%d %b %Y %H:%M:%S",
    ]

    # Clean up the date string
    date_str = re.sub(r"\s*\([^)]*\)", "", date_str).strip()

    for fmt in formats:
        try:
            dt = datetime.strptime(date_str, fmt)
            return dt.isoformat()
        except ValueError:
            continue

    return None


def is_travel_email(subject: str, sender: str) -> bool:
    """
    Determine if an email is likely travel-related based on subject and sender.
    """
    subject_lower = subject.lower()
    sender_lower = sender.lower()

    # Travel keywords in subject
    travel_keywords = [
        "flight",
        "booking",
        "reservation",
        "confirmation",
        "itinerary",
        "boarding pass",
        "e-ticket",
        "hotel",
        "train",
        "car rental",
        "trip",
        "travel",
        "check-in",
        "checkout",
    ]

    # Travel-related senders
    travel_senders = [
        "airline",
        "airways",
        "booking.com",
        "airbnb",
        "vrbo",
        "expedia",
        "hotels.com",
        "tripadvisor",
        "kayak",
        "tripit",
        "eurostar",
        "hertz",
        "avis",
        "enterprise",
        "sixt",
    ]

    for keyword in travel_keywords:
        if keyword in subject_lower:
            return True

    for sender_keyword in travel_senders:
        if sender_keyword in sender_lower:
            return True

    return False


def parse_emails(gmail_service, max_emails: int = 500) -> list[EmailResult]:
    """
    Search and parse travel-related emails.

    Returns list of EmailResult with extracted country information.
    """
    return parse_emails_with_progress(gmail_service, max_emails, None)


def parse_emails_with_progress(
    gmail_service,
    max_emails: int = 500,
    progress_callback: callable = None,
) -> list[EmailResult]:
    """
    Search and parse travel-related emails with progress updates.

    Args:
        gmail_service: Gmail API service
        max_emails: Maximum emails to process
        progress_callback: Optional callback(scanned, total) for progress updates

    Returns list of EmailResult with extracted country information.
    """
    results = []

    # Search for travel emails
    messages = search_travel_emails(gmail_service, max_emails)
    total = len(messages)

    for i, msg in enumerate(messages):
        if progress_callback:
            progress_callback(i + 1, total)

        details = get_email_details(gmail_service, msg["id"])
        if not details:
            continue

        headers = parse_email_headers(details.get("payload", {}).get("headers", []))
        snippet = details.get("snippet", "")

        subject = headers.get("subject", "")
        sender = headers.get("from", "")
        date_str = headers.get("date", "")

        # Check if it's a travel email
        if not is_travel_email(subject, sender):
            continue

        # Extract countries from subject and snippet
        text = f"{subject} {snippet} {sender}"
        countries = extract_countries_comprehensive(text, use_nlp=False)

        if countries:
            results.append(
                EmailResult(
                    id=msg["id"],
                    subject=subject,
                    sender=sender,
                    date=extract_date(date_str),
                    snippet=snippet[:200] if snippet else "",
                    countries=countries,
                    is_travel_related=True,
                )
            )

    return results


def aggregate_email_countries(
    emails: list[EmailResult],
) -> dict[str, dict]:
    """
    Aggregate countries from parsed emails.

    Returns dict mapping country code to aggregated data.
    """
    countries = {}

    for email in emails:
        for country_code in email.countries:
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
                        "id": email.id,
                        "source_type": "email",
                        "title": email.subject[:100] if email.subject else "Email",
                        "date": email.date,
                        "snippet": email.snippet[:100] if email.snippet else None,
                    }
                )

    return countries
