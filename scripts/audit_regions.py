#!/usr/bin/env python3
"""Audit the bundled named-regions dataset (spec §2.4, Phase 4 acceptance).

Checks, exiting non-zero on any error:
- shape: unique slug ids, known kinds, non-empty name/blurb/members, no
  duplicate members, a display name for every member, size budget (≤100 KB);
- every member key resolves against the place registry: countries and
  subdivisions against GeographicData.swift, US county FIPS against the county
  index when it is bundled (else format + state FIPS), city ids by format;
- the dataset matches its hand-curated source (ids, names, kinds, and the
  explicit member lists; metro CBSA expansions need Census data and are only
  checked for having county members).
"""

import argparse
import json
import re
import sys
from pathlib import Path

from audit_geodata import SWIFT_FILE, parse_swift

ROOT = Path(__file__).resolve().parent.parent
DATASET = ROOT / "ios/Footprint/Resources/GeoData/named_regions.json"
SOURCE = ROOT / "data/regions/named_regions.source.json"
COUNTY_INDEX = ROOT / "ios/Footprint/Resources/GeoData/counties/counties_index.json"
KINDS = {"metro", "cultural", "geographic"}
MAX_BYTES = 100_000
ID_PATTERN = re.compile(r"^[a-z]{2}-[a-z0-9]+(-[a-z0-9]+)*$")
CITY_PATTERN = re.compile(r"^gn:\d+$")
# FIPS state codes for the 50 states, DC (11) and Puerto Rico (72).
STATE_FIPS = {
    "01",
    "02",
    "04",
    "05",
    "06",
    "08",
    "09",
    "10",
    "11",
    "12",
    "13",
    "15",
    "16",
    "17",
    "18",
    "19",
    "20",
    "21",
    "22",
    "23",
    "24",
    "25",
    "26",
    "27",
    "28",
    "29",
    "30",
    "31",
    "32",
    "33",
    "34",
    "35",
    "36",
    "37",
    "38",
    "39",
    "40",
    "41",
    "42",
    "44",
    "45",
    "46",
    "47",
    "48",
    "49",
    "50",
    "51",
    "53",
    "54",
    "55",
    "56",
    "72",
}


def key_error(key, countries, states, counties):
    if key.isdigit():
        if len(key) != 5 or key[:2] not in STATE_FIPS:
            return "is not a US county FIPS code"
        if counties is not None and key not in counties:
            return "is not in counties_index.json"
        return None
    if key.startswith("gn:"):
        return None if CITY_PATTERN.match(key) else "is not a city id (gn:<id>)"
    if "-" in key:
        cc, code = key.split("-", 1)
        if cc not in states:
            return f"names a country without subdivisions ({cc})"
        if code not in states[cc]:
            return f"is not a subdivision of {cc} in GeographicData"
        return None
    return None if key in countries else "is not a country in GeographicData"


def audit(
    dataset_path=DATASET,
    source_path=SOURCE,
    swift_file=SWIFT_FILE,
    county_index=COUNTY_INDEX,
):
    errors = []
    dataset_path = Path(dataset_path)
    if (size := dataset_path.stat().st_size) > MAX_BYTES:
        errors.append(f"{dataset_path.name} is {size} bytes (budget {MAX_BYTES})")
    regions = json.loads(dataset_path.read_text())["regions"]
    states, _, countries = parse_swift(Path(swift_file).read_text())
    states = {cc: set(codes) for cc, codes in states.items()}
    county_index = Path(county_index)
    counties = (
        json.loads(county_index.read_text())["counties"]
        if county_index.exists()
        else None
    )

    seen = set()
    for region in regions:
        rid = region.get("id", "")
        label = rid or "<missing id>"
        if not ID_PATTERN.match(rid):
            errors.append(f"{label}: id is not a lowercase slug like us-bay-area")
        if rid in seen:
            errors.append(f"{label}: duplicate id")
        seen.add(rid)
        if region.get("kind") not in KINDS:
            errors.append(
                f"{label}: kind {region.get('kind')!r} not in {sorted(KINDS)}"
            )
        for field in ("name", "blurb"):
            if not str(region.get(field, "")).strip():
                errors.append(f"{label}: empty {field}")
        members = region.get("memberKeys") or []
        if not members:
            errors.append(f"{label}: no members")
        if dup := sorted({k for k in members if members.count(k) > 1}):
            errors.append(f"{label}: duplicate members {dup}")
        names = region.get("memberNames") or {}
        if missing := sorted(set(members) - names.keys()):
            errors.append(f"{label}: members without a name {missing}")
        if extra := sorted(names.keys() - set(members)):
            errors.append(f"{label}: names for non-members {extra}")
        for key in members:
            if problem := key_error(key, set(countries), states, counties):
                errors.append(f"{label}: member {key!r} {problem}")
        if region.get("cbsa") and not all(k.isdigit() for k in members):
            errors.append(f"{label}: CBSA metro has non-county members")

    source = {r["id"]: r for r in json.loads(Path(source_path).read_text())["regions"]}
    by_id = {r.get("id"): r for r in regions}
    if missing := sorted(source.keys() - by_id.keys()):
        errors.append(f"in the source but not the dataset (rebuild): {missing}")
    if extra := sorted(by_id.keys() - source.keys()):
        errors.append(f"in the dataset but not the source: {extra}")
    for rid in sorted(source.keys() & by_id.keys()):
        src, out = source[rid], by_id[rid]
        for field in ("name", "kind", "blurb", "cbsa"):
            if src.get(field) != out.get(field):
                errors.append(f"{rid}: {field} differs from the source (rebuild)")
        if bool(src.get("medal")) != bool(out.get("medal")):
            errors.append(f"{rid}: medal differs from the source (rebuild)")
        if "members" in src and src["members"] != out.get("memberKeys"):
            errors.append(f"{rid}: members differ from the source (rebuild)")
    return errors


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--dataset", default=DATASET)
    parser.add_argument("--county-index", default=COUNTY_INDEX)
    args = parser.parse_args()
    errors = audit(args.dataset, county_index=args.county_index)
    for error in errors:
        print(f"ERROR: {error}")
    if errors:
        sys.exit(1)
    regions = json.loads(Path(args.dataset).read_text())["regions"]
    members = sum(len(r["memberKeys"]) for r in regions)
    print(f"OK: {len(regions)} named regions, {members} member keys")


if __name__ == "__main__":
    main()
