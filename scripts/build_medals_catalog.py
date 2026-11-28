#!/usr/bin/env python3
"""Generate the medals v2 catalog (spec §4.1, §4.2) from this single source file.

Writes byte-identical copies to the iOS bundle and the backend so the two can
never drift; `--check` fails (exit 1) when either copy is stale. Country,
continent and subdivision data are read from GeographicData.swift so set
medals ("every country of Africa", "all 47 JP prefectures") follow the data.
"""

import argparse
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SWIFT_FILE = ROOT / "ios/Footprint/Data/GeographicData.swift"
OUTPUTS = [
    ROOT / "ios/Footprint/Resources/medals.json",
    ROOT / "backend/src/data/medals.json",
]
CATALOG_VERSION = 1
TIER_LEVELS = ["bronze", "silver", "gold", "platinum"]

SUBDIVISION_REGION_TYPES = {
    "us_state": "US",
    "canadian_province": "CA",
    "australian_state": "AU",
    "mexican_state": "MX",
    "brazilian_state": "BR",
    "german_state": "DE",
    "french_region": "FR",
    "spanish_community": "ES",
    "italian_region": "IT",
    "dutch_province": "NL",
    "belgian_province": "BE",
    "uk_country": "GB",
    "russian_federal_subject": "RU",
    "argentine_province": "AR",
    "japanese_prefecture": "JP",
    "south_korean_province": "KR",
    "norwegian_county": "NO",
}
# Opt-in completionist layer (PR #128); regionCode is the 5-digit county FIPS.
COUNTY_REGION_TYPE = "us_county"
# Named regions (spec §2.4, Phase 4); regionCode is the region id.
NAMED_REGION_TYPE = "named_region"

# Census 2024 county equivalents per state: (state FIPS, count). Matches the PR #128 county packs.
COUNTY_STATES = {
    "AK": ("02", 30),
    "AL": ("01", 67),
    "AR": ("05", 75),
    "AZ": ("04", 15),
    "CA": ("06", 58),
    "CO": ("08", 64),
    "CT": ("09", 9),
    "DC": ("11", 1),
    "DE": ("10", 3),
    "FL": ("12", 67),
    "GA": ("13", 159),
    "HI": ("15", 5),
    "IA": ("19", 99),
    "ID": ("16", 44),
    "IL": ("17", 102),
    "IN": ("18", 92),
    "KS": ("20", 105),
    "KY": ("21", 120),
    "LA": ("22", 64),
    "MA": ("25", 14),
    "MD": ("24", 24),
    "ME": ("23", 16),
    "MI": ("26", 83),
    "MN": ("27", 87),
    "MO": ("29", 115),
    "MS": ("28", 82),
    "MT": ("30", 56),
    "NC": ("37", 100),
    "ND": ("38", 53),
    "NE": ("31", 93),
    "NH": ("33", 10),
    "NJ": ("34", 21),
    "NM": ("35", 33),
    "NV": ("32", 17),
    "NY": ("36", 62),
    "OH": ("39", 88),
    "OK": ("40", 77),
    "OR": ("41", 36),
    "PA": ("42", 67),
    "RI": ("44", 5),
    "SC": ("45", 46),
    "SD": ("46", 66),
    "TN": ("47", 95),
    "TX": ("48", 254),
    "UT": ("49", 29),
    "VA": ("51", 133),
    "VT": ("50", 14),
    "WA": ("53", 39),
    "WI": ("55", 72),
    "WV": ("54", 55),
    "WY": ("56", 23),
}

