#!/usr/bin/env python3
"""Build the capitals gazetteer used by the capital medals (spec §2.3, §4.2).

Source: GeoNames (CC BY 4.0) countryInfo.txt + cities1000.txt, downloaded into
a directory passed as --geonames. National capitals are the GeoNames PPLC (or
countryInfo capital name) for every country in GeographicData.swift; US state
capitals are the PPLA seats of each US state (plus Washington, DC).

Output: ios/Footprint/Resources/GeoData/capitals.json, sorted and stable.
"""

import argparse
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SWIFT_FILE = ROOT / "ios/Footprint/Data/GeographicData.swift"
OUT = ROOT / "ios/Footprint/Resources/GeoData/capitals.json"

# Countries whose GeoNames capital is ambiguous or not a PPLC row; value = geonameid.
# GQ: Malabo remains the seat of government; GeoNames already flags Ciudad de la Paz.
CAPITAL_OVERRIDES = {"GQ": "2309527"}


def radius_m(pop):
    # §2.3: match radius scales with population, clamped to 1.5–15 km.
    return round(min(15000, max(1500, 1500 + (pop**0.5) * 6)))


def load(geonames):
    cities = {}
    by_country = {}
    for line in open(geonames / "cities1000.txt", encoding="utf-8"):
        f = line.rstrip("\n").split("\t")
        row = {
            "gid": f[0],
            "name": f[1],
            "lat": float(f[4]),
            "lon": float(f[5]),
            "code": f[7],
            "cc": f[8],
            "admin1": f[10],
            "pop": int(f[14] or 0),
        }
        cities[row["gid"]] = row
        by_country.setdefault(row["cc"], []).append(row)
    capitals = {}
    for line in open(geonames / "countryInfo.txt", encoding="utf-8"):
        if line.startswith("#"):
            continue
        f = line.rstrip("\n").split("\t")
        capitals[f[0]] = f[5]
    return cities, by_country, capitals


def entry(row, cc, kind, subdivision=None):
    e = {
        "id": f"gn:{row['gid']}",
        "name": row["name"],
        "countryCode": cc,
        "kind": kind,
        "lat": round(row["lat"], 4),
        "lon": round(row["lon"], 4),
        "radiusMeters": radius_m(row["pop"]),
    }
    if subdivision:
        e["subdivisionCode"] = subdivision
    return e


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--geonames", type=Path, required=True)
    args = ap.parse_args()
    text = SWIFT_FILE.read_text()
    countries = re.findall(r'Country\(\s*"([A-Z]{2})"', text)
    us_states = re.findall(
        r'StateProvince\("([A-Z]{2})", "[^"]+", country: "US"\)', text
    )
    cities, by_country, capital_names = load(args.geonames)

    out, missing = [], []
    for cc in countries:
        rows = by_country.get(cc, [])
        if cc in CAPITAL_OVERRIDES:
            pick = cities[CAPITAL_OVERRIDES[cc]]
        else:
            pplc = [r for r in rows if r["code"] == "PPLC"]
            named = [r for r in pplc if r["name"] == capital_names.get(cc)] or pplc
            if not named:
                named = [r for r in rows if r["name"] == capital_names.get(cc)]
            if not named:
                missing.append(cc)
                continue
            pick = max(named, key=lambda r: r["pop"])
        out.append(entry(pick, cc, "national"))

    us_rows = by_country["US"]
    for state in us_states:
        if state == "DC":
            pick = next(r for r in us_rows if r["code"] == "PPLC")
        else:
            seats = [r for r in us_rows if r["code"] == "PPLA" and r["admin1"] == state]
            if not seats:
                missing.append(f"US-{state}")
                continue
            pick = max(seats, key=lambda r: r["pop"])
        out.append(entry(pick, "US", "us_state", state))

    out.sort(
        key=lambda e: (
            e["kind"],
            e["countryCode"],
            e.get("subdivisionCode", ""),
            e["id"],
        )
    )
    OUT.write_text(
        json.dumps(
            {"source": "GeoNames cities1000 (CC BY 4.0)", "capitals": out},
            ensure_ascii=False,
            indent=1,
        )
        + "\n"
    )
    print(f"{len(out)} capitals written; missing: {missing}")


if __name__ == "__main__":
    main()
