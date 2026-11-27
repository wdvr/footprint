#!/usr/bin/env python3
"""Audit the bundled geographic data (spec §5.4.3).

Checks, exiting non-zero on any error:
- integrity: every GeoJSON file parses and every feature has the expected
  properties and valid Polygon/MultiPolygon geometry (closed rings, >= 4
  points, coordinates in range);
- country coverage: every country in GeographicData.swift has a boundary in
  countries.geojson;
- subdivision codes: every feature code in a country's boundary file exists in
  that country's GeographicData list and vice versa.
"""

import argparse
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SWIFT_FILE = ROOT / "ios/Footprint/Data/GeographicData.swift"
GEO_DIR = ROOT / "ios/Footprint/Resources/GeoData"
COUNTRIES_FILE = "countries.geojson"
SPECIAL_FILES = {"US": "us_states.geojson", "CA": "canadian_provinces.geojson"}

# Boundary codes the app normalizes to a different country code (normalizedCountryCode in CountryMapView.swift)
COUNTRY_CODE_ALIASES = {"CN-TW": "TW"}

# Known mismatches awaiting an owner decision; reported as warnings, not errors.
PENDING_COUNTRIES = {
    "ES": "ES_states.geojson has 52 provinces; GeographicData has 19 autonomous communities",
}
CODES_WITHOUT_GEOMETRY = {"RU": {"SEV"}}  # Sevastopol: manual entry only
# Countries with subdivisions but no bundled boundary file; any other missing file is an error.
COUNTRIES_WITHOUT_BOUNDARY_FILE = {"AU", "BR", "DE", "MX"}


def parse_swift(text):
    text = re.sub(r"//[^\n]*", "", text)
    lists = {}
    for m in re.finditer(
        r"static let (\w+): \[StateProvince\] = \[(.*?)\n    \]", text, re.S
    ):
        lists[m.group(1)] = re.findall(r'StateProvince\(\s*"([^"]+)"', m.group(2))
    body = re.search(
        r"static func states\(for countryCode: String\).*?\n    \}", text, re.S
    )
    mapping = dict(re.findall(r'case "([A-Z]{2})": return (\w+)', body.group(0)))
    countries = re.findall(r'Country\(\s*"([A-Z]{2})"', text)
    has_states = set(
        re.findall(
            r'Country\(\s*"([A-Z]{2})"(?:[^"()]|"[^"]*")*?hasStates:\s*true', text
        )
    )
    return {cc: lists[name] for cc, name in mapping.items()}, has_states, countries


def geojson_file(geo_dir, cc):
    return geo_dir / SPECIAL_FILES.get(cc, f"{cc}_states.geojson")


def duplicates(codes):
    return sorted({c for c in codes if codes.count(c) > 1})


def geometry_errors(geometry):
    kind = (geometry or {}).get("type")
    coords = (geometry or {}).get("coordinates")
    if kind == "Polygon":
        polygons = [coords]
    elif kind == "MultiPolygon":
        polygons = coords
    else:
        return [f"geometry type {kind!r} is not Polygon/MultiPolygon"]
    if not polygons or not all(polygons):
        return ["empty geometry"]
    errors = []
    for polygon in polygons:
        for ring in polygon:
            if len(ring) < 4 or ring[0] != ring[-1]:
                errors.append(f"ring with {len(ring)} points is not closed")
            if any(not (-180 <= x <= 180 and -90 <= y <= 90) for x, y, *_ in ring):
                errors.append("coordinates out of range")
    return sorted(set(errors))


def load_features(path, code_key, errors, country=None):
    """Return feature codes of a GeoJSON file, recording integrity errors."""
    try:
        data = json.loads(path.read_text())
    except (OSError, ValueError) as e:
        errors.append(f"{path.name}: unreadable: {e}")
        return []
    if data.get("type") != "FeatureCollection" or not data.get("features"):
        errors.append(f"{path.name}: not a non-empty FeatureCollection")
        return []
    codes = []
    for i, feature in enumerate(data["features"]):
        props = feature.get("properties") or {}
        code = props.get(code_key)
        label = f"{path.name}: feature {code or f'#{i}'}"
        if not code or not props.get("name"):
            errors.append(f"{label}: missing {code_key} or name")
            continue
        if country and props.get("country_code") != country:
            errors.append(f"{label}: country_code {props.get('country_code')!r}")
        errors.extend(f"{label}: {e}" for e in geometry_errors(feature.get("geometry")))
        codes.append(code)
    if dup := duplicates(codes):
        errors.append(f"{path.name}: duplicate codes {dup}")
    return codes


