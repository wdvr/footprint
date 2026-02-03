#!/usr/bin/env python3
"""Download and process admin-1 boundary data for specific countries.

This script downloads state/province/region boundaries from Natural Earth
and processes them for use in the iOS app.

Countries supported:
- Russia (83 federal subjects) - ISO 3166-2:RU
- Belgium (11 provinces) - ISO 3166-2:BE
- Netherlands (12 provinces) - ISO 3166-2:NL
- UK (4 nations) - ISO 3166-2:GB
- France (18 regions) - ISO 3166-2:FR
- Spain (19 autonomous communities) - ISO 3166-2:ES
- Italy (20 regions) - ISO 3166-2:IT
- Argentina (24 provinces) - ISO 3166-2:AR

Usage:
    cd backend && uv run python ../scripts/fetch_admin_boundaries.py
    cd backend && uv run python ../scripts/fetch_admin_boundaries.py --countries FR ES IT
    cd backend && uv run python ../scripts/fetch_admin_boundaries.py --all
"""

import argparse
import json
import tempfile
import zipfile
from io import BytesIO
from pathlib import Path

import httpx

# Natural Earth admin-1 data (10m for high detail, 50m for broader coverage)
# Using 10m for better detail
NATURAL_EARTH_10M_ADMIN1_URL = (
    "https://naciscdn.org/naturalearth/10m/cultural/"
    "ne_10m_admin_1_states_provinces.zip"
)

# Backup: 50m has broader coverage but less detail
NATURAL_EARTH_50M_ADMIN1_URL = (
    "https://naciscdn.org/naturalearth/50m/cultural/"
    "ne_50m_admin_1_states_provinces.zip"
)

# Output directories
SCRIPT_DIR = Path(__file__).parent
PROJECT_ROOT = SCRIPT_DIR.parent
DATA_DIR = PROJECT_ROOT / "data" / "boundaries" / "international"
IOS_DATA_DIR = PROJECT_ROOT / "ios" / "Footprint" / "Resources" / "GeoData"

# Countries to process with their expected subdivision counts
SUPPORTED_COUNTRIES = {
    "RU": {
        "name": "Russia",
        "expected_count": 83,
        "subdivision_type": "federal subjects",
        "output_file": "RU_states.geojson",
    },
    "BE": {
        "name": "Belgium",
        "expected_count": 11,  # 10 provinces + Brussels Capital
        "subdivision_type": "provinces",
        "output_file": "BE_states.geojson",
    },
    "NL": {
        "name": "Netherlands",
        "expected_count": 12,
        "subdivision_type": "provinces",
        "output_file": "NL_states.geojson",
    },
    "GB": {
        "name": "United Kingdom",
        "expected_count": 4,  # England, Scotland, Wales, Northern Ireland
        "subdivision_type": "nations",
        "output_file": "GB_states.geojson",
    },
    "FR": {
        "name": "France",
        "expected_count": 18,  # 13 metropolitan + 5 overseas
        "subdivision_type": "regions",
        "output_file": "FR_states.geojson",
    },
    "ES": {
        "name": "Spain",
        "expected_count": 19,  # 17 autonomous + 2 autonomous cities
        "subdivision_type": "autonomous communities",
        "output_file": "ES_states.geojson",
    },
    "IT": {
        "name": "Italy",
        "expected_count": 20,
        "subdivision_type": "regions",
        "output_file": "IT_states.geojson",
    },
    "AR": {
        "name": "Argentina",
        "expected_count": 24,  # 23 provinces + Buenos Aires
        "subdivision_type": "provinces",
        "output_file": "AR_states.geojson",
    },
}


def download_admin1_data(url: str = NATURAL_EARTH_10M_ADMIN1_URL) -> bytes:
    """Download Natural Earth admin-1 boundaries."""
    print(f"Downloading admin-1 data from {url}...")
    response = httpx.get(url, follow_redirects=True, timeout=120)
    response.raise_for_status()
    print(f"Downloaded {len(response.content) / 1024 / 1024:.1f} MB")
    return response.content


def extract_shapefile(zip_content: bytes) -> dict:
    """Extract GeoJSON from shapefile zip using fiona."""
    import fiona

    with zipfile.ZipFile(BytesIO(zip_content)) as zf:
        shp_files = [f for f in zf.namelist() if f.endswith(".shp")]
        if not shp_files:
            raise ValueError("No .shp file found in zip")

        with tempfile.TemporaryDirectory() as tmpdir:
            zf.extractall(tmpdir)
            shp_path = Path(tmpdir) / shp_files[0]

            features = []
            with fiona.open(shp_path) as src:
                for feature in src:
                    features.append(feature)

            return {"type": "FeatureCollection", "features": features}


def simplify_geometry(geom: dict, tolerance: float = 0.01) -> dict:
    """Simplify geometry to reduce file size."""
    from shapely.geometry import mapping, shape

    shapely_geom = shape(geom)
    simplified = shapely_geom.simplify(tolerance, preserve_topology=True)
    return mapping(simplified)


def filter_country_admin1(geojson: dict, country_code: str) -> list:
    """Filter admin-1 features for a specific country."""
    features = []

    for feature in geojson["features"]:
        props = feature.get("properties", {})

        # Check country code in various fields
        iso_a2 = props.get("iso_a2") or props.get("adm0_a3", "")[:2]
        if iso_a2 != country_code:
            # Also check gu_a3 (geopolitical unit)
            gu_a3 = props.get("gu_a3") or ""
            if not gu_a3.startswith(country_code):
                continue

        features.append(feature)

    return features


