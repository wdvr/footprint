#!/usr/bin/env python3
"""Download and process country boundary data from Natural Earth.

This script downloads country boundaries and processes them for use in the iOS app.
Natural Earth provides free, public domain map data.

Usage:
    cd backend && uv run python ../scripts/process_boundaries.py
"""

import json
import zipfile
from io import BytesIO
from pathlib import Path

import httpx
from shapely.geometry import mapping, shape, MultiPolygon, Polygon
from shapely.ops import unary_union

# Natural Earth 10m (high resolution for detailed boundaries)
NATURAL_EARTH_URL = (
    "https://naciscdn.org/naturalearth/10m/cultural/" "ne_10m_admin_0_countries.zip"
)

# Natural Earth 50m admin-1 (states/provinces) - 50m has more countries than 110m
NATURAL_EARTH_ADMIN1_URL = (
    "https://naciscdn.org/naturalearth/50m/cultural/"
    "ne_50m_admin_1_states_provinces.zip"
)

# Output directory
SCRIPT_DIR = Path(__file__).parent
PROJECT_ROOT = SCRIPT_DIR.parent
DATA_DIR = PROJECT_ROOT / "data" / "boundaries"
IOS_DATA_DIR = PROJECT_ROOT / "ios" / "Footprint" / "Resources" / "GeoData"


def download_natural_earth() -> bytes:
    """Download Natural Earth country boundaries."""
    print(f"Downloading from {NATURAL_EARTH_URL}...")
    response = httpx.get(NATURAL_EARTH_URL, follow_redirects=True, timeout=60)
    response.raise_for_status()
    print(f"Downloaded {len(response.content) / 1024:.1f} KB")
    return response.content


def download_admin1_data() -> bytes:
    """Download Natural Earth admin-1 (states/provinces) boundaries."""
    print(f"Downloading admin-1 data from {NATURAL_EARTH_ADMIN1_URL}...")
    response = httpx.get(NATURAL_EARTH_ADMIN1_URL, follow_redirects=True, timeout=60)
    response.raise_for_status()
    print(f"Downloaded {len(response.content) / 1024:.1f} KB")
    return response.content


def extract_shapefile(zip_content: bytes) -> dict:
    """Extract GeoJSON from shapefile zip."""
    import fiona

    with zipfile.ZipFile(BytesIO(zip_content)) as zf:
        shp_files = [f for f in zf.namelist() if f.endswith(".shp")]
        if not shp_files:
            raise ValueError("No .shp file found in zip")

        import tempfile

        with tempfile.TemporaryDirectory() as tmpdir:
            zf.extractall(tmpdir)
            shp_path = Path(tmpdir) / shp_files[0]

            features = []
            with fiona.open(shp_path) as src:
                for feature in src:
                    features.append(feature)

            return {"type": "FeatureCollection", "features": features}


def simplify_geometry(geom: dict, tolerance: float = 0.1) -> dict:
    """Simplify geometry to reduce file size."""
    shapely_geom = shape(geom)
    simplified = shapely_geom.simplify(tolerance, preserve_topology=True)
    return mapping(simplified)


