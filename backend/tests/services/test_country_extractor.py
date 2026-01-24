"""Tests for country extraction service."""

from src.services.country_extractor import (
    extract_airport_codes,
    extract_cities,
    extract_countries_comprehensive,
    extract_countries_from_text,
    extract_country_names,
    get_confidence_score,
    get_country_name,
    normalize_country_name,
)


class TestGetCountryName:
    """Tests for get_country_name function."""

    def test_valid_country_code(self):
        assert get_country_name("US") == "United States"
        assert get_country_name("FR") == "France"
        assert get_country_name("GB") == "United Kingdom"
        assert get_country_name("JP") == "Japan"

    def test_lowercase_country_code(self):
        assert get_country_name("us") == "United States"
        assert get_country_name("fr") == "France"

    def test_invalid_country_code(self):
        assert get_country_name("XX") is None
        assert get_country_name("ZZ") is None
        assert get_country_name("") is None


class TestNormalizeCountryName:
    """Tests for normalize_country_name function."""

    def test_standard_country_names(self):
        assert normalize_country_name("France") == "FR"
        assert normalize_country_name("Germany") == "DE"
        assert normalize_country_name("Japan") == "JP"

    def test_common_variations(self):
        assert normalize_country_name("USA") == "US"
        assert normalize_country_name("UK") == "GB"
        assert normalize_country_name("Holland") == "NL"
        assert normalize_country_name("South Korea") == "KR"

    def test_case_insensitive(self):
        assert normalize_country_name("FRANCE") == "FR"
        assert normalize_country_name("france") == "FR"
        assert normalize_country_name("FrAnCe") == "FR"

    def test_invalid_country_name(self):
        assert normalize_country_name("Narnia") is None
        assert normalize_country_name("Gondor") is None


class TestExtractAirportCodes:
    """Tests for extract_airport_codes function."""

    def test_single_airport(self):
        countries = extract_airport_codes("Flight to JFK confirmed")
        assert "US" in countries

    def test_multiple_airports(self):
        countries = extract_airport_codes("Flying from JFK to CDG")
        assert "US" in countries
        assert "FR" in countries

    def test_european_airports(self):
        countries = extract_airport_codes("LHR to FRA connection")
        assert "GB" in countries
        assert "DE" in countries

    def test_no_airports(self):
        countries = extract_airport_codes("No airport codes here")
        assert len(countries) == 0

    def test_unknown_three_letter_codes(self):
        countries = extract_airport_codes("ABC XYZ not airports")
        assert len(countries) == 0


class TestExtractCities:
    """Tests for extract_cities function."""

    def test_single_city(self):
        countries = extract_cities("Meeting in Paris next week")
        assert "FR" in countries

    def test_multiple_cities(self):
        countries = extract_cities("Trip from London to Tokyo")
        assert "GB" in countries
        assert "JP" in countries

    def test_us_cities(self):
        countries = extract_cities("Flying to Los Angeles and New York")
        assert "US" in countries

    def test_case_insensitive(self):
        countries = extract_cities("Visit BERLIN and MUNICH")
        assert "DE" in countries

    def test_no_cities(self):
        countries = extract_cities("Random text without cities")
        assert len(countries) == 0


class TestExtractCountryNames:
    """Tests for extract_country_names function."""

    def test_single_country(self):
        countries = extract_country_names("Traveling to France this summer")
        assert "FR" in countries

    def test_multiple_countries(self):
        countries = extract_country_names("Tour of Germany, Italy, and Spain")
        assert "DE" in countries
        assert "IT" in countries
        assert "ES" in countries

    def test_common_names(self):
        countries = extract_country_names("Trip to United States and United Kingdom")
        assert "US" in countries
        assert "GB" in countries

    def test_no_countries(self):
        countries = extract_country_names("Just a regular email")
        assert len(countries) == 0