def process_country_admin1(
    features: list, country_code: str, tolerance: float = 0.01
) -> dict:
    """Process admin-1 features for a country."""
    processed = []
    seen_codes = set()

    for feature in features:
        props = feature.get("properties", {})

        # Strict check: ISO 3166-2 code must match the country
        iso_3166_2 = props.get("iso_3166_2", "")
        if not iso_3166_2.startswith(f"{country_code}-"):
            # Skip features that don't belong to this country
            continue

        state_code = iso_3166_2

        # Skip duplicates
        if state_code in seen_codes:
            continue
        seen_codes.add(state_code)

        # Get name
        name = (
            props.get("name")
            or props.get("gn_name")
            or props.get("name_en")
            or "Unknown"
        )

        # Get type of admin unit
        type_en = props.get("type_en", "")

        # Simplify geometry
        try:
            simplified_geom = simplify_geometry(feature["geometry"], tolerance)
        except Exception as e:
            print(f"  Warning: Could not simplify geometry for {name}: {e}")
            simplified_geom = feature["geometry"]

        processed.append(
            {
                "type": "Feature",
                "properties": {
                    "state_code": state_code,
                    "name": name,
                    "country_code": country_code,
                    "type": type_en,
                },
                "geometry": simplified_geom,
            }
        )

    return {
        "type": "FeatureCollection",
        "features": processed,
    }


def save_geojson(data: dict, path: Path) -> None:
    """Save GeoJSON to file."""
    path.parent.mkdir(parents=True, exist_ok=True)
    with open(path, "w") as f:
        json.dump(data, f, separators=(",", ":"))
    size_kb = path.stat().st_size / 1024
    print(f"  Saved {path.name}: {size_kb:.1f} KB ({len(data['features'])} features)")


def process_countries(
    geojson: dict, country_codes: list[str], tolerance: float = 0.01
) -> dict[str, dict]:
    """Process multiple countries from admin-1 data."""
    results = {}

    for code in country_codes:
        if code not in SUPPORTED_COUNTRIES:
            print(f"Warning: {code} is not in supported countries list")
            continue

        config = SUPPORTED_COUNTRIES[code]
        print(f"\nProcessing {config['name']} ({code})...")

        # Filter features for this country
        country_features = filter_country_admin1(geojson, code)
        print(f"  Found {len(country_features)} raw features")

        if not country_features:
            print(f"  Warning: No features found for {code}")
            continue

        # Process and clean up
        processed = process_country_admin1(country_features, code, tolerance)
        count = len(processed["features"])

        expected = config["expected_count"]
        if count < expected:
            print(
                f"  Warning: Found {count} {config['subdivision_type']}, "
                f"expected ~{expected}"
            )
        else:
            print(
                f"  Found {count} {config['subdivision_type']} (expected ~{expected})"
            )

        results[code] = processed

    return results


def main():
    parser = argparse.ArgumentParser(
        description="Download and process admin-1 boundaries for specific countries"
    )
    parser.add_argument(
        "--countries",
        nargs="+",
        help="Country codes to process (e.g., FR ES IT)",
    )
    parser.add_argument(
        "--all",
        action="store_true",
        help="Process all supported countries",
    )
    parser.add_argument(
        "--tolerance",
        type=float,
        default=0.01,
        help="Geometry simplification tolerance (default: 0.01)",
    )
    parser.add_argument(
        "--use-50m",
        action="store_true",
        help="Use 50m data instead of 10m (broader coverage, less detail)",
    )

    args = parser.parse_args()

    # Determine which countries to process
    if args.all:
        country_codes = list(SUPPORTED_COUNTRIES.keys())
    elif args.countries:
        country_codes = [c.upper() for c in args.countries]
    else:
        # Default to a few key countries for testing
        country_codes = ["FR", "ES", "IT"]

    print("=" * 60)
    print("Footprint Admin-1 Boundary Processor")
    print("=" * 60)
    print(f"\nCountries to process: {', '.join(country_codes)}")

    # Ensure fiona is available
    try:
        import fiona  # noqa: F401
    except ImportError:
        print("\nInstalling fiona for shapefile processing...")
        import subprocess

        subprocess.check_call(["uv", "pip", "install", "fiona"])

    # Download data
    url = NATURAL_EARTH_50M_ADMIN1_URL if args.use_50m else NATURAL_EARTH_10M_ADMIN1_URL
    zip_content = download_admin1_data(url)

    print("\nExtracting shapefile...")
    geojson = extract_shapefile(zip_content)
    print(f"Found {len(geojson['features'])} total admin-1 features worldwide")

    # Process countries
    results = process_countries(geojson, country_codes, args.tolerance)

    # Save results
    print("\n" + "-" * 60)
    print("Saving files...")
    print("-" * 60)

    for code, data in results.items():
        config = SUPPORTED_COUNTRIES[code]
        output_file = config["output_file"]

        # Save to data directory
        save_geojson(data, DATA_DIR / output_file)

        # Save to iOS resources
        save_geojson(data, IOS_DATA_DIR / output_file)

    print("\n" + "=" * 60)
    print("Summary")
    print("=" * 60)

    for code, data in results.items():
        config = SUPPORTED_COUNTRIES[code]
        count = len(data["features"])
        print(f"  {config['name']} ({code}): {count} {config['subdivision_type']}")

    print("\nDone! Files saved to:")
    print(f"  - {DATA_DIR}")
    print(f"  - {IOS_DATA_DIR}")


if __name__ == "__main__":
    main()
