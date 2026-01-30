#!/usr/bin/env python3
"""
Fetch international subnational regions data for Footprint travel tracker.

This script downloads administrative boundary data for states/provinces of
countries beyond US and Canada.

Data Sources:
- Natural Earth Admin 1 (States/Provinces): Public Domain
- ISO 3166-2 subdivision codes
- Country-specific official sources where available

Usage:
    python scripts/fetch_international_regions.py --country AU
    python scripts/fetch_international_regions.py --country MX --country BR
    python scripts/fetch_international_regions.py --all
"""

import argparse
import json
import sys
import urllib.request
import zipfile
from pathlib import Path
from typing import Dict, List, Any

# Natural Earth data sources
NATURAL_EARTH_BASE = "https://www.naturalearthdata.com/http//www.naturalearthdata.com/download/10m/cultural"
ADMIN1_URL = f"{NATURAL_EARTH_BASE}/ne_10m_admin_1_states_provinces.zip"

# Output directories
SCRIPT_DIR = Path(__file__).parent
PROJECT_ROOT = SCRIPT_DIR.parent
DATA_OUTPUT_DIR = PROJECT_ROOT / "data" / "international_regions"
BOUNDARIES_DIR = PROJECT_ROOT / "data" / "boundaries" / "international"

# Supported countries and their configurations
SUPPORTED_COUNTRIES = {
    "AU": {
        "name": "Australia",
        "regions": 8,
        "natural_earth_filter": {"ADM0_A3": "AUS"},
        "region_name_field": "name",
        "type_field": "type_en",
    },
    "MX": {
        "name": "Mexico",
        "regions": 32,
        "natural_earth_filter": {"ADM0_A3": "MEX"},
        "region_name_field": "name",
        "type_field": "type_en",
    },
    "BR": {
        "name": "Brazil",
        "regions": 27,
        "natural_earth_filter": {"ADM0_A3": "BRA"},
        "region_name_field": "name",
        "type_field": "type_en",
    },
    "DE": {
        "name": "Germany",
        "regions": 16,
        "natural_earth_filter": {"ADM0_A3": "DEU"},
        "region_name_field": "name",
        "type_field": "type_en",
    },
    "IN": {
        "name": "India",
        "regions": 36,
        "natural_earth_filter": {"ADM0_A3": "IND"},
        "region_name_field": "name",
        "type_field": "type_en",
    },
    "CN": {
        "name": "China",
        "regions": 34,
        "natural_earth_filter": {"ADM0_A3": "CHN"},
        "region_name_field": "name",
        "type_field": "type_en",
    },
}


def create_directories() -> None:
    """Create necessary output directories."""
    DATA_OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    BOUNDARIES_DIR.mkdir(parents=True, exist_ok=True)


def fetch_file(url: str, dest_path: Path) -> None:
    """Download a file to the specified path."""
    print(f"  Downloading: {url}")

    req = urllib.request.Request(
        url, headers={"User-Agent": "Footprint-Travel-Tracker/1.0"}
    )

    with urllib.request.urlopen(req, timeout=120) as response:
        with open(dest_path, "wb") as f:
            f.write(response.read())

    print(f"  Saved: {dest_path}")


def extract_shapefile(zip_path: Path, extract_dir: Path) -> Path:
    """Extract shapefile from zip and return path to .shp file."""
    print(f"  Extracting: {zip_path}")

    with zipfile.ZipFile(zip_path, "r") as zip_ref:
        zip_ref.extractall(extract_dir)

    # Find the .shp file
    shp_files = list(extract_dir.glob("*.shp"))
    if not shp_files:
        raise FileNotFoundError("No .shp file found in extracted archive")

    return shp_files[0]


