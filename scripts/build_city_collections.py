#!/usr/bin/env python3
"""Build the city collections data for iOS from GeoNames.

Writes:
  * ios/Footprint/Resources/GeoData/capitals.json: the 195 national capitals
    (193 UN members + Vatican City + Palestine, the app's country list minus
    TW and XS) and the 51 US state capitals (50 states + DC).
  * an additive "id" field ("gn:<geonameid>") on every matched row of
    world_cities.json, so city visits are keyed by the same GeoNames ids the
    production gazetteer (spec section 2.3) uses.

Source: GeoNames dump cities500.txt (https://download.geonames.org/export/dump/).
National capitals are GeoNames feature code PPLC, US state capitals PPLA, both
checked against the CIA World Factbook; NATIONAL_OVERRIDES lists the deviations.

Usage:
  curl -O https://download.geonames.org/export/dump/cities500.zip && unzip cities500.zip
  python3 scripts/build_city_collections.py --geonames cities500.txt
  python3 scripts/build_city_collections.py --geonames cities500.txt --check
"""

from __future__ import annotations

import argparse
import json
import math
import re
import sys
import unicodedata
from collections import defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
GEO_DIR = ROOT / "ios/Footprint/Resources/GeoData"
SWIFT_FILE = ROOT / "ios/Footprint/Data/GeographicData.swift"
CAPITALS_FILE = GEO_DIR / "capitals.json"
CITIES_FILE = GEO_DIR / "world_cities.json"

DATA_VERSION = "2026.11-1"

# App countries that are not among the 195 sovereign states.
NON_SOVEREIGN = {"TW", "XS"}

# Countries where GeoNames has no PPLC or its PPLC differs from the Factbook.
NATIONAL_OVERRIDES = {
    "IL": 281184,  # Jerusalem (GeoNames files it as PPLA)
    "PS": 282239,  # Ramallah, administrative seat of the State of Palestine
}

US_STATE_COUNT = 51
NATIONAL_COUNT = 195

# GeoNames columns
GID, NAME, ASCII, ALT, LAT, LON, FCODE, CC, ADMIN1, POP, TZ = (
    0,
    1,
    2,
    3,
    4,
    5,
    7,
    8,
    10,
    14,
    17,
)


def norm(s: str) -> str:
    s = unicodedata.normalize("NFKD", s.lower().replace("\u2019", "'"))
    return "".join(c for c in s if not unicodedata.combining(c))


def km(lat1, lon1, lat2, lon2) -> float:
    p = math.pi / 180
    a = (
        math.sin((lat2 - lat1) * p / 2) ** 2
        + math.cos(lat1 * p) * math.cos(lat2 * p) * math.sin((lon2 - lon1) * p / 2) ** 2
    )
    return 2 * 6371 * math.asin(math.sqrt(a))


def app_countries() -> list[str]:
    return re.findall(r'Country\("(\w\w)", "', SWIFT_FILE.read_text())


def load_geonames(path: Path) -> list[list[str]]:
    with open(path, encoding="utf-8") as f:
        return [line.rstrip("\n").split("\t") for line in f]


def record(row, *, national: bool, subdivision: bool) -> dict:
    cc = row[CC]
    return {
        "id": f"gn:{row[GID]}",
        "name": row[NAME],
        "countryCode": cc,
        "subdivisionCode": f"{cc}-{row[ADMIN1]}" if cc == "US" else None,
        "lat": round(float(row[LAT]), 5),
        "lon": round(float(row[LON]), 5),
        "population": int(row[POP] or 0),
        "isNationalCapital": national,
        "isSubdivisionCapital": subdivision,
        "timeZone": row[TZ],
    }


