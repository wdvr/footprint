#!/usr/bin/env python3
"""
Fetch landmarks and points of interest data from open sources.

Data sources:
- Wikidata: SPARQL queries for landmarks by country
  - License: CC0 (Public Domain)
  - Categories: UNESCO sites, monuments, museums, castles, etc.

- GeoNames (optional, requires account):
  - Feature classes: monuments, museums, parks, etc.

Usage:
    python scripts/fetch_landmarks.py --unesco
    python scripts/fetch_landmarks.py --popular
    python scripts/fetch_landmarks.py --all
"""

import argparse
import json
import sys
import time
import urllib.parse
import urllib.request
from pathlib import Path

SCRIPT_DIR = Path(__file__).parent
PROJECT_ROOT = SCRIPT_DIR.parent
DATA_OUTPUT_DIR = PROJECT_ROOT / "data" / "geographic"
IOS_RESOURCES_DIR = PROJECT_ROOT / "ios" / "Footprint" / "Resources" / "GeoData"

WIKIDATA_SPARQL_URL = "https://query.wikidata.org/sparql"

# Static data sources (more reliable than Wikidata SPARQL)
UNESCO_GITHUB_URL = "https://raw.githubusercontent.com/Igor-Vladyka/realplanet/master/data/places/real.planet.unesco.json"
NATIONAL_PARKS_GITHUB_URL = "https://raw.githubusercontent.com/openshift-roadshow/nationalparks-js/master/nationalparks.json"


def sparql_query(query: str, retries: int = 3) -> list[dict]:
    """Execute a SPARQL query against Wikidata with retries."""
    encoded_query = urllib.parse.urlencode({"query": query, "format": "json"})
    url = f"{WIKIDATA_SPARQL_URL}?{encoded_query}"

    req = urllib.request.Request(
        url,
        headers={
            "User-Agent": "Footprint-Travel-Tracker/1.0 (travel app; contact@example.com)",
            "Accept": "application/sparql-results+json",
        }
    )

    for attempt in range(retries):
        try:
            with urllib.request.urlopen(req, timeout=180) as response:
                data = json.loads(response.read().decode("utf-8"))
                return data.get("results", {}).get("bindings", [])
        except urllib.error.HTTPError as e:
            if e.code == 429:
                wait_time = 30 * (attempt + 1)
                print(f"  Rate limited, waiting {wait_time} seconds...")
                time.sleep(wait_time)
            elif e.code in (500, 502, 503, 504) and attempt < retries - 1:
                wait_time = 10 * (attempt + 1)
                print(f"  Server error {e.code}, retrying in {wait_time}s...")
                time.sleep(wait_time)
            else:
                raise
        except urllib.error.URLError as e:
            if attempt < retries - 1:
                wait_time = 10 * (attempt + 1)
                print(f"  Network error, retrying in {wait_time}s...")
                time.sleep(wait_time)
            else:
                raise
    return []


def fetch_json_from_url(url: str) -> dict | list:
    """Fetch JSON from a URL."""
    print(f"  Fetching: {url}")
    req = urllib.request.Request(
        url,
        headers={"User-Agent": "Footprint-Travel-Tracker/1.0"}
    )
    with urllib.request.urlopen(req, timeout=60) as response:
        return json.loads(response.read().decode("utf-8"))


def fetch_unesco_sites():
    """
    Fetch UNESCO World Heritage Sites from static GitHub data.

    Source: Igor-Vladyka/realplanet (maintained UNESCO dataset)
    """
    print("\n=== Fetching UNESCO World Heritage Sites ===")

    # Use static GitHub source instead of Wikidata (more reliable)
    try:
        data = fetch_json_from_url(UNESCO_GITHUB_URL)
    except Exception as e:
        print(f"  Error fetching UNESCO data: {e}")
        return {"sites_by_country": {}}

    print(f"  Downloaded {len(data)} UNESCO sites")

    # Process results
    sites_by_country = {}

    for site in data:
        name = site.get("name_en", "")
        # iso_code is lowercase in this dataset
        country_code = site.get("iso_code", "").upper()
        lat = site.get("latitude")
        lng = site.get("longitude")
        category = site.get("category", "")  # Cultural, Natural, or Mixed

        if not country_code or not name:
            continue

        if country_code not in sites_by_country:
            sites_by_country[country_code] = []

        sites_by_country[country_code].append({
            "name": name,
            "type": "unesco_world_heritage",
            "category": category.lower() if category else "cultural",
            "latitude": lat,
            "longitude": lng,
        })

    output = {
        "source": "Igor-Vladyka/realplanet (UNESCO data)",
        "license": "Public Domain (UNESCO data)",
        "category": "UNESCO World Heritage Sites",
        "total_sites": len(data),
        "countries_with_sites": len(sites_by_country),
        "sites_by_country": sites_by_country,
    }

    DATA_OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    output_path = DATA_OUTPUT_DIR / "unesco_sites.json"
    with open(output_path, "w", encoding="utf-8") as f:
        json.dump(output, f, indent=2, ensure_ascii=False)
    print(f"  Saved to: {output_path}")

    # Summary
    print(f"\n  Summary:")
    print(f"    Total UNESCO sites: {len(data)}")
    print(f"    Countries with sites: {len(sites_by_country)}")

    top_countries = sorted(
        sites_by_country.items(),
        key=lambda x: len(x[1]),
        reverse=True
    )[:10]
    print(f"\n  Top 10 countries by UNESCO site count:")
    for cc, sites in top_countries:
        print(f"    {cc}: {len(sites)} sites")

    return output