ISLAND_NATIONS = [
    "AG",
    "BB",
    "BH",
    "BN",
    "BS",
    "CU",
    "CV",
    "CY",
    "DM",
    "DO",
    "FJ",
    "FM",
    "GB",
    "GD",
    "HT",
    "ID",
    "IE",
    "IS",
    "JM",
    "JP",
    "KI",
    "KM",
    "KN",
    "LC",
    "LK",
    "MG",
    "MH",
    "MT",
    "MU",
    "MV",
    "NR",
    "NZ",
    "PG",
    "PH",
    "PW",
    "SB",
    "SC",
    "SG",
    "ST",
    "TL",
    "TO",
    "TT",
    "TV",
    "TW",
    "VC",
    "VU",
    "WS",
]
LANDLOCKED = [
    "AD",
    "AF",
    "AM",
    "AT",
    "AZ",
    "BF",
    "BI",
    "BO",
    "BT",
    "BW",
    "BY",
    "CF",
    "CH",
    "CZ",
    "ET",
    "HU",
    "KG",
    "KZ",
    "LA",
    "LI",
    "LS",
    "LU",
    "MD",
    "MK",
    "ML",
    "MN",
    "MW",
    "NE",
    "NP",
    "PY",
    "RS",
    "RW",
    "SK",
    "SM",
    "SS",
    "SZ",
    "TD",
    "TJ",
    "TM",
    "UG",
    "UZ",
    "VA",
    "ZM",
    "ZW",
]
# EU 27 + EFTA 4 + UK: Europe Explorer platinum asks for this many European countries.
EU_EFTA_UK_COUNT = 32
LOWER_48_EXCLUDED = {"AK", "HI", "DC"}

ALL = ["ios", "backend"]
IOS = ["ios"]


def parse_swift(text):
    text = re.sub(r"//[^\n]*", "", text)
    countries = re.findall(
        r'Country\(\s*"([A-Z]{2})",\s*"[^"]*",\s*continent:\s*"([^"]+)"', text
    )
    lists = {}
    for m in re.finditer(
        r"static let (\w+): \[StateProvince\] = \[(.*?)\n    \]", text, re.S
    ):
        lists[m.group(1)] = re.findall(r'StateProvince\(\s*"([^"]+)"', m.group(2))
    body = re.search(
        r"static func states\(for countryCode: String\).*?\n    \}", text, re.S
    )
    mapping = dict(re.findall(r'case "([A-Z]{2})": return (\w+)', body.group(0)))
    return dict(countries), {cc: lists[name] for cc, name in mapping.items()}


def tiers(*thresholds):
    """Thresholds bronze→platinum; None = tier not offered."""
    return [
        {"level": level, "threshold": t}
        for level, t in zip(TIER_LEVELS, thresholds)
        if t is not None
    ]


def milestone(threshold):
    # Single-threshold medals are earned once and shown at platinum styling (§4.2).
    return [{"level": "platinum", "threshold": threshold}]


def medal(
    id,
    name,
    description,
    family,
    category,
    metric,
    tier_list,
    icon,
    *,
    filter=None,
    members=None,
    platforms=ALL,
    legacy=None,
    note=None,
):
    m = {
        "id": id,
        "name": name,
        "description": description,
        "family": family,
        "category": category,
        "metric": metric,
        "tiers": tier_list,
        "icon": icon,
        "platforms": platforms,
    }
    if filter:
        m["filter"] = filter
    if members:
        m["members"] = members
    if legacy:
        m["legacyBadgeId"], m["legacyTier"] = legacy
    if note:
        m["note"] = note
    return m