# Overseas territories to split from parent countries
# Each entry: parent_iso -> list of (territory_code, territory_name, bounds)
# bounds = (min_lon, min_lat, max_lon, max_lat) - territory is OUTSIDE these bounds
OVERSEAS_TERRITORIES = {
    # France - mainland is roughly lat 41-51, lon -5 to 10
    "FR": {
        "mainland_bounds": (-10, 41, 15, 52),  # European France + Corsica
        "territories": [
            ("GF", "French Guiana", "South America"),
            ("GP", "Guadeloupe", "Americas"),
            ("MQ", "Martinique", "Americas"),
            ("RE", "Réunion", "Africa"),
            ("YT", "Mayotte", "Africa"),
            ("PM", "Saint Pierre and Miquelon", "Americas"),
            ("BL", "Saint Barthélemy", "Americas"),
            ("MF", "Saint Martin", "Americas"),
            ("WF", "Wallis and Futuna", "Oceania"),
            ("PF", "French Polynesia", "Oceania"),
            ("NC", "New Caledonia", "Oceania"),
        ],
    },
    # United Kingdom - mainland is roughly lat 49-61, lon -11 to 2
    "GB": {
        "mainland_bounds": (-15, 49, 5, 62),  # UK + Ireland area
        "territories": [
            ("GI", "Gibraltar", "Europe"),
            ("FK", "Falkland Islands", "South America"),
            ("GS", "South Georgia", "Antarctica"),
            ("SH", "Saint Helena", "Africa"),
            ("IO", "British Indian Ocean Territory", "Asia"),
            ("KY", "Cayman Islands", "Americas"),
            ("VG", "British Virgin Islands", "Americas"),
            ("MS", "Montserrat", "Americas"),
            ("TC", "Turks and Caicos", "Americas"),
            ("AI", "Anguilla", "Americas"),
            ("BM", "Bermuda", "Americas"),
            ("PN", "Pitcairn Islands", "Oceania"),
        ],
    },
    # Netherlands - mainland is roughly lat 50-54, lon 3-8
    "NL": {
        "mainland_bounds": (2, 50, 9, 55),  # European Netherlands
        "territories": [
            ("AW", "Aruba", "Americas"),
            ("CW", "Curaçao", "Americas"),
            ("SX", "Sint Maarten", "Americas"),
            ("BQ", "Caribbean Netherlands", "Americas"),
        ],
    },
    # United States - mainland is roughly lat 24-50, lon -125 to -66
    "US": {
        "mainland_bounds": (
            -130,
            24,
            -60,
            50,
        ),  # Continental US (excludes Alaska/Hawaii)
        "territories": [
            ("PR", "Puerto Rico", "Americas"),
            ("VI", "U.S. Virgin Islands", "Americas"),
            ("GU", "Guam", "Oceania"),
            ("AS", "American Samoa", "Oceania"),
            ("MP", "Northern Mariana Islands", "Oceania"),
        ],
    },
    # Spain - mainland is roughly lat 35-44, lon -10 to 5
    "ES": {
        "mainland_bounds": (-20, 26, 6, 45),  # Spain + Canary Islands
        "territories": [
            # Canary Islands are included in mainland bounds
            # Ceuta and Melilla are tiny and usually not separate polygons
        ],
    },
    # Portugal - mainland is roughly lat 36-42, lon -10 to -6
    "PT": {
        "mainland_bounds": (-35, 30, -5, 45),  # Portugal + Azores + Madeira
        "territories": [
            # Azores and Madeira are included in bounds
        ],
    },
    # Denmark - mainland is roughly lat 54-58, lon 8-16
    "DK": {
        "mainland_bounds": (7, 54, 16, 58),  # Denmark proper
        "territories": [
            ("GL", "Greenland", "Americas"),
            ("FO", "Faroe Islands", "Europe"),
        ],
    },
    # Norway - mainland is roughly lat 57-72, lon 4-32
    "NO": {
        "mainland_bounds": (3, 57, 35, 72),  # Norway mainland
        "territories": [
            ("SJ", "Svalbard and Jan Mayen", "Europe"),
            ("BV", "Bouvet Island", "Antarctica"),
        ],
    },
    # Australia - mainland is roughly lat -45 to -10, lon 110 to 155
    "AU": {
        "mainland_bounds": (110, -45, 160, -8),  # Australia + Tasmania
        "territories": [
            ("NF", "Norfolk Island", "Oceania"),
            ("CX", "Christmas Island", "Oceania"),
            ("CC", "Cocos Islands", "Oceania"),
            ("HM", "Heard and McDonald Islands", "Antarctica"),
        ],
    },
    # New Zealand - mainland is roughly lat -48 to -34, lon 165 to 180
    "NZ": {
        "mainland_bounds": (165, -48, 180, -32),  # NZ mainland
        "territories": [
            ("CK", "Cook Islands", "Oceania"),
            ("NU", "Niue", "Oceania"),
            ("TK", "Tokelau", "Oceania"),
        ],
    },
}


def get_polygon_centroid(polygon):
    """Get the centroid of a polygon."""
    if isinstance(polygon, Polygon):
        return polygon.centroid.x, polygon.centroid.y
    return None


def is_in_mainland_bounds(polygon, bounds):
    """Check if a polygon's centroid is within the mainland bounds."""
    min_lon, min_lat, max_lon, max_lat = bounds
    centroid = get_polygon_centroid(polygon)
    if centroid is None:
        return True  # Default to mainland if can't determine
    lon, lat = centroid
    return min_lon <= lon <= max_lon and min_lat <= lat <= max_lat