def audit(swift_file=SWIFT_FILE, geo_dir=GEO_DIR):
    states, has_states, countries = parse_swift(Path(swift_file).read_text())
    geo_dir = Path(geo_dir)
    errors, warnings = [], []

    if dup := duplicates(countries):
        errors.append(f"duplicate country codes in GeographicData: {dup}")
    country_codes = load_features(geo_dir / COUNTRIES_FILE, "iso_code", errors)
    boundary_countries = {COUNTRY_CODE_ALIASES.get(c, c) for c in country_codes}
    if missing := sorted(set(countries) - boundary_countries):
        errors.append(f"countries without a boundary in {COUNTRIES_FILE}: {missing}")

    for cc in sorted(has_states - states.keys()):
        errors.append(f"{cc}: hasStates is true but states(for:) has no list")
    for cc in sorted(states.keys() - has_states):
        errors.append(f"{cc}: has a states list but hasStates is not true")

    for cc, swift_codes in sorted(states.items()):
        if dup := duplicates(swift_codes):
            errors.append(f"{cc}: duplicate codes in GeographicData: {dup}")
        path = geojson_file(geo_dir, cc)
        if not path.exists():
            if cc in COUNTRIES_WITHOUT_BOUNDARY_FILE:
                warnings.append(
                    f"{cc}: no boundary file ({path.name}); codes not audited"
                )
            else:
                errors.append(f"{cc}: boundary file {path.name} is missing")
            continue
        if cc in COUNTRIES_WITHOUT_BOUNDARY_FILE:
            errors.append(
                f"{cc}: has {path.name}; remove from COUNTRIES_WITHOUT_BOUNDARY_FILE"
            )
        geo_codes = {
            c.split("-")[-1] for c in load_features(path, "state_code", errors, cc)
        }
        swift_only = set(swift_codes) - geo_codes
        geo_only = geo_codes - set(swift_codes)
        if cc in PENDING_COUNTRIES:
            if swift_only or geo_only:
                warnings.append(
                    f"{cc}: pending owner decision: {PENDING_COUNTRIES[cc]}"
                )
            else:
                errors.append(
                    f"{cc}: matches its boundary file; remove from PENDING_COUNTRIES"
                )
            continue
        exempt = CODES_WITHOUT_GEOMETRY.get(cc, set())
        if stale := sorted(exempt - swift_only):
            errors.append(f"{cc}: remove {stale} from CODES_WITHOUT_GEOMETRY")
        if missing := sorted(geo_only):
            errors.append(f"{cc}: in {path.name} but not GeographicData: {missing}")
        if missing := sorted(swift_only - exempt):
            errors.append(f"{cc}: in GeographicData but not {path.name}: {missing}")

    exceptions = {
        "PENDING_COUNTRIES": PENDING_COUNTRIES,
        "CODES_WITHOUT_GEOMETRY": CODES_WITHOUT_GEOMETRY,
        "COUNTRIES_WITHOUT_BOUNDARY_FILE": COUNTRIES_WITHOUT_BOUNDARY_FILE,
    }
    for name, codes in exceptions.items():
        if stale := sorted(set(codes) - states.keys()):
            errors.append(f"{stale} have no subdivisions; remove from {name}")

    known = {geojson_file(geo_dir, cc).name for cc in states}
    for path in sorted(geo_dir.glob("*_states.geojson")):
        if path.name not in known:
            errors.append(f"{path.name}: no matching country in GeographicData")

    return errors, warnings


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--swift-file", default=SWIFT_FILE)
    parser.add_argument("--geo-dir", default=GEO_DIR)
    args = parser.parse_args()
    errors, warnings = audit(args.swift_file, args.geo_dir)
    for w in warnings:
        print(f"warning: {w}")
    for e in errors:
        print(f"error: {e}")
    print(f"Data audit: {len(errors)} error(s), {len(warnings)} warning(s)")
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
