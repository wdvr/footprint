#!/usr/bin/env python3
"""Build the city gazetteer (spec §2.3) from GeoNames plus curated corrections.

Two steps, so the bundled JSON is reproducible from committed sources:

  extract  GeoNames dump dir (cities500.txt, countryInfo.txt) -> data/gazetteer/geonames_cities.tsv
           Keeps every national capital, every place >= 100k people and every US place >= 25k.
  build    geonames_cities.tsv + data/gazetteer/*.{tsv,json} + bundled boundaries
           -> ios/Footprint/Resources/GeoData/cities_gazetteer.json

`build` resolves each city's country and subdivision against the same GeoJSON files the app's
GeoLocationMatcher uses, so a stay the app resolves to US-CA can only match cities stored as US-CA.

Usage:
  python3 scripts/build_city_gazetteer.py extract --geonames ~/geonames
  python3 scripts/build_city_gazetteer.py build
"""

import argparse
import csv
import json
import math
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DATA = ROOT / "data/gazetteer"
EXTRACT = DATA / "geonames_cities.tsv"
OVERRIDES = DATA / "overrides.json"
STATE_CAPITALS = DATA / "us_state_capitals.tsv"
GEO_DIR = ROOT / "ios/Footprint/Resources/GeoData"
OUTPUT = GEO_DIR / "cities_gazetteer.json"
SWIFT_GEO = ROOT / "ios/Footprint/Data/GeographicData.swift"
SWIFT_MATCHER = ROOT / "ios/Footprint/Services/GeoLocationMatcher.swift"

GAZETTEER_VERSION = "2026.11.1"
MIN_POPULATION = 100_000
MIN_US_POPULATION = 25_000
# Not cities: sections of populated places, historical / abandoned / destroyed places.
EXCLUDED_FEATURE_CODES = {"PPLX", "PPLH", "PPLQ", "PPLW", "PPLCH"}
# Countries the app tracks that are not among the 195 (193 UN members + VA + PS).
NOT_NATIONAL = {"TW", "XS"}
# Territories the app tracks as their own country; a city whose centroid falls inside one belongs to it.
APP_TERRITORIES = {"XS"}
# Boundary codes the app normalizes to another country code (COUNTRY_CODE_ALIASES in audit_geodata.py).
COUNTRY_CODE_ALIASES = {"CN-TW": "TW"}
# GeoNames country codes the bundled outlines spell differently.
GEONAMES_COUNTRY_ALIASES = {"XK": "KO"}
SPECIAL_STATE_FILES = {"US": "us_states.geojson", "CA": "canadian_provinces.geojson"}

# Match radius: a disc holding the population at 4,000 people/km², clamped to 1.5–15 km.
DENSITY_PER_KM2 = 4_000
MIN_RADIUS_M = 1_500
MAX_RADIUS_M = 15_000

STATE_FIPS = {
    "AL": "01",
    "AK": "02",
    "AZ": "04",
    "AR": "05",
    "CA": "06",
    "CO": "08",
    "CT": "09",
    "DE": "10",
    "DC": "11",
    "FL": "12",
    "GA": "13",
    "HI": "15",
    "ID": "16",
    "IL": "17",
    "IN": "18",
    "IA": "19",
    "KS": "20",
    "KY": "21",
    "LA": "22",
    "ME": "23",
    "MD": "24",
    "MA": "25",
    "MI": "26",
    "MN": "27",
    "MS": "28",
    "MO": "29",
    "MT": "30",
    "NE": "31",
    "NV": "32",
    "NH": "33",
    "NJ": "34",
    "NM": "35",
    "NY": "36",
    "NC": "37",
    "ND": "38",
    "OH": "39",
    "OK": "40",
    "OR": "41",
    "PA": "42",
    "RI": "44",
    "SC": "45",
    "SD": "46",
    "TN": "47",
    "TX": "48",
    "UT": "49",
    "VT": "50",
    "VA": "51",
    "WA": "53",
    "WV": "54",
    "WI": "55",
    "WY": "56",
}
# GeoNames still uses Connecticut's 8 former counties; Census 2022+ FIPS use 9 planning regions.
NO_COUNTY_FIPS_STATES = {"CT"}