def identify_territory(polygon, territories_list):
    """Try to identify which territory a polygon belongs to based on location."""
    centroid = get_polygon_centroid(polygon)
    if centroid is None:
        return None

    lon, lat = centroid

    # Use geographic bounds to identify territories
    # Format: (min_lon, min_lat, max_lon, max_lat, code, name, continent)
    territory_bounds = [
        # French territories
        (-56, -6, -50, 7, "GF", "French Guiana", "South America"),
        (-62, 15.8, -60.5, 16.6, "GP", "Guadeloupe", "Americas"),
        (-61.5, 14.3, -60.5, 15, "MQ", "Martinique", "Americas"),
        (55, -21.5, 56, -20.8, "RE", "Réunion", "Africa"),
        (44.5, -13.5, 45.5, -12.5, "YT", "Mayotte", "Africa"),
        (-56.5, 46.5, -55.5, 47.5, "PM", "Saint Pierre and Miquelon", "Americas"),
        (-63, 17.8, -62.5, 18, "BL", "Saint Barthélemy", "Americas"),
        (-63.5, 18, -62.5, 18.2, "MF", "Saint Martin", "Americas"),
        (-178.5, -14.5, -175.5, -13, "WF", "Wallis and Futuna", "Oceania"),
        (-155, -28, -134, -7, "PF", "French Polynesia", "Oceania"),
        (163, -23, 169, -19, "NC", "New Caledonia", "Oceania"),
        # Danish territories
        (-75, 59, -10, 84, "GL", "Greenland", "Americas"),
        (-8, 61, -6, 63, "FO", "Faroe Islands", "Europe"),
        # UK territories
        (-6, 35.8, -5, 36.3, "GI", "Gibraltar", "Europe"),
        (-62, -53, -57, -51, "FK", "Falkland Islands", "South America"),
        (-38, -55, -35, -53, "GS", "South Georgia", "Antarctica"),
        (-6.5, -16.5, -5, -15.5, "SH", "Saint Helena", "Africa"),
        (71, -8, 73, -4, "IO", "British Indian Ocean Territory", "Asia"),
        (-82, 19, -79, 20, "KY", "Cayman Islands", "Americas"),
        (-65, 18, -64, 19, "VG", "British Virgin Islands", "Americas"),
        (-62.5, 16.5, -61.5, 17, "MS", "Montserrat", "Americas"),
        (-72.5, 21, -70.5, 22, "TC", "Turks and Caicos", "Americas"),
        (-63.5, 18, -62.5, 18.5, "AI", "Anguilla", "Americas"),
        (-65, 32, -64, 33, "BM", "Bermuda", "Americas"),
        (-131, -25.5, -124, -23, "PN", "Pitcairn Islands", "Oceania"),
        # Dutch Caribbean
        (-70.5, 12, -68.5, 12.5, "CW", "Curaçao", "Americas"),
        (-70.5, 12.3, -69.5, 13, "AW", "Aruba", "Americas"),
        (-63.5, 17.8, -62.5, 18.3, "SX", "Sint Maarten", "Americas"),
        (-69, 11.5, -67.5, 13.5, "BQ", "Caribbean Netherlands", "Americas"),
        # US territories
        (-68, 17.5, -65, 18.6, "PR", "Puerto Rico", "Americas"),
        (-65.5, 17.5, -64, 18.5, "VI", "U.S. Virgin Islands", "Americas"),
        (144, 13, 145, 14, "GU", "Guam", "Oceania"),
        (-171.5, -14.5, -169, -14, "AS", "American Samoa", "Oceania"),
        (144.5, 14, 146.5, 21, "MP", "Northern Mariana Islands", "Oceania"),
        # Norwegian territories
        (10, 76, 35, 81, "SJ", "Svalbard", "Europe"),
        (2.5, -55, 4, -54, "BV", "Bouvet Island", "Antarctica"),
        # Australian territories
        (167.5, -29.5, 168.5, -28.5, "NF", "Norfolk Island", "Oceania"),
        (105, -11, 106, -10, "CX", "Christmas Island", "Oceania"),
        (96, -12.5, 97, -11.5, "CC", "Cocos Islands", "Oceania"),
        (72, -54, 74, -52, "HM", "Heard and McDonald Islands", "Antarctica"),
        # New Zealand territories
        (-166, -22, -156, -8, "CK", "Cook Islands", "Oceania"),
        (-170, -20, -169, -18, "NU", "Niue", "Oceania"),
        (-172.5, -10, -171, -8, "TK", "Tokelau", "Oceania"),
    ]

    for min_lon, min_lat, max_lon, max_lat, code, name, continent in territory_bounds:
        if min_lon <= lon <= max_lon and min_lat <= lat <= max_lat:
            return (code, name, continent)

    return None


