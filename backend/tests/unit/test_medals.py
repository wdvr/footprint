"""Medals v2: catalog parity with iOS, shared fixture history, evaluation rules."""

import json
import subprocess
import sys
from datetime import UTC, datetime
from pathlib import Path

from src.models.badges import BADGES_BY_ID
from src.services.medals import CATALOG_PATH, evaluate, load_catalog

ROOT = Path(__file__).resolve().parents[3]
IOS_CATALOG = ROOT / "ios/Footprint/Resources/medals.json"
FIXTURE = ROOT / "ios/FootprintTests/Fixtures/medal_fixture_history.json"

V1_BADGES = {
    "first_steps",
    "explorer_10",
    "globetrotter_25",
    "world_traveler_50",
    "elite_traveler_100",
    "world_champion_150",
    "europe_explorer",
    "asia_adventurer",
    "africa_safari",
    "americas_explorer",
    "oceania_hopper",
    "all_continents",
    "us_starter",
    "us_half",
    "us_complete",
    "canada_explorer",
    "canada_complete",
    "time_zone_master",
    "all_time_zones",
    "bucket_list_5",
    "bucket_list_25",
}


def place(code, date, region_type="country", **extra):
    return {
        "region_type": region_type,
        "region_code": code,
        "region_name": code,
        "status": "visited",
        "visit_type": "visited",
        "is_deleted": False,
        "visited_date": date,
        **extra,
    }


def by_id(results):
    return {r.definition["id"]: r for r in results}


class TestCatalogParity:
    def test_backend_and_ios_copies_are_identical(self):
        assert CATALOG_PATH.read_bytes() == IOS_CATALOG.read_bytes()

    def test_copies_match_generator(self):
        script = ROOT / "scripts/build_medals_catalog.py"
        result = subprocess.run(
            [sys.executable, str(script), "--check"], capture_output=True, text=True
        )
        assert result.returncode == 0, result.stdout + result.stderr

    def test_every_v1_badge_is_preserved_with_its_id(self):
        medals = {m["id"]: m for m in load_catalog()["medals"]}
        assert {m.get("legacyBadgeId") for m in medals.values()} - {None} == V1_BADGES
        for badge_id in V1_BADGES:
            medal = medals[badge_id]
            assert medal["legacyBadgeId"] == badge_id
            assert medal["legacyTier"] in [t["level"] for t in medal["tiers"]]

    def test_tiers_increase(self):
        for medal in load_catalog()["medals"]:
            thresholds = [t["threshold"] for t in medal["tiers"]]
            assert thresholds == sorted(set(thresholds)), medal["id"]

    def test_device_only_medals_are_not_served(self):
        assert "capital_gains" not in BADGES_BY_ID
        assert "wanderer" not in BADGES_BY_ID
        assert "first_steps" in BADGES_BY_ID


class TestSharedFixture:
    def test_fixture_history_produces_expected_medals_and_dates(self):
        fixture = json.loads(FIXTURE.read_text(encoding="utf-8"))
        results = [
            r
            for r in evaluate(fixture["places"])
            if r.definition["family"] not in fixture["excludedFamilies"]
        ]
        actual = {
            r.definition["id"]: [
                {
                    "level": a.level,
                    "earnedAt": a.earned_at.strftime("%Y-%m-%dT%H:%M:%SZ"),
                    "trigger": a.trigger,
                }
                for a in r.awards
            ]
            for r in results
        }
        assert actual == fixture["expected"]
        assert sum(1 for v in fixture["expected"].values() if v) >= 10


class TestEvaluation:
    def test_retroactive_tiers_use_crossing_dates(self):
        codes = ["FR", "DE", "NL", "BE", "IT", "ES", "PT", "AT", "CH", "PL"]
        places = [
            place(c, f"2020-01-{i + 1:02d}T00:00:00Z") for i, c in enumerate(codes)
        ]
        explorer = by_id(evaluate(places))["explorer_10"]
        assert [a.level for a in explorer.awards] == ["bronze", "silver"]
        assert explorer.awards[0].earned_at == datetime(2020, 1, 5, tzinfo=UTC)
        assert explorer.awards[1].earned_at == datetime(2020, 1, 10, tzinfo=UTC)
        assert explorer.awards[1].trigger == "PL"

    def test_transit_bucket_list_and_deleted_do_not_count(self):
        places = [
            place("FR", "2020-01-01"),
            place("DE", "2020-01-02", visit_type="transit"),
            place("NL", None, status="bucket_list"),
            place("BE", "2020-01-03", is_deleted=True),
        ]
        assert by_id(evaluate(places))["full_atlas"].value == 1

    def test_duplicate_place_counts_once_at_earliest_date(self):
        places = [place("FR", "2022-01-01"), place("FR", "2019-06-01")]
        first = by_id(evaluate(places))["first_steps"]
        assert first.value == 1
        assert first.awards[0].earned_at == datetime(2019, 6, 1, tzinfo=UTC)

    def test_undated_places_fall_back_to_marked_at(self):
        places = [place("FR", None, marked_at="2021-03-04T05:06:07Z")]
        first = by_id(evaluate(places))["first_steps"]
        assert first.awards[0].earned_at == datetime(2021, 3, 4, 5, 6, 7, tzinfo=UTC)

    def test_place_without_any_date_counts_without_a_date(self):
        first = by_id(evaluate([place("FR", None)]))["first_steps"]
        assert first.awards[0].earned_at is None

    def test_simple_sync_places_fall_back_to_created_at(self):
        places = [place("FR", None, created_at="2025-02-03T04:05:06+00:00")]
        first = by_id(evaluate(places))["first_steps"]
        assert first.awards[0].earned_at == datetime(2025, 2, 3, 4, 5, 6, tzinfo=UTC)

    def test_undated_places_do_not_stretch_the_travel_span(self):
        places = [place("FR", None), place("DE", "2024-06-01T00:00:00Z")]
        results = by_id(evaluate(places))
        assert results["decade_of_footprints"].value == 0
        assert results["regular_explorer"].value == 1
        assert results["full_atlas"].value == 2

    def test_weekly_streak_crosses_year_boundary(self):
        days = ["2024-12-23", "2024-12-30", "2025-01-06", "2025-01-13"]
        places = [
            place(c, d) for c, d in zip(["FR", "DE", "NL", "BE"], days, strict=True)
        ]
        weekly = by_id(evaluate(places))["weekly_wanderer"]
        assert weekly.value == 4
        assert weekly.awards[0].earned_at == datetime(2025, 1, 13, tzinfo=UTC)

    def test_counties_in_state_use_fips_prefix(self):
        places = [
            place(f, "2023-01-01", region_type="us_county")
            for f in ["44001", "44003", "44005", "44007", "44009"]
        ]
        results = by_id(evaluate(places))
        assert results["complete_counties_ri"].awards
        assert not results["complete_counties_ct"].awards

    def test_progress_total_is_next_tier(self):
        places = [place(c, "2020-01-01") for c in ["FR", "DE", "NL", "BE", "IT"]]
        explorer = by_id(evaluate(places))["explorer_10"]
        assert explorer.progress_total == 10
