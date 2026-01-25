"""Country extraction service using NLP and geocoding."""

import re
from functools import lru_cache

import pycountry

# IATA airport codes to country codes mapping (major airports)
AIRPORT_CODES: dict[str, str] = {
    # United States
    "JFK": "US",
    "LAX": "US",
    "ORD": "US",
    "DFW": "US",
    "DEN": "US",
    "SFO": "US",
    "SEA": "US",
    "LAS": "US",
    "MCO": "US",
    "EWR": "US",
    "BOS": "US",
    "ATL": "US",
    "MIA": "US",
    "PHX": "US",
    "IAH": "US",
    # Europe
    "LHR": "GB",
    "LGW": "GB",
    "STN": "GB",
    "MAN": "GB",
    "EDI": "GB",
    "CDG": "FR",
    "ORY": "FR",
    "NCE": "FR",
    "LYS": "FR",
    "FRA": "DE",
    "MUC": "DE",
    "TXL": "DE",
    "BER": "DE",
    "DUS": "DE",
    "AMS": "NL",
    "BCN": "ES",
    "MAD": "ES",
    "FCO": "IT",
    "MXP": "IT",
    "VIE": "AT",
    "ZRH": "CH",
    "GVA": "CH",
    "CPH": "DK",
    "ARN": "SE",
    "OSL": "NO",
    "HEL": "FI",
    "DUB": "IE",
    "LIS": "PT",
    "ATH": "GR",
    "PRG": "CZ",
    "WAW": "PL",
    "BUD": "HU",
    "OTP": "RO",
    "SOF": "BG",
    # Asia
    "HND": "JP",
    "NRT": "JP",
    "KIX": "JP",
    "ICN": "KR",
    "GMP": "KR",
    "PEK": "CN",
    "PVG": "CN",
    "CAN": "CN",
    "HKG": "HK",
    "TPE": "TW",
    "SIN": "SG",
    "BKK": "TH",
    "KUL": "MY",
    "CGK": "ID",
    "MNL": "PH",
    "DEL": "IN",
    "BOM": "IN",
    "DXB": "AE",
    "DOH": "QA",
    "TLV": "IL",
    # Oceania
    "SYD": "AU",
    "MEL": "AU",
    "BNE": "AU",
    "PER": "AU",
    "AKL": "NZ",
    # Americas
    "YYZ": "CA",
    "YVR": "CA",
    "YUL": "CA",
    "YYC": "CA",
    "MEX": "MX",
    "CUN": "MX",
    "GRU": "BR",
    "GIG": "BR",
    "EZE": "AR",
    "SCL": "CL",
    "BOG": "CO",
    "LIM": "PE",
    # Africa
    "JNB": "ZA",
    "CPT": "ZA",
    "CAI": "EG",
    "CMN": "MA",
    "NBO": "KE",
}

# City to country mapping (major cities)
CITY_TO_COUNTRY: dict[str, str] = {
    "paris": "FR",
    "london": "GB",
    "new york": "US",
    "tokyo": "JP",
    "berlin": "DE",
    "rome": "IT",
    "madrid": "ES",
    "amsterdam": "NL",
    "barcelona": "ES",
    "vienna": "AT",
    "prague": "CZ",
    "budapest": "HU",
    "lisbon": "PT",
    "athens": "GR",
    "dublin": "IE",
    "copenhagen": "DK",
    "stockholm": "SE",
    "oslo": "NO",
    "helsinki": "FI",
    "zurich": "CH",
    "geneva": "CH",
    "brussels": "BE",
    "warsaw": "PL",
    "krakow": "PL",
    "singapore": "SG",
    "hong kong": "HK",
    "bangkok": "TH",
    "seoul": "KR",
    "beijing": "CN",
    "shanghai": "CN",
    "dubai": "AE",
    "tel aviv": "IL",
    "sydney": "AU",
    "melbourne": "AU",
    "auckland": "NZ",
    "toronto": "CA",
    "vancouver": "CA",
    "montreal": "CA",
    "mexico city": "MX",
    "cancun": "MX",
    "sao paulo": "BR",
    "rio de janeiro": "BR",
    "buenos aires": "AR",
    "cape town": "ZA",
    "johannesburg": "ZA",
    "cairo": "EG",
    "marrakech": "MA",
    "los angeles": "US",
    "san francisco": "US",
    "chicago": "US",
    "miami": "US",
    "las vegas": "US",
    "boston": "US",
    "seattle": "US",
    "washington": "US",
    "milan": "IT",
    "florence": "IT",
    "venice": "IT",
    "naples": "IT",
    "munich": "DE",
    "frankfurt": "DE",
    "hamburg": "DE",
    "cologne": "DE",
    "lyon": "FR",
    "marseille": "FR",
    "nice": "FR",
    "bordeaux": "FR",
    "edinburgh": "GB",
    "manchester": "GB",
    "liverpool": "GB",
    "glasgow": "GB",
    "kyoto": "JP",
    "osaka": "JP",
    "taipei": "TW",
    "kuala lumpur": "MY",
    "bali": "ID",
    "jakarta": "ID",
    "manila": "PH",
    "hanoi": "VN",
    "ho chi minh": "VN",
    "mumbai": "IN",
    "delhi": "IN",
    "bangalore": "IN",
    "istanbul": "TR",
    "doha": "QA",
    "abu dhabi": "AE",
    "riyadh": "SA",
    "nairobi": "KE",
    "lagos": "NG",
    "casablanca": "MA",
    "tunis": "TN",
}