def split_overseas_territories(features: list) -> list:
    """Split overseas territories from parent country MultiPolygons."""
    # First, collect all existing ISO codes to avoid creating duplicates
    existing_codes = {f.get("properties", {}).get("iso_code") for f in features}
    print(f"  Found {len(existing_codes)} existing territory codes")

    result = []
    territories_created = {}  # Track created territories to merge polygons

    for feature in features:
        props = feature.get("properties", {})
        iso_code = props.get("iso_code")

        # Check if this country has overseas territories to split
        if iso_code not in OVERSEAS_TERRITORIES:
            result.append(feature)
            continue

        config = OVERSEAS_TERRITORIES[iso_code]
        mainland_bounds = config["mainland_bounds"]
        geom = feature.get("geometry", {})

        # Only process MultiPolygons
        if geom.get("type") != "MultiPolygon":
            result.append(feature)
            continue

        shapely_geom = shape(geom)
        mainland_polygons = []
        territory_polygons = {}  # territory_code -> list of polygons

        # Sort polygons into mainland vs territories
        for polygon in shapely_geom.geoms:
            if is_in_mainland_bounds(polygon, mainland_bounds):
                mainland_polygons.append(polygon)
            else:
                # Try to identify which territory this belongs to
                territory_info = identify_territory(polygon, config["territories"])
                if territory_info:
                    code = territory_info[0]
                    if code not in territory_polygons:
                        territory_polygons[code] = {
                            "polygons": [],
                            "name": territory_info[1],
                            "continent": territory_info[2],
                        }
                    territory_polygons[code]["polygons"].append(polygon)
                else:
                    # Unknown territory, keep with mainland
                    mainland_polygons.append(polygon)

        # Create mainland feature
        if mainland_polygons:
            if len(mainland_polygons) == 1:
                mainland_geom = mainland_polygons[0]
            else:
                mainland_geom = MultiPolygon(mainland_polygons)

            result.append(
                {
                    "type": "Feature",
                    "properties": props,
                    "geometry": mapping(mainland_geom),
                }
            )
            print(f"  {iso_code}: kept {len(mainland_polygons)} mainland polygon(s)")

        # Create territory features
        for code, data in territory_polygons.items():
            # Skip if this territory already exists as a separate feature in Natural Earth
            if code in existing_codes:
                print(
                    f"  Skipping {code} ({data['name']}) - already exists as separate feature"
                )
                continue

            polygons = data["polygons"]
            if len(polygons) == 1:
                territory_geom = polygons[0]
            else:
                territory_geom = MultiPolygon(polygons)

            # Check if territory already exists as separate feature
            if code not in territories_created:
                territories_created[code] = {
                    "type": "Feature",
                    "properties": {
                        "iso_code": code,
                        "name": data["name"],
                        "continent": data["continent"],
                        "region": "",
                        "subregion": "",
                        "parent_country": iso_code,
                    },
                    "geometry": mapping(territory_geom),
                }
                print(
                    f"  Split out {code} ({data['name']}) with {len(polygons)} polygon(s)"
                )

    # Add all created territories
    result.extend(territories_created.values())

    return result


