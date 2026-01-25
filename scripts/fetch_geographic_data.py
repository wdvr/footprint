#!/usr/bin/env python3
"""
Fetch geographic data from open sources for Footprint travel tracker.

Data sources:
- States/Provinces: dr5hn/countries-states-cities-database (GitHub)
  - License: ODbL 1.0 (Open Database License)
  - 5,299 states across 250 countries

- Cities: dr5hn/countries-states-cities-database (GitHub)
  - License: ODbL 1.0
  - 153,765 cities worldwide

- ISO 3166-2 data: iso3166-2 API
  - Free REST API for subdivision codes

Usage:
    python scripts/fetch_geographic_data.py --states
    python scripts/fetch_geographic_data.py --cities
    python scripts/fetch_geographic_data.py --all
"""

import argparse
import json
import sys
import urllib.request
from pathlib import Path

# Base URLs for data sources
DR5HN_BASE = "https://raw.githubusercontent.com/dr5hn/countries-states-cities-database/master"
ISO3166_API = "https://iso3166-2-api.vercel.app/api"

# Output directories
SCRIPT_DIR = Path(__file__).parent
PROJECT_ROOT = SCRIPT_DIR.parent
DATA_OUTPUT_DIR = PROJECT_ROOT / "data" / "geographic"
IOS_RESOURCES_DIR = PROJECT_ROOT / "ios" / "Footprint" / "Resources" / "GeoData"


def fetch_json(url: str) -> dict | list:
    """Fetch JSON from URL."""
    print(f"  Fetching: {url}")
    req = urllib.request.Request(
        url,
        headers={"User-Agent": "Footprint-Travel-Tracker/1.0"}
    )
    with urllib.request.urlopen(req, timeout=60) as response:
        return json.loads(response.read().decode("utf-8"))


def fetch_states_provinces():
    """
    Fetch states/provinces data for all countries.

    Source: dr5hn/countries-states-cities-database
    """
    print("\n=== Fetching States/Provinces Data ===")

    # Fetch the combined states file
    url = f"{DR5HN_BASE}/json/states.json"
    states_data = fetch_json(url)

    print(f"  Downloaded {len(states_data)} total states/provinces")

    # Group by country
    states_by_country = {}
    for state in states_data:
        country_code = state.get("country_code", "")
        if country_code not in states_by_country:
            states_by_country[country_code] = []

        states_by_country[country_code].append({
            "id": state.get("id"),
            "name": state.get("name"),
            "code": state.get("state_code"),
            "country_code": country_code,
            "country_name": state.get("country_name", ""),
            "latitude": state.get("latitude"),
            "longitude": state.get("longitude"),
            "type": state.get("type", "state"),
        })

    # Create output structure
    output = {
        "source": "dr5hn/countries-states-cities-database",
        "license": "ODbL 1.0 (Open Database License)",
        "total_states": len(states_data),
        "countries_with_states": len(states_by_country),
        "states_by_country": states_by_country,
    }

    # Ensure output directory exists
    DATA_OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

    # Write full data
    output_path = DATA_OUTPUT_DIR / "states_provinces.json"
    with open(output_path, "w", encoding="utf-8") as f:
        json.dump(output, f, indent=2, ensure_ascii=False)
    print(f"  Saved to: {output_path}")

    # Print summary
    print(f"\n  Summary:")
    print(f"    Total states/provinces: {len(states_data)}")
    print(f"    Countries with subdivisions: {len(states_by_country)}")

    # Top countries by state count
    top_countries = sorted(
        states_by_country.items(),
        key=lambda x: len(x[1]),
        reverse=True
    )[:10]
    print(f"\n  Top 10 countries by subdivision count:")
    for country_code, states in top_countries:
        country_name = states[0].get("country_name", country_code) if states else country_code
        print(f"    {country_code} ({country_name}): {len(states)}")

    return output