def fetch_popular_landmarks():
    """
    Fetch popular landmarks from Wikidata (experimental - may timeout).

    Includes: monuments, museums, castles, etc.
    Note: This uses Wikidata SPARQL which may be rate-limited or slow.
    """
    print("\n=== Fetching Popular Landmarks (from Wikidata) ===")
    print("  Note: This may be slow or fail due to Wikidata rate limits.")

    # Simplified query for just a few landmark types
    landmark_types = [
        ("Q33506", "museum", "Museums"),
        ("Q23413", "castle", "Castles"),
    ]

    all_landmarks = {}

    for wikidata_class, landmark_type, display_name in landmark_types:
        print(f"\n  Fetching {display_name}...")

        # Simplified query
        query = f"""
        SELECT ?item ?itemLabel ?countryCode ?coord WHERE {{
          ?item wdt:P31 wd:{wikidata_class}.
          ?item wdt:P17 ?country.
          ?country wdt:P297 ?countryCode.
          ?item wdt:P625 ?coord.

          SERVICE wikibase:label {{
            bd:serviceParam wikibase:language "en".
          }}
        }}
        LIMIT 300
        """

        try:
            results = sparql_query(query, retries=2)
            print(f"    Found {len(results)} {display_name}")

            for result in results:
                item_uri = result.get("item", {}).get("value", "")
                item_id = item_uri.split("/")[-1] if item_uri else ""
                name = result.get("itemLabel", {}).get("value", "")
                country_code = result.get("countryCode", {}).get("value", "")
                coord = result.get("coord", {}).get("value", "")

                lat, lng = None, None
                if coord and coord.startswith("Point("):
                    try:
                        coord_str = coord.replace("Point(", "").replace(")", "")
                        lng, lat = map(float, coord_str.split())
                    except (ValueError, IndexError):
                        pass

                if not country_code or not name:
                    continue

                if country_code not in all_landmarks:
                    all_landmarks[country_code] = []

                all_landmarks[country_code].append({
                    "name": name,
                    "type": landmark_type,
                    "latitude": lat,
                    "longitude": lng,
                })

            time.sleep(3)

        except Exception as e:
            print(f"    Skipping {display_name} due to error: {e}")
            continue

    total_landmarks = sum(len(v) for v in all_landmarks.values())

    if total_landmarks == 0:
        print("\n  No landmarks fetched (Wikidata may be unavailable).")
        return {"landmarks_by_country": {}}

    output = {
        "source": "Wikidata",
        "license": "CC0 (Public Domain)",
        "category": "Popular Landmarks",
        "total_landmarks": total_landmarks,
        "countries_with_landmarks": len(all_landmarks),
        "landmarks_by_country": all_landmarks,
    }

    DATA_OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    output_path = DATA_OUTPUT_DIR / "landmarks.json"
    with open(output_path, "w", encoding="utf-8") as f:
        json.dump(output, f, indent=2, ensure_ascii=False)
    print(f"\n  Saved to: {output_path}")

    print(f"\n  Summary:")
    print(f"    Total landmarks: {total_landmarks}")
    print(f"    Countries with landmarks: {len(all_landmarks)}")

    return output