def build():
    country_continents, subdivisions = parse_swift(SWIFT_FILE.read_text())
    for code in ISLAND_NATIONS + LANDLOCKED:
        if code not in country_continents:
            sys.exit(f"country set references unknown country {code}")
    continents = sorted(set(country_continents.values()))
    per_continent = {
        c: sum(1 for v in country_continents.values() if v == c) for c in continents
    }
    us_states = subdivisions["US"]

    M = []
    # Countries
    M += [
        medal(
            "first_steps",
            "First Steps",
            "Visit your first country",
            "countries",
            "countries",
            "countriesVisited",
            milestone(1),
            "figure.walk",
            legacy=("first_steps", "platinum"),
        ),
        medal(
            "explorer_10",
            "Explorer",
            "Visit 5 and then 10 countries",
            "countries",
            "countries",
            "countriesVisited",
            tiers(5, 10),
            "globe.americas",
            legacy=("explorer_10", "silver"),
        ),
        medal(
            "globetrotter_25",
            "Globetrotter",
            "Visit 25 countries",
            "countries",
            "countries",
            "countriesVisited",
            milestone(25),
            "globe",
            legacy=("globetrotter_25", "platinum"),
        ),
        medal(
            "world_traveler_50",
            "World Traveler",
            "Visit 50 countries",
            "countries",
            "countries",
            "countriesVisited",
            milestone(50),
            "airplane",
            legacy=("world_traveler_50", "platinum"),
        ),
        medal(
            "elite_traveler_100",
            "Elite Traveler",
            "Visit 100 countries",
            "countries",
            "countries",
            "countriesVisited",
            milestone(100),
            "crown",
            legacy=("elite_traveler_100", "platinum"),
        ),
        medal(
            "world_champion_150",
            "World Champion",
            "Visit 150 countries",
            "countries",
            "countries",
            "countriesVisited",
            milestone(150),
            "trophy",
            legacy=("world_champion_150", "platinum"),
        ),
        medal(
            "full_atlas",
            "Full Atlas",
            "Visit every country in the world",
            "countries",
            "countries",
            "countriesVisited",
            milestone(len(country_continents)),
            "globe.badge.chevron.backward",
        ),
    ]
    # US states and Canadian provinces
    us = {"country": "US"}
    M += [
        medal(
            "state_starter",
            "State Starter",
            "Visit 5 US states",
            "subdivisions",
            "states",
            "subdivisionsVisited",
            milestone(5),
            "flag",
            filter=us,
        ),
        medal(
            "us_starter",
            "US Starter",
            "Visit 10 US states",
            "subdivisions",
            "states",
            "subdivisionsVisited",
            milestone(10),
            "flag",
            filter=us,
            legacy=("us_starter", "platinum"),
        ),
        medal(
            "road_tripper",
            "Road Tripper",
            "Visit 15 and then 25 US states",
            "subdivisions",
            "states",
            "subdivisionsVisited",
            tiers(15, 25),
            "car",
            filter=us,
        ),
        medal(
            "us_half",
            "Half the States",
            "Visit 25 US states",
            "subdivisions",
            "states",
            "subdivisionsVisited",
            milestone(25),
            "star",
            filter=us,
            legacy=("us_half", "platinum"),
        ),
        medal(
            "coast_to_coast",
            "Coast to Coast",
            "Visit 30 and then 40 US states",
            "subdivisions",
            "states",
            "subdivisionsVisited",
            tiers(30, 40),
            "road.lanes",
            filter=us,
        ),
        medal(
            "us_complete",
            "All 50 States",
            "Visit 50 US states",
            "subdivisions",
            "states",
            "subdivisionsVisited",
            milestone(50),
            "star.fill",
            filter=us,
            legacy=("us_complete", "platinum"),
        ),
        medal(
            "fifty_plus_one",
            "Fifty Plus One",
            "Visit 49, 50 and finally all 50 states plus DC",
            "subdivisions",
            "states",
            "subdivisionsVisited",
            tiers(49, 50, len(us_states)),
            "star.circle.fill",
            filter=us,
        ),
        medal(
            "canada_explorer",
            "Canada Explorer",
            "Visit 5 Canadian provinces",
            "subdivisions",
            "states",
            "subdivisionsVisited",
            milestone(5),
            "leaf.circle",
            filter={"country": "CA"},
            legacy=("canada_explorer", "platinum"),
        ),
        medal(
            "regionalist",
            "Regionalist",
            "Visit states, provinces and regions in any tracked country",
            "subdivisions",
            "regions",
            "subdivisionsVisited",
            tiers(25, 50, 100, 250),
            "map",
        ),
    ]
    # Counties (opt-in layer; hidden on iOS until county places exist)
    for id, name, t in [
        ("county_seat", "County Seat", (10, 25)),
        ("county_hopper", "County Hopper", (50, 100)),
        ("century_counties", "Century Counties", (100, 250)),
        ("county_connoisseur", "County Connoisseur", (250, 500)),
        ("shire_reeve", "Shire Reeve", (500, 1000)),
        (
            "county_royalty",
            "County Royalty",
            (1000, 2000, sum(n for _, n in COUNTY_STATES.values())),
        ),
    ]:
        M.append(
            medal(
                id,
                name,
                f"Visit {' / '.join(f'{x:,}' for x in t)} US counties",
                "counties",
                "states",
                "countiesVisited",
                tiers(*t),
                "square.grid.3x3.square",
            )
        )
    # Cities & capitals (device-only: matched from visit and photo coordinates)
    M += [
        medal(
            "city_slicker",
            "City Slicker",
            "Visit 10 and then 25 cities",
            "cities",
            "special",
            "citiesVisited",
            tiers(10, 25),
            "building.2",
            platforms=IOS,
        ),
        medal(
            "urban_explorer",
            "Urban Explorer",
            "Visit 50 and then 100 cities",
            "cities",
            "special",
            "citiesVisited",
            tiers(50, 100),
            "building.2.crop.circle",
            platforms=IOS,
        ),
        medal(
            "metropolis",
            "Metropolis",
            "Visit 250, 500 and 1,000 cities",
            "cities",
            "special",
            "citiesVisited",
            tiers(250, 500, 1000),
            "building.columns.circle",
            platforms=IOS,
        ),
        medal(
            "capital_gains",
            "Capital Gains",
            "Visit national capitals",
            "cities",
            "special",
            "capitalsVisited",
            tiers(5, 15, 30, 50),
            "building.columns",
            filter={"kind": "national"},
            platforms=IOS,
        ),
        medal(
            "capital_collector",
            "Capital Collector",
            "Visit 75 to 195 national capitals",
            "cities",
            "special",
            "capitalsVisited",
            tiers(75, 100, 150, 195),
            "building.columns.fill",
            filter={"kind": "national"},
            platforms=IOS,
        ),
        medal(
            "state_capital_circuit",
            "State Capital Circuit",
            "Visit US state capitals",
            "cities",
            "special",
            "capitalsVisited",
            tiers(10, 25, 40, len(us_states)),
            "star.square",
            filter={"kind": "us_state"},
            platforms=IOS,
        ),
    ]
    # Named regions (Phase 4 data; hidden until region places exist)
    M += [
        medal(
            "metro_pass",
            "Metro Pass",
            "Visit named regions",
            "regions",
            "regions",
            "regionsVisited",
            tiers(3, 5, 10),
            "tram",
        ),
        medal(
            "region_hopper",
            "Region Hopper",
            "Visit 15 to 80 named regions",
            "regions",
            "regions",
            "regionsVisited",
            tiers(15, 25, 40, 80),
            "point.3.connected.trianglepath.dotted",
        ),
    ]
    # Continents
    M += [
        medal(
            "europe_explorer",
            "Europe Explorer",
            "Visit European countries",
            "continents",
            "continents",
            "continentCountries",
            tiers(10, 20, 30, EU_EFTA_UK_COUNT),
            "building.columns",
            filter={"continents": "Europe"},
            legacy=("europe_explorer", "bronze"),
        ),
        medal(
            "asia_adventurer",
            "Asia Adventurer",
            "Visit Asian countries",
            "continents",
            "continents",
            "continentCountries",
            tiers(10, 20, 30, 40),
            "building.2",
            filter={"continents": "Asia"},
            legacy=("asia_adventurer", "bronze"),
        ),
        medal(
            "africa_safari",
            "African Safari",
            "Visit African countries",
            "continents",
            "continents",
            "continentCountries",
            tiers(10, 20, 30, 40),
            "leaf",
            filter={"continents": "Africa"},
            legacy=("africa_safari", "bronze"),
        ),
        medal(
            "americas_explorer",
            "Americas Explorer",
            "Visit countries in the Americas",
            "continents",
            "continents",
            "continentCountries",
            tiers(10, 15, 20, 25),
            "mountain.2",
            filter={"continents": "North America,South America"},
            legacy=("americas_explorer", "bronze"),
        ),
        medal(
            "oceania_hopper",
            "Island Hopper",
            "Visit Oceania countries",
            "continents",
            "continents",
            "continentCountries",
            tiers(5, 8, 12, 14),
            "water.waves",
            filter={"continents": "Oceania"},
            legacy=("oceania_hopper", "bronze"),
        ),
        medal(
            "all_continents",
            "Continental Master",
            "Visit 3, 5, 6 and all 7 continents",
            "continents",
            "continents",
            "continentsTouched",
            tiers(3, 5, 6, 7),
            "globe.europe.africa",
            legacy=("all_continents", "gold"),
            note="Antarctica counts from a visit or photo south of 60°S.",
        ),
    ]
    # Completionist sets
    for state, (fips, count) in sorted(COUNTY_STATES.items()):
        M.append(
            medal(
                f"complete_counties_{state.lower()}",
                f"{state} Complete",
                f"Visit every county in {state}",
                "completionist",
                "states",
                "countiesInState",
                milestone(count),
                "checkmark.seal",
                filter={"state": state},
            )
        )
    lower48 = [s for s in us_states if s not in LOWER_48_EXCLUDED]
    M += [
        medal(
            "lower_48",
            "Lower 48",
            "Visit all 48 contiguous US states",
            "completionist",
            "states",
            "subdivisionSet",
            milestone(len(lower48)),
            "flag.2.crossed",
            filter={"country": "US"},
            members=lower48,
        ),
        medal(
            "canada_complete",
            "True North Strong",
            "Visit all Canadian provinces and territories",
            "completionist",
            "states",
            "subdivisionsVisited",
            milestone(len(subdivisions["CA"])),
            "maple.leaf",
            filter={"country": "CA"},
            legacy=("canada_complete", "platinum"),
        ),
        medal(
            "hexagone",
            "Hexagone",
            "Visit every French department",
            "completionist",
            "special",
            "subdivisionsVisited",
            milestone(len(subdivisions["FR"])),
            "seal",
            filter={"country": "FR"},
        ),
        medal(
            "land_of_the_rising_sun",
            "Land of the Rising Sun",
            "Visit all Japanese prefectures",
            "completionist",
            "special",
            "subdivisionsVisited",
            milestone(len(subdivisions["JP"])),
            "sun.horizon",
            filter={"country": "JP"},
        ),
        medal(
            "home_turf",
            "Home Turf",
            "Visit every subdivision of your home country",
            "completionist",
            "special",
            "homeCountryCompletion",
            milestone(100),
            "house",
            note="Home is the tracked country where you have visited the most subdivisions.",
        ),
    ]
    for continent in continents:
        M.append(
            medal(
                f"full_atlas_{continent.lower().replace(' ', '_')}",
                f"Full Atlas: {continent}",
                f"Visit every country in {continent}",
                "completionist",
                "continents",
                "continentCountries",
                milestone(per_continent[continent]),
                "globe.desk",
                filter={"continents": continent},
            )
        )
    # Distance (device-only; accumulates from the visit pipeline's track)
    distance_note = "Counts distance recorded since automatic tracking was turned on."
    M += [
        medal(
            "wanderer",
            "Wanderer",
            "Travel 1,000 km",
            "distance",
            "special",
            "distanceKm",
            milestone(1000),
            "figure.hiking",
            platforms=IOS,
            note=distance_note,
        ),
        medal(
            "voyager",
            "Voyager",
            "Travel 5,000 and then 10,000 km",
            "distance",
            "special",
            "distanceKm",
            tiers(5000, 10000),
            "ferry",
            platforms=IOS,
            note=distance_note,
        ),
        medal(
            "around_the_world",
            "Around the World",
            "Travel around the Earth and to the Moon",
            "distance",
            "special",
            "distanceKm",
            tiers(25000, 40075, 100000, 384400),
            "moon.stars",
            platforms=IOS,
            note=distance_note,
        ),
    ]
    # Streaks & cadence
    M += [
        medal(
            "monthly_explorer",
            "Monthly Explorer",
            "A new place every calendar month in a row",
            "streaks",
            "special",
            "newPlaceStreakMonths",
            tiers(3, 6, 12, 24),
            "calendar",
        ),
        medal(
            "weekly_wanderer",
            "Weekly Wanderer",
            "A new place every week in a row",
            "streaks",
            "special",
            "newPlaceStreakWeeks",
            tiers(4, 8, 12, 26),
            "calendar.badge.clock",
        ),
        medal(
            "regular_explorer",
            "Regular Explorer",
            "Discover new places in 2 to 10 different years",
            "streaks",
            "special",
            "distinctYearsActive",
            tiers(2, 3, 5, 10),
            "repeat",
        ),
        medal(
            "decade_of_footprints",
            "Decade of Footprints",
            "5 and then 10 years between first and latest visit",
            "streaks",
            "special",
            "yearsSpan",
            tiers(5, 10),
            "hourglass",
        ),
    ]
    # Time zones
    M += [
        medal(
            "time_zone_master",
            "Time Zone Master",
            "Visit 6, 12 and 18 time zones",
            "timezones",
            "special",
            "timeZonesVisited",
            tiers(6, 12, 18),
            "clock",
            legacy=("time_zone_master", "silver"),
        ),
        medal(
            "all_time_zones",
            "Around the Clock",
            "Visit all 24 time zones",
            "timezones",
            "special",
            "timeZonesVisited",
            milestone(24),
            "clock.badge.checkmark",
            legacy=("all_time_zones", "platinum"),
        ),
        # The zone tables reach UTC−10 (Hawaii) in the west, so the far side of the date line starts there.
        medal(
            "date_line_crosser",
            "Date Line Crosser",
            "Visit both UTC+12 or beyond and UTC−10 or beyond",
            "timezones",
            "special",
            "dateLineCrossed",
            milestone(1),
            "arrow.left.and.right",
            filter={"east": "12", "west": "-10"},
            # The backend credits a country with all of its zones (US → UTC−10), so only the
            # device, which counts zones per visited state, can tell.
            platforms=IOS,
        ),
    ]
    # Novelty / geography (device-only: from visit and photo coordinates)
    M += [
        medal(
            "four_hemispheres",
            "Four Hemispheres",
            "Visit the northern, southern, eastern and western hemispheres",
            "novelty",
            "special",
            "hemispheresTouched",
            milestone(4),
            "circle.grid.cross",
            platforms=IOS,
        ),
        medal(
            "equator_crosser",
            "Equator Crosser",
            "Visit both sides of the equator",
            "novelty",
            "special",
            "hemispheresTouched",
            milestone(2),
            "arrow.up.and.down",
            filter={"axis": "lat"},
            platforms=IOS,
        ),
        medal(
            "meridian_split",
            "Meridian Split",
            "Visit both sides of the prime meridian",
            "novelty",
            "special",
            "hemispheresTouched",
            milestone(2),
            "arrow.left.and.right.circle",
            filter={"axis": "lon"},
            platforms=IOS,
        ),
        medal(
            "on_the_equator",
            "On the Equator",
            "Visit within 0.5° of the equator",
            "novelty",
            "special",
            "coordinateInBand",
            milestone(1),
            "circle.and.line.horizontal",
            filter={"minLat": "-0.5", "maxLat": "0.5"},
            platforms=IOS,
        ),
        medal(
            "polar_explorer",
            "Polar Explorer",
            "Visit north of the Arctic Circle",
            "novelty",
            "special",
            "coordinateInBand",
            milestone(1),
            "snowflake",
            filter={"minLat": "66.56"},
            platforms=IOS,
        ),
        medal(
            "southern_cross",
            "Southern Cross",
            "Visit south of the Tropic of Capricorn",
            "novelty",
            "special",
            "coordinateInBand",
            milestone(1),
            "sparkles",
            filter={"maxLat": "-23.44"},
            platforms=IOS,
        ),
        medal(
            "island_nations",
            "Island Nations",
            "Visit 5, 10 and 20 island nations",
            "novelty",
            "special",
            "countriesInSet",
            tiers(5, 10, 20),
            "beach.umbrella",
            filter={"set": "island_nations"},
        ),
        medal(
            "landlocked",
            "Landlocked",
            "Visit 5 landlocked countries",
            "novelty",
            "special",
            "countriesInSet",
            milestone(5),
            "mountain.2.circle",
            filter={"set": "landlocked"},
        ),
    ]
    # Bucket list (v1; device-only: needs the on-device bucket-list ledger)
    M += [
        medal(
            "bucket_list_5",
            "Dream Chaser",
            "Check off 5 places from your bucket list",
            "streaks",
            "special",
            "bucketListCompleted",
            milestone(5),
            "checklist",
            platforms=IOS,
            legacy=("bucket_list_5", "platinum"),
            note="Counts bucket-list places visited since medals v2.",
        ),
        medal(
            "bucket_list_25",
            "Dream Achiever",
            "Check off 25 places from your bucket list",
            "streaks",
            "special",
            "bucketListCompleted",
            milestone(25),
            "checklist.checked",
            platforms=IOS,
            legacy=("bucket_list_25", "platinum"),
            note="Counts bucket-list places visited since medals v2.",
        ),
    ]

    ids = [m["id"] for m in M]
    assert len(ids) == len(set(ids)), "duplicate medal ids"
    for m in M:
        ts = [t["threshold"] for t in m["tiers"]]
        assert ts == sorted(ts) and len(set(ts)) == len(ts), (
            f"{m['id']}: tiers must increase"
        )
    return {
        "catalogVersion": CATALOG_VERSION,
        "tierLevels": TIER_LEVELS,
        "subdivisionRegionTypes": SUBDIVISION_REGION_TYPES,
        "countyRegionType": COUNTY_REGION_TYPE,
        "namedRegionRegionType": NAMED_REGION_TYPE,
        "countryContinents": dict(sorted(country_continents.items())),
        "subdivisionCounts": {
            cc: len(codes) for cc, codes in sorted(subdivisions.items())
        },
        "countrySets": {
            "island_nations": sorted(ISLAND_NATIONS),
            "landlocked": sorted(LANDLOCKED),
        },
        "countyStates": {
            s: {"fips": f, "count": n} for s, (f, n) in sorted(COUNTY_STATES.items())
        },
        "medals": M,
    }


def render():
    return json.dumps(build(), ensure_ascii=False, indent=1) + "\n"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument(
        "--check", action="store_true", help="fail if a generated copy is stale"
    )
    args = ap.parse_args()
    text = render()
    stale = [
        p for p in OUTPUTS if not p.exists() or p.read_text(encoding="utf-8") != text
    ]
    if args.check:
        for p in stale:
            print(f"stale: {p.relative_to(ROOT)} (run scripts/build_medals_catalog.py)")
        sys.exit(1 if stale else 0)
    for p in OUTPUTS:
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_text(text, encoding="utf-8")
    print(f"{len(build()['medals'])} medals written to {len(OUTPUTS)} copies")


if __name__ == "__main__":
    main()