def fetch_cities(min_population: int = 50000):
    """
    Fetch cities data for all countries.

    Args:
        min_population: Minimum population to include (default 50,000)
                       Set to 0 for all cities (153k+)

    Source: dr5hn/countries-states-cities-database
    """
    print("\n=== Fetching Cities Data ===")

    # Fetch the full combined file (countries + states + cities)
    # This is ~47MB but has all the hierarchy properly linked
    url = f"{DR5HN_BASE}/json/countries+states+cities.json"
    print("  Fetching countries+states+cities.json (large file, please wait)...")
    countries_data = fetch_json(url)

    # Extract cities from the nested structure
    cities_data = []
    for country in countries_data:
        country_code = country.get("iso2", "")
        country_name = country.get("name", "")
        for state in country.get("states", []):
            state_code = state.get("state_code", "")
            state_name = state.get("name", "")
            for city in state.get("cities", []):
                cities_data.append({
                    "id": city.get("id"),
                    "name": city.get("name"),
                    "state_code": state_code,
                    "state_name": state_name,
                    "country_code": country_code,
                    "country_name": country_name,
                    "latitude": city.get("latitude"),
                    "longitude": city.get("longitude"),
                })

    print(f"  Downloaded {len(cities_data):,} total cities")

    # Group by country
    cities_by_country = {}
    for city in cities_data:
        country_code = city["country_code"]
        if country_code not in cities_by_country:
            cities_by_country[country_code] = []
        cities_by_country[country_code].append(city)

    # Create output structure
    output = {
        "source": "dr5hn/countries-states-cities-database",
        "license": "ODbL 1.0 (Open Database License)",
        "total_cities": len(cities_data),
        "countries_with_cities": len(cities_by_country),
        "cities_by_country": cities_by_country,
    }

    # Ensure output directory exists
    DATA_OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

    # Write full data
    output_path = DATA_OUTPUT_DIR / "cities.json"
    with open(output_path, "w", encoding="utf-8") as f:
        json.dump(output, f, indent=2, ensure_ascii=False)
    print(f"  Saved to: {output_path}")

    # Print summary
    print(f"\n  Summary:")
    print(f"    Total cities: {len(cities_data):,}")
    print(f"    Countries with cities: {len(cities_by_country)}")

    # Top countries by city count
    top_countries = sorted(
        cities_by_country.items(),
        key=lambda x: len(x[1]),
        reverse=True
    )[:10]
    print(f"\n  Top 10 countries by city count:")
    for country_code, cities in top_countries:
        country_name = cities[0].get("country_name", country_code) if cities else country_code
        print(f"    {country_code} ({country_name}): {len(cities):,}")

    return output


def fetch_countries_metadata():
    """
    Fetch country metadata with additional info.

    Source: dr5hn/countries-states-cities-database
    """
    print("\n=== Fetching Countries Metadata ===")

    url = f"{DR5HN_BASE}/json/countries.json"
    countries_data = fetch_json(url)

    print(f"  Downloaded {len(countries_data)} countries")

    # Process and structure
    countries = {}
    for country in countries_data:
        iso2 = country.get("iso2", "")
        countries[iso2] = {
            "id": country.get("id"),
            "name": country.get("name"),
            "iso2": iso2,
            "iso3": country.get("iso3"),
            "numeric_code": country.get("numeric_code"),
            "capital": country.get("capital"),
            "currency": country.get("currency"),
            "currency_symbol": country.get("currency_symbol"),
            "region": country.get("region"),
            "subregion": country.get("subregion"),
            "latitude": country.get("latitude"),
            "longitude": country.get("longitude"),
            "emoji": country.get("emoji"),
            "timezones": country.get("timezones", []),
        }

    output = {
        "source": "dr5hn/countries-states-cities-database",
        "license": "ODbL 1.0 (Open Database License)",
        "total_countries": len(countries),
        "countries": countries,
    }

    DATA_OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    output_path = DATA_OUTPUT_DIR / "countries_metadata.json"
    with open(output_path, "w", encoding="utf-8") as f:
        json.dump(output, f, indent=2, ensure_ascii=False)
    print(f"  Saved to: {output_path}")

    return output