def build_capitals(rows) -> list[dict]:
    by_id = {int(r[GID]): r for r in rows}
    pplc = defaultdict(list)
    for r in rows:
        if r[FCODE] == "PPLC":
            pplc[r[CC]].append(r)

    sovereign = [c for c in app_countries() if c not in NON_SOVEREIGN]
    national = []
    for cc in sovereign:
        if cc in NATIONAL_OVERRIDES:
            row = by_id[NATIONAL_OVERRIDES[cc]]
        elif len(pplc[cc]) == 1:
            row = pplc[cc][0]
        else:
            sys.exit(f"{cc}: expected one PPLC, found {len(pplc[cc])}; add an override")
        if row[CC] != cc:
            sys.exit(f"{cc}: capital {row[NAME]} is filed under {row[CC]}")
        national.append(row)

    us = [r for r in rows if r[CC] == "US" and r[FCODE] == "PPLA"]
    us.append(next(r for r in pplc["US"]))  # Washington, DC
    if len({r[ADMIN1] for r in us}) != len(us):
        sys.exit("US: more than one capital for a state")

    us_ids = {r[GID] for r in us}
    out = [record(r, national=True, subdivision=r[GID] in us_ids) for r in national]
    out += [
        record(r, national=False, subdivision=True)
        for r in us
        if r[GID] not in {n[GID] for n in national}
    ]
    if sum(c["isNationalCapital"] for c in out) != NATIONAL_COUNT:
        sys.exit(f"expected {NATIONAL_COUNT} national capitals")
    if (
        sum(c["isSubdivisionCapital"] and c["countryCode"] == "US" for c in out)
        != US_STATE_COUNT
    ):
        sys.exit(f"expected {US_STATE_COUNT} US state capitals")
    return sorted(out, key=lambda c: (c["countryCode"], c["name"]))


def assign_city_ids(rows, cities: dict) -> tuple[dict, list[str]]:
    by_cc = defaultdict(list)
    for r in rows:
        if r[CC] in cities:
            by_cc[r[CC]].append(r)
    used, unmatched, out = set(), [], {}
    for cc, entries in cities.items():
        out[cc] = []
        for c in entries:
            lat, lon, name = float(c["lat"]), float(c["lng"]), norm(c["name"])
            best = None
            for r in by_cc[cc]:
                d = km(lat, lon, float(r[LAT]), float(r[LON]))
                names_match = name in (norm(r[NAME]), norm(r[ASCII])) or name in map(
                    norm, r[ALT].split(",")
                )
                if d < 30 and names_match and (best is None or d < best[0]):
                    best = (d, r)
            entry = {k: v for k, v in c.items() if k != "id"}
            if best and best[1][GID] not in used:
                used.add(best[1][GID])
                entry = {"id": f"gn:{best[1][GID]}", **entry}
            else:
                unmatched.append(f"{cc} {c['name']}")
            out[cc].append(entry)
    return out, unmatched


def main() -> int:
    ap = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter
    )
    ap.add_argument(
        "--geonames", type=Path, required=True, help="path to GeoNames cities500.txt"
    )
    ap.add_argument(
        "--check",
        action="store_true",
        help="fail if the committed files are out of date",
    )
    args = ap.parse_args()

    rows = load_geonames(args.geonames)
    capitals = {
        "dataVersion": DATA_VERSION,
        "source": "GeoNames cities500 (CC BY 4.0), checked against the CIA World Factbook",
        "cities": build_capitals(rows),
    }
    cities, unmatched = assign_city_ids(rows, json.loads(CITIES_FILE.read_text()))

    capitals_text = json.dumps(capitals, ensure_ascii=False, indent=1) + "\n"
    cities_text = json.dumps(cities, ensure_ascii=False)
    if args.check:
        stale = [
            p.name
            for p, t in ((CAPITALS_FILE, capitals_text), (CITIES_FILE, cities_text))
            if p.read_text() != t
        ]
        if stale:
            print(f"out of date: {', '.join(stale)}")
            return 1
        print("city collections data is up to date")
        return 0

    CAPITALS_FILE.write_text(capitals_text)
    CITIES_FILE.write_text(cities_text)
    print(f"capitals.json: {len(capitals['cities'])} cities")
    print(
        f"world_cities.json: {sum(map(len, cities.values()))} cities, {len(unmatched)} without a GeoNames id"
    )
    for u in unmatched:
        print(f"  no id: {u}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