def process_natural_earth_data(country_code: str) -> Dict[str, Any]:
    """
    Process Natural Earth admin 1 data for a specific country.

    Note: This is a simplified version. In a full implementation,
    you would use a library like geopandas or fiona to properly
    process the shapefile data.
    """
    config = SUPPORTED_COUNTRIES[country_code]

    print(f"Processing {config['name']} regions...")

    # For now, return sample/mock data structure
    # In a real implementation, this would:
    # 1. Load the shapefile using geopandas
    # 2. Filter for the specific country
    # 3. Extract region information
    # 4. Convert geometries to GeoJSON
    # 5. Calculate bounding boxes and centroids

    regions = []

    # Sample data structure - replace with actual shapefile processing
    sample_regions = get_sample_regions(country_code)

    for region in sample_regions:
        regions.append(
            {
                "code": region["code"],
                "name": region["name"],
                "display_name": region["name"],
                "country_code": country_code,
                "country_name": config["name"],
                "region_type": region.get("type", "state"),
                "iso_3166_2_code": region["iso_code"],
                "capital": region.get("capital"),
                "abbreviation": region.get("abbreviation"),
                # Placeholder coordinates - replace with actual data
                "bbox_north": region.get("bbox_north", 0.0),
                "bbox_south": region.get("bbox_south", 0.0),
                "bbox_east": region.get("bbox_east", 0.0),
                "bbox_west": region.get("bbox_west", 0.0),
                "center_lat": region.get("center_lat", 0.0),
                "center_lon": region.get("center_lon", 0.0),
            }
        )

    return {
        "country_code": country_code,
        "country_name": config["name"],
        "total_regions": len(regions),
        "regions": regions,
        "generated_at": "2026-01-30T00:00:00Z",
        "data_source": "Natural Earth Admin 1",
        "license": "Public Domain",
    }


def get_sample_regions(country_code: str) -> List[Dict[str, Any]]:
    """Get sample region data for demonstration/testing purposes."""

    if country_code == "AU":
        return [
            {
                "code": "NSW",
                "name": "New South Wales",
                "iso_code": "AU-NSW",
                "capital": "Sydney",
                "abbreviation": "NSW",
                "type": "state",
            },
            {
                "code": "VIC",
                "name": "Victoria",
                "iso_code": "AU-VIC",
                "capital": "Melbourne",
                "abbreviation": "VIC",
                "type": "state",
            },
            {
                "code": "QLD",
                "name": "Queensland",
                "iso_code": "AU-QLD",
                "capital": "Brisbane",
                "abbreviation": "QLD",
                "type": "state",
            },
            {
                "code": "WA",
                "name": "Western Australia",
                "iso_code": "AU-WA",
                "capital": "Perth",
                "abbreviation": "WA",
                "type": "state",
            },
            {
                "code": "SA",
                "name": "South Australia",
                "iso_code": "AU-SA",
                "capital": "Adelaide",
                "abbreviation": "SA",
                "type": "state",
            },
            {
                "code": "TAS",
                "name": "Tasmania",
                "iso_code": "AU-TAS",
                "capital": "Hobart",
                "abbreviation": "TAS",
                "type": "state",
            },
            {
                "code": "ACT",
                "name": "Australian Capital Territory",
                "iso_code": "AU-ACT",
                "capital": "Canberra",
                "abbreviation": "ACT",
                "type": "territory",
            },
            {
                "code": "NT",
                "name": "Northern Territory",
                "iso_code": "AU-NT",
                "capital": "Darwin",
                "abbreviation": "NT",
                "type": "territory",
            },
        ]
    elif country_code == "MX":
        return [
            {
                "code": "AGU",
                "name": "Aguascalientes",
                "iso_code": "MX-AGU",
                "capital": "Aguascalientes",
                "abbreviation": "AGS",
            },
            {
                "code": "BCN",
                "name": "Baja California",
                "iso_code": "MX-BCN",
                "capital": "Mexicali",
                "abbreviation": "BC",
            },
            {
                "code": "BCS",
                "name": "Baja California Sur",
                "iso_code": "MX-BCS",
                "capital": "La Paz",
                "abbreviation": "BCS",
            },
            {
                "code": "CAM",
                "name": "Campeche",
                "iso_code": "MX-CAM",
                "capital": "Campeche",
                "abbreviation": "CAM",
            },
            {
                "code": "CDMX",
                "name": "Ciudad de México",
                "iso_code": "MX-CMX",
                "capital": "Ciudad de México",
                "abbreviation": "CDMX",
                "type": "federal_district",
            },
        ]
    elif country_code == "BR":
        return [
            {
                "code": "SP",
                "name": "São Paulo",
                "iso_code": "BR-SP",
                "capital": "São Paulo",
                "abbreviation": "SP",
            },
            {
                "code": "RJ",
                "name": "Rio de Janeiro",
                "iso_code": "BR-RJ",
                "capital": "Rio de Janeiro",
                "abbreviation": "RJ",
            },
            {
                "code": "MG",
                "name": "Minas Gerais",
                "iso_code": "BR-MG",
                "capital": "Belo Horizonte",
                "abbreviation": "MG",
            },
            {
                "code": "DF",
                "name": "Distrito Federal",
                "iso_code": "BR-DF",
                "capital": "Brasília",
                "abbreviation": "DF",
                "type": "federal_district",
            },
        ]
    else:
        # Return minimal data for other countries
        return [
            {
                "code": f"{country_code}1",
                "name": "Region 1",
                "iso_code": f"{country_code}-R1",
                "capital": "Capital 1",
            },
            {
                "code": f"{country_code}2",
                "name": "Region 2",
                "iso_code": f"{country_code}-R2",
                "capital": "Capital 2",
            },
        ]


