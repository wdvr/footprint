#!/usr/bin/env python3
"""Build the bundled US county packs (production spec §2.2).

Input: Census cartographic boundary file cb_2024_us_county_500k (public domain), downloaded from
https://www2.census.gov/geo/tiger/GENZ2024/shp/cb_2024_us_county_500k.zip and unzipped.

Output (committed, like the other GeoJSON):
  ios/Footprint/Resources/GeoData/counties/counties_US-<ST>.json     one pack per state, DC and PR
  ios/Footprint/Resources/GeoData/counties/counties_index.json       FIPS -> name, local term, state, land area,
                                                                     and an interior point of the full-resolution
                                                                     county that its pack also contains

Requires: pip install pyshp shapely
Usage: python scripts/build_us_counties.py /path/to/cb_2024_us_county_500k
"""

import json
import sys
from pathlib import Path

import shapefile
from shapely.geometry import MultiPolygon, Polygon, shape
from shapely.ops import polylabel

ROOT = Path(__file__).resolve().parent.parent
OUT_DIR = ROOT / "ios/Footprint/Resources/GeoData/counties"

TOLERANCE = 0.0005
PRECISION = 4
# Packed coordinates are integers in 1/SCALE degrees (~11 m), delta-encoded per ring.
SCALE = 10_000
MAX_PACK_BYTES = 250_000
# Territories other than PR have no subdivision entry in the app's US list.
EXCLUDED_STATES = {"AS", "GU", "MP", "VI"}
# Census LSAD code -> the local term for a county equivalent (§2.2 "64 parishes").
LSAD_TERMS = {
    "06": "county",
    "03": "city and borough",
    "04": "borough",
    "05": "census area",
    "07": "district",
    "10": "island",
    "12": "municipality",
    "13": "municipio",
    "15": "parish",
    "25": "city",
    "PL": "planning region",
    "00": "county",
}


def rounded(geom):
    def ring(coords):
        return [[round(x, PRECISION), round(y, PRECISION)] for x, y in coords]

    polys = [geom] if isinstance(geom, Polygon) else list(geom.geoms)
    return {
        "type": "MultiPolygon",
        "coordinates": [
            [ring(p.exterior.coords)] + [ring(i.coords) for i in p.interiors]
            for p in polys
        ],
    }


def packed_rings(geom):
    """[[ring, hole, ...], ...] with each ring as flat delta-encoded [dx0, dy0, dx1, dy1, ...]."""
    polys = []
    for poly in geom["coordinates"]:
        rings = []
        for ring in poly:
            flat, px, py = [], 0, 0
            for x, y in ring[:-1]:
                ix, iy = round(x * SCALE), round(y * SCALE)
                flat += [ix - px, iy - py]
                px, py = ix, iy
            rings.append(flat)
        polys.append(rings)
    return polys


def simplified(geom, tolerance):
    simple = geom.simplify(tolerance, preserve_topology=True)
    if simple.is_empty:
        return geom
    if not isinstance(simple, Polygon | MultiPolygon):
        simple = MultiPolygon([g for g in simple.geoms if isinstance(g, Polygon)])
    return simple


def interior_point(original, packed):
    """A point well inside the county that the packed (simplified) geometry also contains."""
    candidates = sorted(
        [original] if isinstance(original, Polygon) else original.geoms,
        key=lambda p: p.area,
        reverse=True,
    )
    for poly in candidates:
        for tolerance in (0.001, 0.0001):
            point = polylabel(poly, tolerance=tolerance)
            if packed.contains(point):
                return point
    point = packed.representative_point()
    assert original.contains(point)
    return point


def pack_state(records, tolerance):
    counties, index = [], {}
    for rec, original in records:
        packed_geom = shape(rounded(simplified(original, tolerance)))
        if not packed_geom.is_valid:
            packed_geom = packed_geom.buffer(0)
        point = interior_point(original, packed_geom)
        bbox = [round(v, PRECISION) for v in packed_geom.bounds]
        counties.append(
            {
                "fips": rec["GEOID"],
                "bbox": bbox,
                "polygons": packed_rings(rounded(packed_geom)),
            }
        )
        index[rec["GEOID"]] = {
            "name": rec["NAMELSAD"],
            "state": rec["STUSPS"],
            "term": LSAD_TERMS[rec["LSAD"]],
            "landKm2": round(rec["ALAND"] / 1e6, 1),
            "lat": round(point.y, PRECISION),
            "lon": round(point.x, PRECISION),
        }
    counties.sort(key=lambda c: c["fips"])
    return json.dumps(
        {"scale": SCALE, "counties": counties}, separators=(",", ":")
    ), index


def main(src: str) -> None:
    reader = shapefile.Reader(src)
    by_state: dict[str, list] = {}
    for sr in reader.iterShapeRecords():
        rec = sr.record.as_dict()
        if rec["STUSPS"] not in EXCLUDED_STATES:
            by_state.setdefault(rec["STUSPS"], []).append(
                (rec, shape(sr.shape.__geo_interface__))
            )

    OUT_DIR.mkdir(parents=True, exist_ok=True)
    for old in OUT_DIR.glob("counties_US-*"):
        old.unlink()
    index: dict[str, dict] = {}
    for state, records in sorted(by_state.items()):
        # Coarsen only states whose pack would blow the per-state budget (AK, TX).
        tolerance = TOLERANCE
        pack, state_index = pack_state(records, tolerance)
        while len(pack) > MAX_PACK_BYTES:
            tolerance *= 1.5
            pack, state_index = pack_state(records, tolerance)
        if tolerance != TOLERANCE:
            print(f"{state}: tolerance {tolerance:.5f}")
        (OUT_DIR / f"counties_US-{state}.json").write_text(pack)
        index.update(state_index)
    (OUT_DIR / "counties_index.json").write_text(
        json.dumps(
            {
                "source": "cb_2024_us_county_500k",
                "counties": dict(sorted(index.items())),
            },
            separators=(",", ":"),
        )
    )
    total = sum(p.stat().st_size for p in OUT_DIR.iterdir())
    print(f"{len(index)} counties in {len(by_state)} packs, {total / 1e6:.2f} MB")


if __name__ == "__main__":
    main(sys.argv[1])