def process_countries(geojson: dict) -> dict:
    """Process countries and extract relevant properties."""
    # Features to exclude (not real countries, or duplicates we want to skip)
    EXCLUDE_NAMES = {
        "Brazilian I.",
        "Southern Patagonian Ice Field",
        "Bir Tawil",  # Unclaimed territory
        "Baykonur Cosmodrome",
        "Baikonur",
        "Indian Ocean Ter.",
        "Serranilla Bank",
        "Bajo Nuevo Bank",
        "Scarborough Reef",
        "Spratly Is.",
        "Paracel Is.",
        "Clipperton I.",
        "Ashmore and Cartier Is.",
        "Coral Sea Is.",
        "USNB Guantanamo Bay",
        "Akrotiri",
        "Dhekelia",
        "Siachen Glacier",
        "Cyprus U.N. Buffer Zone",
    }

    # Collect features by ISO code, keeping the one with the largest area
    features_by_code = {}

    for feature in geojson["features"]:
        props = feature.get("properties", {})
        name = props.get("NAME") or props.get("ADMIN") or "Unknown"

        # Skip excluded features
        if name in EXCLUDE_NAMES:
            print(f"  Excluding: {name}")
            continue

        iso_code = props.get("ISO_A2") or props.get("ISO_A2_EH")
        if iso_code in (None, "-99", "-1"):
            iso_code = props.get("ADM0_A3", "")[:2] if props.get("ADM0_A3") else None

        if not iso_code or iso_code in ("-99", "-1"):
            print(f"  Skipping: {name} (no ISO code)")
            continue

        geom = feature["geometry"]
        shapely_geom = shape(geom)

        # If we already have this ISO code, merge geometries
        if iso_code in features_by_code:
            existing = features_by_code[iso_code]
            existing_geom = shape(existing["geometry"])

            # Merge the geometries
            try:
                merged = unary_union([existing_geom, shapely_geom])
                features_by_code[iso_code]["geometry"] = mapping(merged)
                print(
                    f"  Merged duplicate: {name} into {existing['properties']['name']}"
                )
            except Exception as e:
                print(f"  Warning: Could not merge {name}: {e}")
        else:
            features_by_code[iso_code] = {
                "type": "Feature",
                "properties": {
                    "iso_code": iso_code,
                    "name": name,
                    "continent": props.get("CONTINENT", ""),
                    "region": props.get("REGION_UN", ""),
                    "subregion": props.get("SUBREGION", ""),
                },
                "geometry": geom,  # Don't simplify yet, do after merging
            }

    # Simplify geometries after merging
    processed_features = []
    for iso_code, feature in features_by_code.items():
        feature["geometry"] = simplify_geometry(feature["geometry"], tolerance=0.05)
        processed_features.append(feature)

    print(f"Processed {len(processed_features)} countries (after deduplication)")

    # Split overseas territories from parent countries
    print("\nSplitting overseas territories...")
    processed_features = split_overseas_territories(processed_features)
    print(f"Final count: {len(processed_features)} features (countries + territories)")

    return {"type": "FeatureCollection", "features": processed_features}


def process_us_states(geojson: dict) -> dict:
    """Process US states from admin-1 data."""
    processed_features = []

    for feature in geojson["features"]:
        props = feature.get("properties", {})

        # Filter for US states only
        iso_a2 = props.get("iso_a2") or props.get("adm0_a3", "")[:2]
        if iso_a2 != "US":
            continue

        # Get state code (postal abbreviation)
        state_code = props.get("iso_3166_2", "")
        if state_code.startswith("US-"):
            state_code = state_code[3:]
        elif not state_code:
            state_code = props.get("postal", "")

        if not state_code:
            print(f"  Skipping US state: {props.get('name', 'Unknown')} (no code)")
            continue

        name = props.get("name") or props.get("gn_name") or "Unknown"

        simplified_geom = simplify_geometry(feature["geometry"], tolerance=0.02)

        processed_features.append(
            {
                "type": "Feature",
                "properties": {
                    "state_code": state_code,
                    "name": name,
                    "country_code": "US",
                },
                "geometry": simplified_geom,
            }
        )

    print(f"Processed {len(processed_features)} US states")
    return {"type": "FeatureCollection", "features": processed_features}


def process_canadian_provinces(geojson: dict) -> dict:
    """Process Canadian provinces from admin-1 data."""
    processed_features = []

    for feature in geojson["features"]:
        props = feature.get("properties", {})

        # Filter for Canada only
        iso_a2 = props.get("iso_a2") or props.get("adm0_a3", "")[:2]
        if iso_a2 != "CA":
            continue

        # Get province code
        province_code = props.get("iso_3166_2", "")
        if province_code.startswith("CA-"):
            province_code = province_code[3:]
        elif not province_code:
            province_code = props.get("postal", "")

        if not province_code:
            print(f"  Skipping CA province: {props.get('name', 'Unknown')} (no code)")
            continue

        name = props.get("name") or props.get("gn_name") or "Unknown"

        simplified_geom = simplify_geometry(feature["geometry"], tolerance=0.02)

        processed_features.append(
            {
                "type": "Feature",
                "properties": {
                    "state_code": province_code,
                    "name": name,
                    "country_code": "CA",
                },
                "geometry": simplified_geom,
            }
        )

    print(f"Processed {len(processed_features)} Canadian provinces")
    return {"type": "FeatureCollection", "features": processed_features}