class TestExtractCountriesFromText:
    """Tests for extract_countries_from_text function."""

    def test_combined_extraction(self):
        text = "Flight from JFK to Paris, France confirmed"
        countries = extract_countries_from_text(text)
        assert "US" in countries  # JFK
        assert "FR" in countries  # Paris and France

    def test_flight_booking_email(self):
        text = """
        Your Air France booking is confirmed.
        Flight AF123 from CDG to NRT
        Paris to Tokyo
        """
        countries = extract_countries_from_text(text)
        assert "FR" in countries  # CDG, Paris
        assert "JP" in countries  # NRT, Tokyo

    def test_hotel_booking(self):
        text = "Your reservation at Grand Hotel Berlin, Germany"
        countries = extract_countries_from_text(text)
        assert "DE" in countries

    def test_empty_text(self):
        countries = extract_countries_from_text("")
        assert len(countries) == 0


class TestExtractCountriesComprehensive:
    """Tests for extract_countries_comprehensive function."""

    def test_comprehensive_extraction(self):
        text = "Flying from SFO to London Heathrow (LHR), United Kingdom"
        # Without NLP (faster)
        countries = extract_countries_comprehensive(text, use_nlp=False)
        assert "US" in countries  # SFO
        assert "GB" in countries  # LHR, London, United Kingdom

    def test_travel_itinerary(self):
        text = """
        Day 1: Arrive in Amsterdam, Netherlands
        Day 3: Train to Paris, France
        Day 5: Fly to Barcelona, Spain
        """
        countries = extract_countries_comprehensive(text, use_nlp=False)
        assert "NL" in countries
        assert "FR" in countries
        assert "ES" in countries


class TestGetConfidenceScore:
    """Tests for get_confidence_score function."""

    def test_low_evidence(self):
        score = get_confidence_score(email_count=1, calendar_count=0)
        assert 0.5 <= score <= 0.6

    def test_medium_evidence(self):
        score = get_confidence_score(email_count=5, calendar_count=2)
        assert 0.7 <= score <= 0.9

    def test_high_evidence(self):
        score = get_confidence_score(email_count=10, calendar_count=5)
        assert score >= 0.9

    def test_flight_boost(self):
        score_no_flight = get_confidence_score(email_count=3, calendar_count=1)
        score_with_flight = get_confidence_score(
            email_count=3, calendar_count=1, has_flight=True
        )
        assert score_with_flight > score_no_flight

    def test_max_confidence(self):
        score = get_confidence_score(
            email_count=100, calendar_count=50, has_flight=True
        )
        assert score <= 0.99


class TestIntegration:
    """Integration tests for country extraction."""

    def test_airline_confirmation_email(self):
        text = """
        Subject: Your British Airways booking confirmation

        Dear Customer,

        Thank you for booking with British Airways.

        Flight Details:
        BA 178 - London Heathrow (LHR) to New York JFK (JFK)
        Date: March 15, 2024

        Return Flight:
        BA 179 - New York JFK (JFK) to London Heathrow (LHR)
        Date: March 22, 2024
        """
        countries = extract_countries_comprehensive(text, use_nlp=False)
        assert "GB" in countries  # British Airways, London, LHR
        assert "US" in countries  # New York, JFK

    def test_hotel_booking_confirmation(self):
        text = """
        Subject: Booking Confirmation - Hotel Ritz Paris

        Your reservation at Hotel Ritz Paris is confirmed.

        Check-in: April 10, 2024
        Check-out: April 13, 2024

        Address: 15 Place Vendôme, 75001 Paris, France
        """
        countries = extract_countries_comprehensive(text, use_nlp=False)
        assert "FR" in countries  # Paris, France

    def test_train_booking(self):
        text = """
        Eurostar Booking Confirmation

        London St Pancras to Paris Gare du Nord
        Train: EST 9014
        Date: May 1, 2024
        """
        countries = extract_countries_comprehensive(text, use_nlp=False)
        assert "GB" in countries  # London
        assert "FR" in countries  # Paris