def create_ios_states_json(states_data: dict):
    """
    Create a compact JSON file for iOS app consumption.

    This creates a lighter-weight file for the iOS app bundle.
    """
    print("\n=== Creating iOS States JSON ===")

    ios_states = {}
    for country_code, states in states_data.get("states_by_country", {}).items():
        if len(states) > 0 and country_code:
            state_list = []
            for s in states:
                # Use code if available, otherwise generate from id
                code = s.get("code") or f"S{s.get('id', '')}"
                if s.get("name") and s.get("latitude") and s.get("longitude"):
                    state_list.append({
                        "code": code,
                        "name": s["name"],
                        "lat": s["latitude"],
                        "lng": s["longitude"],
                    })
            if state_list:
                ios_states[country_code] = state_list

    IOS_RESOURCES_DIR.mkdir(parents=True, exist_ok=True)
    output_path = IOS_RESOURCES_DIR / "world_states.json"
    with open(output_path, "w", encoding="utf-8") as f:
        json.dump(ios_states, f, ensure_ascii=False)

    # Calculate size
    size_kb = output_path.stat().st_size / 1024
    print(f"  Saved to: {output_path} ({size_kb:.1f} KB)")
    print(f"  Countries included: {len(ios_states)}")
    total_states = sum(len(v) for v in ios_states.values())
    print(f"  Total states: {total_states}")


def create_ios_cities_json(cities_data: dict, max_per_country: int = 100):
    """
    Create a compact JSON file with top cities for iOS app.

    Args:
        max_per_country: Maximum cities to include per country
    """
    print(f"\n=== Creating iOS Cities JSON (max {max_per_country}/country) ===")

    ios_cities = {}
    for country_code, cities in cities_data.get("cities_by_country", {}).items():
        # Take up to max_per_country cities (dataset is already reasonably ordered)
        top_cities = cities[:max_per_country]
        ios_cities[country_code] = [
            {
                "name": c["name"],
                "state": c.get("state_code", ""),
                "lat": c["latitude"],
                "lng": c["longitude"],
            }
            for c in top_cities
        ]

    IOS_RESOURCES_DIR.mkdir(parents=True, exist_ok=True)
    output_path = IOS_RESOURCES_DIR / "world_cities.json"
    with open(output_path, "w", encoding="utf-8") as f:
        json.dump(ios_cities, f, ensure_ascii=False)

    size_kb = output_path.stat().st_size / 1024
    print(f"  Saved to: {output_path} ({size_kb:.1f} KB)")
    print(f"  Countries included: {len(ios_cities)}")
    total_cities = sum(len(v) for v in ios_cities.values())
    print(f"  Total cities: {total_cities}")


def main():
    parser = argparse.ArgumentParser(
        description="Fetch geographic data from open sources"
    )
    parser.add_argument(
        "--states", action="store_true",
        help="Fetch states/provinces data"
    )
    parser.add_argument(
        "--cities", action="store_true",
        help="Fetch cities data"
    )
    parser.add_argument(
        "--countries", action="store_true",
        help="Fetch countries metadata"
    )
    parser.add_argument(
        "--all", action="store_true",
        help="Fetch all data types"
    )
    parser.add_argument(
        "--ios", action="store_true",
        help="Also create iOS-optimized JSON files"
    )

    args = parser.parse_args()

    # Default to all if nothing specified
    if not any([args.states, args.cities, args.countries, args.all]):
        args.all = True

    print("=" * 60)
    print("Footprint Geographic Data Fetcher")
    print("=" * 60)

    states_data = None
    cities_data = None

    try:
        if args.all or args.countries:
            fetch_countries_metadata()

        if args.all or args.states:
            states_data = fetch_states_provinces()

        if args.all or args.cities:
            cities_data = fetch_cities()

        # Create iOS files if requested
        if args.ios or args.all:
            if states_data:
                create_ios_states_json(states_data)
            if cities_data:
                create_ios_cities_json(cities_data)

        print("\n" + "=" * 60)
        print("Done! Data files created successfully.")
        print("=" * 60)

    except urllib.error.URLError as e:
        print(f"\nError fetching data: {e}", file=sys.stderr)
        sys.exit(1)
    except json.JSONDecodeError as e:
        print(f"\nError parsing JSON: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
