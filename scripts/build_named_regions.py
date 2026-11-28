#!/usr/bin/env python3
"""Build the bundled named-regions dataset (spec §2.4).

Reads the hand-curated data/regions/named_regions.source.json, expands metro
entries ("cbsa") into their Census CBSA county lists, attaches a display name
to every member key and writes ios/Footprint/Resources/GeoData/named_regions.json.

Census inputs (downloaded into --cache-dir when missing):
- CBSA delineation file, July 2023 (list1_2023.xlsx; needs openpyxl);
- 2024 Gazetteer county file, for county names ("Lake County, IL").

Subdivision and country names come from GeographicData.swift.
"""

import argparse
import io
import json
import re
import urllib.request
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / "data/regions/named_regions.source.json"
OUTPUT = ROOT / "ios/Footprint/Resources/GeoData/named_regions.json"
SWIFT_FILE = ROOT / "ios/Footprint/Data/GeographicData.swift"
CACHE_DIR = ROOT / "data/regions/.cache"
DELINEATION_URL = "https://www2.census.gov/programs-surveys/metro-micro/geographies/reference-files/2023/delineation-files/list1_2023.xlsx"
GAZETTEER_URL = "https://www2.census.gov/geo/docs/maps-data/data/gazetteer/2024_Gazetteer/2024_Gaz_counties_national.zip"


def fetch(url, cache_dir):
    path = Path(cache_dir) / url.rsplit("/", 1)[-1]
    if not path.exists():
        path.parent.mkdir(parents=True, exist_ok=True)
        with urllib.request.urlopen(url) as response:
            path.write_bytes(response.read())
    return path


def cbsa_counties(xlsx_path):
    import openpyxl

    sheet = openpyxl.load_workbook(xlsx_path, read_only=True).active
    rows = sheet.iter_rows(values_only=True)
    for row in rows:
        if row[0] == "CBSA Code":
            header = list(row)
            break
    col = {name: header.index(name) for name in header if name}
    counties = {}
    for row in rows:
        if not row[0] or not str(row[0]).isdigit():
            continue
        fips = f"{row[col['FIPS State Code']]}{row[col['FIPS County Code']]}"
        counties.setdefault(str(row[0]), []).append(fips)
    return counties


def county_names(zip_path):
    with zipfile.ZipFile(zip_path) as archive:
        text = archive.read(archive.namelist()[0]).decode("utf-8")
    names = {}
    for line in io.StringIO(text).readlines()[1:]:
        fields = line.split("\t")
        names[fields[1]] = f"{fields[3].strip()}, {fields[0]}"
    return names


def place_names(swift_text):
    names = {}
    for code, name, cc in re.findall(
        r'StateProvince\(\s*"([^"]+)",\s*"([^"]+)",\s*country:\s*"([A-Z]{2})"\)',
        swift_text,
    ):
        names[f"{cc}-{code}"] = name
    for cc, name in re.findall(r'Country\(\s*"([A-Z]{2})",\s*"([^"]+)"', swift_text):
        names[cc] = name
    return names


def build(source, cbsa, counties, places):
    regions = []
    for entry in source["regions"]:
        members = list(entry.get("members") or cbsa[entry["cbsa"]])
        names = {}
        for key in members:
            name = counties.get(key) if key.isdigit() else places.get(key)
            if name is None:
                raise SystemExit(f"{entry['id']}: no name for member {key!r}")
            names[key] = name
        region = {
            "id": entry["id"],
            "name": entry["name"],
            "kind": entry["kind"],
            "blurb": entry["blurb"],
            "memberKeys": members,
            "memberNames": names,
        }
        if "cbsa" in entry:
            region["cbsa"] = entry["cbsa"]
        if entry.get("medal"):
            region["medal"] = True
        regions.append(region)
    return {
        "version": 1,
        "cbsaDelineation": source.get("cbsaDelineation"),
        "regions": regions,
    }


def dump(dataset):
    """One region per line so data reviews read as per-region diffs."""
    lines = [
        json.dumps(r, ensure_ascii=False, separators=(",", ":"))
        for r in dataset["regions"]
    ]
    head = {k: v for k, v in dataset.items() if k != "regions"}
    head_json = json.dumps(head, ensure_ascii=False, separators=(",", ":"))[1:-1]
    return "{" + head_json + ',"regions":[\n' + ",\n".join(lines) + "\n]}\n"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--cache-dir", default=CACHE_DIR)
    parser.add_argument("--output", default=OUTPUT)
    args = parser.parse_args()
    source = json.loads(SOURCE.read_text())
    cbsa = cbsa_counties(fetch(DELINEATION_URL, args.cache_dir))
    counties = county_names(fetch(GAZETTEER_URL, args.cache_dir))
    places = place_names(SWIFT_FILE.read_text())
    dataset = build(source, cbsa, counties, places)
    Path(args.output).write_text(dump(dataset), encoding="utf-8")
    print(f"wrote {len(dataset['regions'])} regions to {args.output}")


if __name__ == "__main__":
    main()