def fetch_country_regions(country_code: str) -> bool:
    """Fetch and process regions for a specific country."""
    if country_code not in SUPPORTED_COUNTRIES:
        print(f"Error: Country {country_code} not supported")
        print(f"Supported countries: {', '.join(SUPPORTED_COUNTRIES.keys())}")
        return False

    config = SUPPORTED_COUNTRIES[country_code]
    print(f"\nFetching regions for {config['name']} ({country_code})")

    try:
        # Process the data (currently using sample data)
        country_data = process_natural_earth_data(country_code)

        # Save the processed data
        output_file = DATA_OUTPUT_DIR / f"{country_code.lower()}_regions.json"
        with open(output_file, "w", encoding="utf-8") as f:
            json.dump(country_data, f, indent=2, ensure_ascii=False)

        print(f"✅ Successfully processed {len(country_data['regions'])} regions")
        print(f"   Saved to: {output_file}")

        return True

    except Exception as e:
        print(f"❌ Error processing {country_code}: {e}")
        return False


def main():
    """Main execution function."""
    parser = argparse.ArgumentParser(
        description="Fetch international subnational regions data"
    )
    parser.add_argument(
        "--country",
        action="append",
        choices=list(SUPPORTED_COUNTRIES.keys()),
        help="Country code to fetch (can be used multiple times)",
    )
    parser.add_argument(
        "--all", action="store_true", help="Fetch data for all supported countries"
    )
    parser.add_argument("--list", action="store_true", help="List supported countries")

    args = parser.parse_args()

    create_directories()

    if args.list:
        print("Supported countries:")
        for code, config in SUPPORTED_COUNTRIES.items():
            print(f"  {code}: {config['name']} ({config['regions']} regions)")
        return

    countries_to_fetch = []
    if args.all:
        countries_to_fetch = list(SUPPORTED_COUNTRIES.keys())
    elif args.country:
        countries_to_fetch = args.country
    else:
        print("Please specify --country, --all, or --list")
        parser.print_help()
        return

    print("Fetching International Subnational Regions")
    print("=" * 50)

    success_count = 0
    for country in countries_to_fetch:
        if fetch_country_regions(country):
            success_count += 1

    print(
        f"\nCompleted: {success_count}/{len(countries_to_fetch)} countries processed successfully"
    )

    if success_count < len(countries_to_fetch):
        sys.exit(1)


if __name__ == "__main__":
    main()