def save_geojson(data: dict, path: Path) -> None:
    """Save GeoJSON to file."""
    path.parent.mkdir(parents=True, exist_ok=True)
    with open(path, "w") as f:
        json.dump(data, f, separators=(",", ":"))
    size_kb = path.stat().st_size / 1024
    print(f"Saved {path.name}: {size_kb:.1f} KB")


def create_swift_country_mapping(geojson: dict, output_path: Path) -> None:
    """Create a Swift file with country code to name mapping."""
    # Use dict to deduplicate by code (keep first occurrence)
    countries_by_code = {}
    for feature in geojson["features"]:
        props = feature["properties"]
        code = props["iso_code"]
        if code not in countries_by_code:
            countries_by_code[code] = {
                "code": code,
                "name": props["name"],
                "continent": props["continent"],
                "region": props["region"],
            }

    countries = list(countries_by_code.values())
    countries.sort(key=lambda x: x["name"])

    swift_code = """// Auto-generated country data with boundary information
// Generated by scripts/process_boundaries.py

import Foundation

struct CountryInfo: Codable, Identifiable {
    let code: String
    let name: String
    let continent: String
    let region: String

    var id: String { code }
}

// Countries with boundary data available
let countriesWithBoundaries: [CountryInfo] = [
"""

    for country in countries:
        swift_code += f'    CountryInfo(code: "{country["code"]}", name: "{country["name"]}", continent: "{country["continent"]}", region: "{country["region"]}"),\n'

    swift_code += "]\n"

    output_path.parent.mkdir(parents=True, exist_ok=True)
    with open(output_path, "w") as f:
        f.write(swift_code)
    print(f"Created Swift country mapping: {output_path}")


def main():
    """Main function to download and process boundary data."""
    print("=" * 60)
    print("Footprint Boundary Data Processor")
    print("=" * 60)

    try:
        import fiona  # noqa: F401
    except ImportError:
        print("\nInstalling fiona for shapefile processing...")
        import subprocess

        subprocess.check_call(["uv", "pip", "install", "fiona"])

    zip_content = download_natural_earth()

    print("\nExtracting shapefile...")
    raw_geojson = extract_shapefile(zip_content)
    print(f"Found {len(raw_geojson['features'])} features")

    print("\nProcessing countries...")
    processed = process_countries(raw_geojson)

    print("\nSaving country files...")
    save_geojson(processed, DATA_DIR / "countries.geojson")

    IOS_DATA_DIR.mkdir(parents=True, exist_ok=True)
    save_geojson(processed, IOS_DATA_DIR / "countries.geojson")

    swift_path = (
        PROJECT_ROOT / "ios" / "Footprint" / "Generated" / "CountryBoundaries.swift"
    )
    create_swift_country_mapping(processed, swift_path)

    # Process admin-1 data (states/provinces)
    print("\n" + "-" * 60)
    print("Processing admin-1 boundaries (states/provinces)...")
    print("-" * 60)

    admin1_zip = download_admin1_data()

    print("\nExtracting admin-1 shapefile...")
    admin1_geojson = extract_shapefile(admin1_zip)
    print(f"Found {len(admin1_geojson['features'])} admin-1 features")

    print("\nProcessing US states...")
    us_states = process_us_states(admin1_geojson)

    print("\nProcessing Canadian provinces...")
    ca_provinces = process_canadian_provinces(admin1_geojson)

    print("\nSaving admin-1 files...")
    save_geojson(us_states, DATA_DIR / "us_states.geojson")
    save_geojson(us_states, IOS_DATA_DIR / "us_states.geojson")

    save_geojson(ca_provinces, DATA_DIR / "canadian_provinces.geojson")
    save_geojson(ca_provinces, IOS_DATA_DIR / "canadian_provinces.geojson")

    print("\n" + "=" * 60)
    print("Done! All boundary data is ready for use.")
    print("=" * 60)


if __name__ == "__main__":
    main()