def fetch_national_parks():
    """
    Fetch national parks from static GitHub data.

    Source: openshift-roadshow/nationalparks-js (GeoNames data)
    """
    print("\n=== Fetching National Parks ===")

    try:
        data = fetch_json_from_url(NATIONAL_PARKS_GITHUB_URL)
    except Exception as e:
        print(f"  Error fetching parks data: {e}")
        return {"parks_by_country": {}}

    print(f"  Downloaded {len(data)} national parks")

    parks_by_country = {}

    for park in data:
        name = park.get("name", "")
        country_code = park.get("countryCode", "")
        coords = park.get("coordinates", [])

        # coordinates are [lat, lng]
        lat = coords[0] if len(coords) > 0 else None
        lng = coords[1] if len(coords) > 1 else None

        if not country_code or not name:
            continue

        if country_code not in parks_by_country:
            parks_by_country[country_code] = []

        parks_by_country[country_code].append({
            "name": name,
            "type": "national_park",
            "latitude": lat,
            "longitude": lng,
        })

    output = {
        "source": "openshift-roadshow/nationalparks-js (GeoNames)",
        "license": "Public Domain (GeoNames)",
        "category": "National Parks",
        "total_parks": len(data),
        "countries_with_parks": len(parks_by_country),
        "parks_by_country": parks_by_country,
    }

    DATA_OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    output_path = DATA_OUTPUT_DIR / "national_parks.json"
    with open(output_path, "w", encoding="utf-8") as f:
        json.dump(output, f, indent=2, ensure_ascii=False)
    print(f"  Saved to: {output_path}")

    print(f"\n  Summary:")
    print(f"    Total national parks: {len(data)}")
    print(f"    Countries with parks: {len(parks_by_country)}")

    # Top countries
    top_countries = sorted(
        parks_by_country.items(),
        key=lambda x: len(x[1]),
        reverse=True
    )[:10]
    print(f"\n  Top 10 countries by park count:")
    for cc, parks in top_countries:
        print(f"    {cc}: {len(parks)} parks")

    return output


def create_ios_landmarks_json(unesco_data: dict, parks_data: dict, landmarks_data: dict):
    """Create combined iOS landmarks JSON."""
    print("\n=== Creating iOS Landmarks JSON ===")

    combined = {}

    # Add UNESCO sites
    for cc, sites in unesco_data.get("sites_by_country", {}).items():
        if cc not in combined:
            combined[cc] = []
        for site in sites:
            combined[cc].append({
                "name": site["name"],
                "type": "unesco",
                "lat": site["latitude"],
                "lng": site["longitude"],
            })

    # Add national parks
    for cc, parks in parks_data.get("parks_by_country", {}).items():
        if cc not in combined:
            combined[cc] = []
        for park in parks:
            combined[cc].append({
                "name": park["name"],
                "type": "park",
                "lat": park["latitude"],
                "lng": park["longitude"],
            })

    # Add other landmarks (limit per country to avoid bloat)
    for cc, landmarks in landmarks_data.get("landmarks_by_country", {}).items():
        if cc not in combined:
            combined[cc] = []
        # Take top 50 landmarks per country
        for lm in landmarks[:50]:
            combined[cc].append({
                "name": lm["name"],
                "type": lm["type"],
                "lat": lm["latitude"],
                "lng": lm["longitude"],
            })

    # Remove items without coordinates
    for cc in combined:
        combined[cc] = [l for l in combined[cc] if l["lat"] and l["lng"]]

    IOS_RESOURCES_DIR.mkdir(parents=True, exist_ok=True)
    output_path = IOS_RESOURCES_DIR / "world_landmarks.json"
    with open(output_path, "w", encoding="utf-8") as f:
        json.dump(combined, f, ensure_ascii=False)

    size_kb = output_path.stat().st_size / 1024
    total = sum(len(v) for v in combined.values())
    print(f"  Saved to: {output_path} ({size_kb:.1f} KB)")
    print(f"  Countries: {len(combined)}")
    print(f"  Total landmarks: {total}")


def main():
    parser = argparse.ArgumentParser(
        description="Fetch landmarks data from open sources"
    )
    parser.add_argument(
        "--unesco", action="store_true",
        help="Fetch UNESCO World Heritage Sites"
    )
    parser.add_argument(
        "--parks", action="store_true",
        help="Fetch National Parks"
    )
    parser.add_argument(
        "--popular", action="store_true",
        help="Fetch popular landmarks (monuments, museums, etc.)"
    )
    parser.add_argument(
        "--all", action="store_true",
        help="Fetch all landmark types"
    )
    parser.add_argument(
        "--ios", action="store_true",
        help="Create iOS-optimized JSON"
    )

    args = parser.parse_args()

    if not any([args.unesco, args.parks, args.popular, args.all]):
        args.all = True

    print("=" * 60)
    print("Footprint Landmarks Data Fetcher")
    print("=" * 60)

    unesco_data = {}
    parks_data = {}
    landmarks_data = {}

    try:
        if args.all or args.unesco:
            unesco_data = fetch_unesco_sites()
            time.sleep(3)

        if args.all or args.parks:
            parks_data = fetch_national_parks()
            time.sleep(3)

        if args.all or args.popular:
            landmarks_data = fetch_popular_landmarks()

        if args.ios or args.all:
            if unesco_data or parks_data or landmarks_data:
                create_ios_landmarks_json(
                    unesco_data or {"sites_by_country": {}},
                    parks_data or {"parks_by_country": {}},
                    landmarks_data or {"landmarks_by_country": {}},
                )

        print("\n" + "=" * 60)
        print("Done! Landmarks data fetched successfully.")
        print("=" * 60)

    except Exception as e:
        print(f"\nError: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