EXTRACT_COLUMNS = [
    "geonameid",
    "name",
    "latitude",
    "longitude",
    "feature_code",
    "country_code",
    "admin1",
    "admin2",
    "population",
    "timezone",
]


def app_countries():
    text = SWIFT_GEO.read_text()
    return re.findall(r'Country\(\s*"([A-Z]{2})",\s*"([^"]+)"', text)


def countries_with_states():
    text = SWIFT_MATCHER.read_text()
    m = re.search(r"countriesWithStates = \[([^\]]*)\]", text)
    return re.findall(r'"([A-Z]{2})"', m.group(1))


def read_tsv(path):
    with open(path, encoding="utf-8") as f:
        return [
            line.rstrip("\n").split("\t")
            for line in f
            if line.strip() and not line.startswith("#")
        ]


# MARK: - extract


def extract(geonames_dir):
    overrides = json.loads(OVERRIDES.read_text())
    capital_ids = {
        v for k, v in overrides["nationalCapitalIds"].items() if not k.startswith("_")
    }
    state_capitals = {(s, name) for s, name in read_tsv(STATE_CAPITALS)}
    national = {cc for cc, _ in app_countries()} - NOT_NATIONAL
    rows = []
    with open(Path(geonames_dir) / "cities500.txt", encoding="utf-8") as f:
        for r in csv.reader(f, delimiter="\t", quoting=csv.QUOTE_NONE):
            gid, name, lat, lon, fclass, fcode, cc, admin1, admin2, pop, tz = (
                r[0],
                r[1],
                r[4],
                r[5],
                r[6],
                r[7],
                r[8],
                r[10],
                r[11],
                int(r[14] or 0),
                r[17],
            )
            if fclass != "P":
                continue
            is_capital = (fcode == "PPLC" and cc in national) or gid in capital_ids
            is_state_capital = (
                cc == "US"
                and fcode in ("PPLA", "PPLC")
                and (admin1, name) in state_capitals
            )
            big = pop >= MIN_POPULATION or (cc == "US" and pop >= MIN_US_POPULATION)
            if (
                is_capital
                or is_state_capital
                or (big and fcode not in EXCLUDED_FEATURE_CODES)
            ):
                rows.append(
                    [gid, name, lat, lon, fcode, cc, admin1, admin2, str(pop), tz]
                )
    rows.sort(key=lambda r: int(r[0]))
    with open(EXTRACT, "w", encoding="utf-8") as f:
        f.write(
            "# GeoNames cities500 extract (CC BY 4.0, https://www.geonames.org). Regenerate with:\n"
        )
        f.write(
            "#   python3 scripts/build_city_gazetteer.py extract --geonames <dump dir>\n"
        )
        f.write("#" + "\t".join(EXTRACT_COLUMNS) + "\n")
        for r in rows:
            f.write("\t".join(r) + "\n")
    print(f"wrote {len(rows)} rows to {EXTRACT.relative_to(ROOT)}")


# MARK: - boundaries


def polygons(geometry):
    if geometry["type"] == "Polygon":
        return [geometry["coordinates"]]
    if geometry["type"] == "MultiPolygon":
        return geometry["coordinates"]
    return []


class Boundaries:
    """Point-in-polygon over GeoJSON features, first match in file order (like GeoLocationMatcher)."""

    def __init__(self, path, code_key):
        self.features = []
        for feature in json.loads(path.read_text())["features"]:
            code = feature["properties"].get(code_key)
            polys = polygons(feature["geometry"])
            if not code or not polys:
                continue
            xs = [p[0] for poly in polys for p in poly[0]]
            ys = [p[1] for poly in polys for p in poly[0]]
            self.features.append((code, (min(xs), min(ys), max(xs), max(ys)), polys))

    def code_at(self, lon, lat):
        for code, (x0, y0, x1, y1), polys in self.features:
            if (
                x0 <= lon <= x1
                and y0 <= lat <= y1
                and any(inside(lon, lat, poly) for poly in polys)
            ):
                return code
        return None

    def code_near(self, lon, lat):
        """Exact match, else the first match on rings of 0.5–10 km (centroids just offshore)."""
        code = self.code_at(lon, lat)
        if code:
            return code
        for meters in (500, 1_000, 2_000, 5_000, 10_000):
            dlat = meters / 111_320
            dlon = dlat / max(0.01, math.cos(math.radians(lat)))
            for sx, sy in (
                (0, 1),
                (0, -1),
                (1, 0),
                (-1, 0),
                (1, 1),
                (1, -1),
                (-1, 1),
                (-1, -1),
            ):
                code = self.code_at(lon + sx * dlon, lat + sy * dlat)
                if code:
                    return code
        return None