@lru_cache(maxsize=500)
def get_country_name(country_code: str) -> str | None:
    """Get country name from ISO 3166-1 alpha-2 code."""
    try:
        country = pycountry.countries.get(alpha_2=country_code.upper())
        return country.name if country else None
    except (KeyError, AttributeError):
        return None


@lru_cache(maxsize=500)
def normalize_country_name(name: str) -> str | None:
    """Normalize country name to ISO 3166-1 alpha-2 code."""
    name_lower = name.lower().strip()

    # Handle common variations FIRST (before fuzzy search which can misfire)
    variations = {
        "usa": "US",
        "u.s.a.": "US",
        "united states of america": "US",
        "uk": "GB",
        "u.k.": "GB",
        "great britain": "GB",
        "england": "GB",
        "scotland": "GB",
        "wales": "GB",
        "northern ireland": "GB",
        "holland": "NL",
        "the netherlands": "NL",
        "uae": "AE",
        "u.a.e.": "AE",
        "korea": "KR",
        "south korea": "KR",
        "czech republic": "CZ",
        "czechia": "CZ",
        "russia": "RU",
        "russian federation": "RU",
    }

    if name_lower in variations:
        return variations[name_lower]

    # Direct lookup
    try:
        country = pycountry.countries.get(name=name)
        if country:
            return country.alpha_2
    except (KeyError, LookupError):
        pass

    # Try fuzzy search
    try:
        country = pycountry.countries.search_fuzzy(name)[0]
        return country.alpha_2
    except (LookupError, IndexError):
        pass

    return None


def extract_airport_codes(text: str) -> set[str]:
    """Extract IATA airport codes from text and return country codes."""
    countries = set()
    # Match 3-letter uppercase codes that are known airports
    pattern = r"\b([A-Z]{3})\b"
    for match in re.finditer(pattern, text.upper()):
        code = match.group(1)
        if code in AIRPORT_CODES:
            countries.add(AIRPORT_CODES[code])
    return countries


def extract_cities(text: str) -> set[str]:
    """Extract city names from text and return country codes."""
    countries = set()
    text_lower = text.lower()

    for city, country_code in CITY_TO_COUNTRY.items():
        # Use word boundaries to avoid partial matches
        if re.search(rf"\b{re.escape(city)}\b", text_lower):
            countries.add(country_code)

    return countries


def extract_country_names(text: str) -> set[str]:
    """Extract country names directly mentioned in text."""
    countries = set()

    # Get all country names for matching
    for country in pycountry.countries:
        name_lower = country.name.lower()
        if re.search(rf"\b{re.escape(name_lower)}\b", text.lower()):
            countries.add(country.alpha_2)

    # Also check common names
    common_names = {
        "united states": "US",
        "america": "US",
        "united kingdom": "GB",
        "britain": "GB",
        "netherlands": "NL",
        "holland": "NL",
        "czech republic": "CZ",
    }

    for name, code in common_names.items():
        if re.search(rf"\b{re.escape(name)}\b", text.lower()):
            countries.add(code)

    return countries


def extract_countries_from_text(text: str) -> set[str]:
    """
    Extract all possible country codes from text using multiple methods.

    Returns a set of ISO 3166-1 alpha-2 country codes.
    """
    if not text:
        return set()

    countries = set()

    # Method 1: Airport codes
    countries.update(extract_airport_codes(text))

    # Method 2: City names
    countries.update(extract_cities(text))

    # Method 3: Country names
    countries.update(extract_country_names(text))

    return countries


def get_confidence_score(
    email_count: int, calendar_count: int, has_flight: bool = False
) -> float:
    """
    Calculate confidence score for a country detection.

    Higher scores indicate more confident detections.
    """
    total = email_count + calendar_count
    base_score = min(0.5 + (total * 0.05), 0.9)

    if has_flight:
        base_score = min(base_score + 0.1, 0.99)

    return round(base_score, 2)


# Singleton pattern for spaCy model (lazy load)
_nlp_model = None


def get_nlp_model():
    """Get or initialize the spaCy NLP model."""
    global _nlp_model
    if _nlp_model is None:
        try:
            import spacy

            _nlp_model = spacy.load("en_core_web_sm")
        except OSError:
            # Model not installed, use basic extraction only
            _nlp_model = False
    return _nlp_model


def extract_locations_with_nlp(text: str) -> set[str]:
    """
    Use spaCy NLP to extract location entities and convert to country codes.

    This is more accurate but slower than rule-based extraction.
    """
    countries = set()
    nlp = get_nlp_model()

    if nlp is False:
        # spaCy not available, fall back to basic extraction
        return countries

    doc = nlp(text)

    for ent in doc.ents:
        if ent.label_ in ("GPE", "LOC"):  # Geopolitical entity or Location
            # Try to normalize the entity to a country code
            code = normalize_country_name(ent.text)
            if code:
                countries.add(code)
            else:
                # Check if it's a known city
                city_code = CITY_TO_COUNTRY.get(ent.text.lower())
                if city_code:
                    countries.add(city_code)

    return countries


def extract_countries_comprehensive(text: str, use_nlp: bool = True) -> set[str]:
    """
    Comprehensive country extraction using all available methods.

    Args:
        text: The text to extract countries from
        use_nlp: Whether to use NLP-based extraction (slower but more accurate)

    Returns:
        Set of ISO 3166-1 alpha-2 country codes
    """
    countries = set()

    # Basic rule-based extraction (fast)
    countries.update(extract_countries_from_text(text))

    # NLP-based extraction (slow but catches more)
    if use_nlp:
        countries.update(extract_locations_with_nlp(text))

    return countries