def inside(x, y, poly):
    """Even-odd ray casting over all rings (outer + holes)."""
    hit = False
    for ring in poly:
        j = len(ring) - 1
        for i in range(len(ring)):
            xi, yi = ring[i][0], ring[i][1]
            xj, yj = ring[j][0], ring[j][1]
            if (yi > y) != (yj > y) and x < (xj - xi) * (y - yi) / (yj - yi) + xi:
                hit = not hit
            j = i
    return hit


# MARK: - build


def radius_meters(population):
    r = math.sqrt(max(population, 0) / (math.pi * DENSITY_PER_KM2)) * 1000
    return int(round(min(MAX_RADIUS_M, max(MIN_RADIUS_M, r)) / 10) * 10)


def build():
    overrides = json.loads(OVERRIDES.read_text())
    strip = lambda d: {k: v for k, v in d.items() if not k.startswith("_")}  # noqa: E731
    capital_overrides = strip(overrides["nationalCapitalIds"])
    country_overrides = strip(overrides["countryCodes"])
    parts_of = {
        pid: parent
        for parent, parts in strip(overrides["partsOf"]).items()
        for pid in parts
    }
    extra_subdivisions = strip(overrides["additionalSubdivisions"])
    state_capitals = dict(read_tsv(STATE_CAPITALS))

    rows = [dict(zip(EXTRACT_COLUMNS, r)) for r in read_tsv(EXTRACT)]
    part_rows = [r for r in rows if r["geonameid"] in parts_of]
    rows = [r for r in rows if r["geonameid"] not in parts_of]

    countries = Boundaries(GEO_DIR / "countries.geojson", "iso_code")
    states = {}
    for cc in countries_with_states():
        path = GEO_DIR / SPECIAL_STATE_FILES.get(cc, f"{cc}_states.geojson")
        if path.exists():
            states[cc] = Boundaries(path, "state_code")

    errors = []
    national = {cc for cc, _ in app_countries()} - NOT_NATIONAL
    capital_of = {}
    for r in rows:
        if r["geonameid"] in capital_overrides.values():
            capital_of[r["geonameid"]] = next(
                k for k, v in capital_overrides.items() if v == r["geonameid"]
            )
        elif (
            r["feature_code"] == "PPLC"
            and r["country_code"] in national
            and r["country_code"] not in capital_overrides
        ):
            capital_of[r["geonameid"]] = r["country_code"]
    capital_countries = sorted(capital_of.values())
    if sorted(national) != capital_countries:
        errors.append(
            f"national capitals: missing {sorted(national - set(capital_countries))}, "
            f"duplicated {sorted({c for c in capital_countries if capital_countries.count(c) > 1})}"
        )

    state_capital_ids = {}
    for state, name in state_capitals.items():
        matches = [
            r
            for r in rows
            if r["country_code"] == "US"
            and r["admin1"] == state
            and r["name"] == name
            and r["feature_code"] in ("PPLA", "PPLC")
        ]
        if len(matches) != 1:
            errors.append(
                f"US state capital {state} {name}: {len(matches)} GeoNames matches"
            )
        else:
            state_capital_ids[matches[0]["geonameid"]] = state

    cities = []
    disagreements = 0
    for r in rows:
        gid = r["geonameid"]
        lat, lon = float(r["latitude"]), float(r["longitude"])
        raw_boundary_cc = countries.code_near(lon, lat)
        boundary_cc = COUNTRY_CODE_ALIASES.get(raw_boundary_cc, raw_boundary_cc)
        geonames_cc = GEONAMES_COUNTRY_ALIASES.get(r["country_code"], r["country_code"])
        cc = country_overrides.get(gid) or (
            boundary_cc if boundary_cc in APP_TERRITORIES else geonames_cc
        )
        # The simplified country outlines put some border cities (Laredo, Niagara Falls, Monaco) on the
        # wrong side; the matcher accepts stays resolving to either code.
        bcc = boundary_cc if boundary_cc and boundary_cc != cc else None
        disagreements += bcc is not None
        subdivision = None
        if cc in states and raw_boundary_cc == cc:
            code = states[cc].code_near(lon, lat)
            if code:
                subdivision = f"{cc}-{code.split('-')[-1]}"
        fips = None
        if (
            cc == "US"
            and r["admin1"] in STATE_FIPS
            and r["admin1"] not in NO_COUNTY_FIPS_STATES
            and re.fullmatch(r"\d{3}", r["admin2"])
        ):
            fips = STATE_FIPS[r["admin1"]] + r["admin2"]
        city = {
            "id": f"gn:{gid}",
            "name": r["name"],
            "cc": cc,
            "bcc": bcc,
            "sub": subdivision,
            "fips": fips,
            "lat": round(lat, 5),
            "lon": round(lon, 5),
            "r": radius_meters(int(r["population"])),
            "pop": int(r["population"]),
            "tz": r["timezone"],
        }
        if gid in extra_subdivisions:
            city["subs"] = extra_subdivisions[gid]
        if gid in capital_of:
            city["nc"] = True
        if gid in state_capital_ids:
            city["sc"] = True
        cities.append({k: v for k, v in city.items() if v is not None})

    # A place inside another city's extra subdivisions (Croydon, Islington in London) is part of that city.
    spanned = {sub: c["id"] for c in cities for sub in c.get("subs", [])}
    parts = [
        c
        for c in cities
        if c.get("sub") in spanned and spanned[c["sub"]] != c["id"] and not c.get("nc")
    ]
    cities = [c for c in cities if c not in parts]
    by_id = {c["id"]: c for c in cities}
    for part in parts:
        by_id[spanned[part["sub"]]].setdefault("parts", []).append(
            [part["lat"], part["lon"], part["r"]]
        )
    for r in part_rows:
        area = [
            round(float(r["latitude"]), 5),
            round(float(r["longitude"]), 5),
            radius_meters(int(r["population"])),
        ]
        by_id[f"gn:{parts_of[r['geonameid']]}"].setdefault("parts", []).append(area)
    for c in cities:
        c.get("parts", []).sort()
    print(
        f"merged {len(parts) + len(part_rows)} parts into their city: "
        + ", ".join(sorted([c["name"] for c in parts] + [r["name"] for r in part_rows]))
    )

    cities.sort(key=lambda c: (-c["pop"], int(c["id"][3:])))
    ids = [c["id"] for c in cities]
    if len(ids) != len(set(ids)):
        errors.append("duplicate city ids")
    if errors:
        print("\n".join(f"ERROR: {e}" for e in errors), file=sys.stderr)
        sys.exit(1)

    with open(OUTPUT, "w", encoding="utf-8") as f:
        f.write(
            '{"version":"%s","source":"GeoNames cities500 (CC BY 4.0) + data/gazetteer","cities":[\n'
            % GAZETTEER_VERSION
        )
        f.write(
            ",\n".join(
                json.dumps(c, ensure_ascii=False, separators=(",", ":")) for c in cities
            )
        )
        f.write("\n]}\n")
    print(
        f"wrote {len(cities)} cities to {OUTPUT.relative_to(ROOT)}: "
        f"{sum('nc' in c for c in cities)} national capitals, {sum('sc' in c for c in cities)} US state capitals, "
        f"{sum(c['cc'] == 'US' for c in cities)} US places, {disagreements} boundary/GeoNames country disagreements"
    )


def main():
    parser = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter
    )
    sub = parser.add_subparsers(dest="command", required=True)
    ex = sub.add_parser("extract")
    ex.add_argument("--geonames", required=True, help="directory with cities500.txt")
    sub.add_parser("build")
    args = parser.parse_args()
    if args.command == "extract":
        extract(args.geonames)
    else:
        build()


if __name__ == "__main__":
    main()
