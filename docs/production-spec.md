# Footprint — Production Spec

**Date:** 2026-11-26 · **Repo:** `wdvr/footprint` · **Audience:** Wouter (owner) and the Devin sessions implementing this in phases.
**Status of this document:** implementation spec. Every phase ends in a PR under the standing rules: Devin never merges its own PRs; a PR is assigned to @wdvr only when CI is green AND Devin Review is green.

---

## 0. Grounding: what already exists (verified in the repo, 2026-11-26)

Footprint is not a greenfield app. It is live on the App Store (App Store id 6758334183, footprintmaps.com) and already does more than this spec's title implies. The spec below builds on these verified facts:

| Area | What exists today |
|---|---|
| Stack | iOS: Swift 6, SwiftUI, SwiftData, MapKit, iOS 17+. Backend: Python 3.11 FastAPI on AWS Lambda, DynamoDB single-table, Pulumi infra. Auth: Sign in with Apple + Google OAuth. An `android/` app also exists in the repo (out of scope for this spec, see Open Questions). |
| Countries | `GeographicData.countries`: 195 UN member states with continent. Bundled `countries.geojson` (2.5 MB) with point-in-polygon matching. |
| Subdivisions | 17 countries have subdivision lists in `GeographicData` and (for 11+ of them) bundled GeoJSON: US 51 (50+DC), CA 13, FR 101 (departments), IT 110, GB 229 (council areas), JP 47, KR 17, NO 15, plus AU, MX, BR, DE, ES, NL, BE, RU, AR. `VisitedPlace.RegionType` has a case per subdivision kind. |
| Visits (place level) | SwiftData `@Model VisitedPlace`: `regionType` (String), `regionCode`, `regionName`, `status` (visited / bucket_list), `visitType` (visited / transit), `visitedDate`, `departureDate`, notes, soft delete, and sync fields (`syncVersion`, `lastModifiedAt`, `isSynced`). |
| Background location | `LocationManager`: `CLLocationManager`, significant-location-change monitoring for background, 100 m desired accuracy, 1 km distance filter, `pausesLocationUpdatesAutomatically`. Callbacks `onCountryDetected` / `onStateDetected` / `onCityDetected` already exist; new-place events fire a local notification via `PushNotificationManager`. |
| Offline matching | `GeoLocationMatcher`: on-device point-in-polygon over the bundled GeoJSON, currently used as a fallback when `CLGeocoder` fails. Covers countries and subdivisions of US, CA, RU, FR, DE, ES, IT, NL, BE, GB, AR. |
| Photo import | `PhotoImportManager` (71 KB, the largest service) + `PhotoLocation` model: derives visited countries/states from photo GPS, with a memories UI. |
| Cities data | `Resources/GeoData/world_cities.json` (179 KB) and `world_landmarks.json` (356 KB) are bundled. **Assumption (unverified):** no Swift references to `world_cities` were found by code search; the files may be unused or consumed indirectly. Phase 3 must verify before building on them. Research notes exist in `data/cities_research.md`. |
| Stats | `Statistics.swift`: `CountryCoverage` (per-country subdivision %), `ContinentStats`, `TimeZoneStats` (24-zone model; multi-zone countries count only the zones of subdivisions actually visited — semantics fixed by PR #121), `ExtendedStats`, friends `LeaderboardEntry`. |
| Badges (v1) | A working badge system exists, defined server-side in `backend/src/models/badges.py` and mirrored as DTOs in iOS `Statistics.swift` (`Badge`, `BadgeProgress`, `BadgesResponse`). Verified catalog entries include: First Steps (1 country), Explorer (10), Globetrotter (25), World Traveler (50), Elite Traveler (100), World Champion (150); Europe Explorer / Asia Adventurer / African Safari / Americas Explorer (10 continent countries each), Island Hopper (5 Oceania). Properties of v1: one threshold per badge (no tiers), evaluated server-side from synced stats, categories = countries / regions / continents / special / states. **Assumption:** the tail of `badges.py` (states/special badges) was not read line-by-line; Phase 5 inventories the full catalog before replacing it. |
| Sync | Custom backend sync: `SyncManager` + `APIClient`, last-write-wins via `syncVersion`/`lastModifiedAt`, soft deletes. This is **not** CloudKit today (see §5.4 and Open Questions). |
| Tests | `FootprintTests` target: GeographicDataTests, StatisticsTests, GeoJSONParserTests, LocationManagerTests (thin, ~1 KB), PhotoImportTests, SyncManagerTests, APIClientTests, TokenRefreshTests, LocalizationTests, MapViewTests, YearInReviewTests, AccountResetTests. Backend has pytest (`backend/tests`, incl. `test_badges.py`). |
| CI / release | `.github/workflows/ci.yml`, `ios-build.yml`, `ios-testflight-internal.yml`, `ios-testflight-external.yml`, `ios-app-store-release.yml`, `monitor-testflight-external.yml`. iOS CI runs on the self-hosted Mac runner (the same runner whose queue PR #121's CI waited in). |
| Known data defect | PR #121 documents that `GB_states.geojson` contains 3 feature codes (`WRL`, `CKT`, `SHN`) absent from `GeographicData.ukCouncilAreas`. No test covers it. Fixed in Phase 0. |
| Prior art in-repo | `IDEAS.md` already scopes: per-country coverage %, timeline playback (shipped: `TimelinePlaybackView`), cities & landmarks incl. capitals (issue #18), national parks (#40), UNESCO sites (#46), challenges & streaks, furthest-point and hemisphere stats. This spec absorbs those where they overlap. |

**What does not exist yet** (the actual gaps this spec closes):

1. No US counties anywhere: no data, no `RegionType`, no coverage, no medals. ("County" in the codebase means Norwegian counties only.)
2. No city-level tracking: `LocationManager` can name the current city, but there is no city `RegionType`, no city visit record, no gazetteer-driven matching, no capitals.
3. No "regions" in the metro / named-area sense (Bay Area, Provence, New England…).
4. No raw location history: the app stores place-level records only. There is no `Visit` event log and no `LocationSample` store, so dwell time, distance travelled, streaks, and retroactive re-derivation are impossible today.
5. Badges v1 has no tiers, no county/city/streak/distance families, and is evaluated on the server, so it cannot award offline or retroactively with correct dates.
6. Visit detection is notification-grade, not record-grade: significant-change pings + geocoder, with no dwell/accuracy rules deciding what counts as a visit vs a drive-through.
7. CI trust is shaky: PR #121 exists precisely because tests went stale against intentional data changes and nobody noticed until assertions failed in 4 methods at once.

---

## 1. Product goal

Footprint, production-ready: the app **silently and automatically** records where you have been and turns that history into (a) coverage you can read at every geographic level — country, subdivision, county, city, region — and (b) a collectible medal cabinet that rewards real exploration.

Non-negotiables:

- **Zero user action for capture.** After onboarding (permissions + optional photo import), the user never has to open the app, check in, or confirm a place for it to be recorded. Manual marking stays available as an override, not the mechanism.
- **On-device first.** Raw location never leaves the phone. Only place-level results (which county/city/… you visited, and when) sync, and only with the user's sync consent (§6.2).
- **No data loss, ever** (the repo's own vision statement). Every derived record must be re-derivable from stored evidence; every migration must be lossless and tested.
- **Correct over clever.** A missed county is a bug; a phantom county from a GPS glitch is a worse bug. Thresholds in §3.3 are tuned for precision first.

Definition of "production-ready" for this spec: §6's readiness bar met, Phase 0–7 acceptance criteria green, and the app passing a 14-day background-capture field test on the owner's phone with ≥98% of known visits captured and ≤1% battery/day attributable (§5.1).

---

## 2. Geographic hierarchy

### 2.1 Levels

One flat place registry, five levels plus two special collections. Every place has a stable string key.

| Level | Key format | Denominator (v1) | Source of truth |
|---|---|---|---|
| Country | ISO 3166-1 alpha-2 (`US`) | 195 | `GeographicData.countries` (exists) |
| Subdivision | `CC-CODE` (`US-CA`, `FR-75`) | per country, 17 countries at spec time | `GeographicData` lists + bundled GeoJSON (exists) |
| County | US FIPS 5-digit (`06001`) | 3,143 US counties & equivalents (incl. DC, PR municipios; AK boroughs/census areas, LA parishes, VA independent cities) | New: Census TIGER county polygons (§2.2) |
| City | GeoNames id (`gn:5391959`) | Curated gazetteer: all national capitals + all cities ≥100k population + all US places ≥25k (≈4,500 places v1) | New gazetteer built from `world_cities.json` (verify) + GeoNames |
| Region | slug (`us-bay-area`) | Curated v1 set: ~40 US + ~40 international named regions and metro areas (§2.4) | New curated dataset, defined as member place keys |
| Capital (collection) | — | 195 national capitals; 51 US state capitals (incl. DC); subdivision capitals where the gazetteer carries them | `isCapital` flags in the gazetteer |
| Landmark (collection) | slug | `world_landmarks.json` (bundled; inventory in Phase 3) | Exists as data; no tracking yet |

`VisitedPlace` is extended, not replaced: `regionType` is already a `String`, so new cases are additive and migration-free for existing rows.

New `RegionType` cases: `.usCounty = "us_county"`, `.city = "city"`, `.region = "region"` (metro/named), `.landmark = "landmark"`. Key formats above go in `regionCode`; display name in `regionName` as today.

### 2.2 County data (new)

- Source: US Census Bureau TIGER/Line `cb_2024_us_county_500k` (cartographic boundary, generalized). License: public domain.
- Build-time pipeline (script in `data/` or `scripts/`, output committed like the existing GeoJSON): simplify to ≤0.0005° tolerance, split per state into `GeoData/counties/US-<STATE>.geojson` (51 files, target ≤250 KB each, ≤6 MB total), plus `counties_index.json` (FIPS → name, state, land area km², centroid, bbox).
- Runtime loading is per-state lazy: only the states the user is in or has visited get parsed; parsed polygons cached in memory with an LRU of 4 states.
- Matching uses the same point-in-polygon core as `GeoLocationMatcher`, fronted by a bbox/geohash pre-filter so a fix tests ≤ a few dozen polygons, never 3,143.
- County equivalents are counties for all spec purposes (parishes, boroughs, independent cities, municipios). The UI label is "Counties" with the local term shown on the state page (e.g., "64 parishes" for Louisiana).

### 2.3 City gazetteer (new)

`City` record (bundled JSON, generated at build time, versioned):

```swift
struct City: Codable, Identifiable {
    let id: String            // "gn:5391959"
    let name: String
    let countryCode: String   // "US"
    let subdivisionCode: String? // "US-CA"
    let countyFips: String?   // "06001" (US only at v1)
    let lat: Double; let lon: Double
    let radiusMeters: Double  // match radius: f(population), clamp 1.5–15 km
    let population: Int
    let isNationalCapital: Bool
    let isSubdivisionCapital: Bool
    let timeZone: String      // IANA id, for §4 stats
}
```

- A city visit = the user's confirmed stay-point (§3) falls within `radiusMeters` of the centroid **and** (where a county/subdivision match exists) is consistent with it. Radius matching, not municipal polygons, at v1: municipal boundary data is inconsistent worldwide; centroids + population-scaled radius are predictable and testable. (Polygon upgrade is a post-v1 option; see Open Questions.)
- Capitals are flags, not a separate dataset, so "capital cities visited" is a filter, not a feature.

### 2.4 Regions (new)

"Region" in this spec means a **named area that is not an administrative unit**: metro areas and cultural/geographic regions people actually say ("the Bay Area", "Silicon Valley", "New England", "the Cotswolds", "Provence", "the Alps", "Tuscany", "the Outback").

Representation: a region is a **set of member place keys** (counties and/or subdivisions and/or cities), not a polygon. A region is visited when ≥1 member is visited; region coverage = visited members / total members. This reuses all existing matching and survives boundary disputes.

```swift
struct NamedRegion: Codable, Identifiable {
    let id: String                 // "us-bay-area"
    let name: String               // "San Francisco Bay Area"
    let kind: Kind                 // .metro | .cultural | .geographic
    let memberKeys: [String]       // regionCodes: FIPS, "CC-CODE", or city ids
    let blurb: String              // one line, shown on the region page
}
```

V1 set (ship ~80; the dataset is data, not code, so it grows without releases): US metros (top 25 by population, defined by their Census CBSA county lists), US cultural regions (New England = CT/MA/ME/NH/RI/VT subdivisions; the South, Midwest etc. are too coarse — skip), plus hand-picked: Silicon Valley (Santa Clara + San Mateo + Alameda + San Francisco counties), Bay Area (9 counties), Wine Country (Napa + Sonoma), Lake Tahoe (El Dorado, Placer, Nevada, Douglas, Washoe, Carson City), Death Valley, Cape Cod (Barnstable), the Hamptons (Suffolk NY), Provence (FR departments 04/05/06/13/83/84), Tuscany (IT subdivisions), the Cotswolds, Bavaria (DE-BY), Catalonia (ES-CT), the Alps (cross-border subdivision set), Flanders (BE), the Randstad (NL), Kansai + Kanto (JP), the Outback — final list is a data PR in Phase 4, reviewed against this definition.

### 2.5 Coverage model

Coverage is always **count and, where area data exists, land-area share**, shown together:

- World: countries visited / 195; % of world land area (country areas computed from `countries.geojson` at build time, stored in `GeographicData` as `landAreaKm2` — new field, additive).
- Country page: subdivisions visited / total (exists as `CountryCoverage`); for the US additionally counties / 3,143 and % of US land area; cities visited from the gazetteer within that country.
- US page: states 51, counties with per-state breakdown (count + %), state completion list.
- City coverage is always expressed against the gazetteer denominator ("38 of 195 capitals", "112 of ~4,500 cities"), never as a bare count alone.
- Region page: member checklist with visited state, coverage ring.

Transit rule (existing `visitType`): a place passed through below the dwell threshold (§3.3) is recorded as `transit`. Transit places show on maps in the transit style, count toward "passed through" lists, and **do not** count toward coverage percentages or medals unless a medal explicitly says so. This preserves the meaning of the existing data: today's `VisitedPlace` rows have no dwell evidence, so on migration they are `visited` (grandfathered, §4.4).

### 2.6 Maps and lists per level

- **World map** (exists): country choropleth; add area-% toggle.
- **Country map** (exists for subdivisions): subdivision choropleth with coverage-intensity shading (absorbs IDEAS.md #2 heat rule: light = 1, saturated ≥50%).
- **US county map** (new): state picker → county choropleth, visited / transit / unvisited, tap a county for name, first-visit date, visit count.
- **City layer** (new): pins on country/world map for gazetteer cities, filled = visited; capital pins get a star.
- **Region pages** (new): member checklist map + list.
- **Lists**: every level gets a searchable list view with three segments (Visited / Transit / Not yet), each row showing first-visit date and visit count where known. Lists and maps are two renderings of the same query; no list-only or map-only places.

---

## 3. Visit detection (the automation core)

### 3.1 Evidence model (new data)

Place records alone cannot support dwell, distance, or streaks. Two new SwiftData models:

```swift
@Model final class LocationSample {          // raw evidence, on-device only, NEVER synced
    var id: UUID
    var timestamp: Date
    var latitude: Double; var longitude: Double
    var horizontalAccuracy: Double            // meters
    var source: SampleSource                  // .gps | .photo | .manual
    var processedAt: Date?                    // nil = pending pipeline
}

@Model final class Visit {                    // a confirmed stay, derived from samples
    var id: UUID
    var arrivedAt: Date; var departedAt: Date?  // nil = ongoing
    var centroidLat: Double; var centroidLon: Double
    var sampleCount: Int
    var source: SampleSource
    // resolved places (denormalized keys, filled by the matcher)
    var countryCode: String?
    var subdivisionCode: String?              // "US-CA"
    var countyFips: String?
    var cityId: String?
    var regionIds: [String]                   // derived from members; cached
}
```

`VisitedPlace` remains the user-facing, synced record ("you have visited X, first on date D, N times"). `Visit` is the evidence ledger it is derived from: one `VisitedPlace` per place key, `visitedDate` = earliest confirmed `Visit.arrivedAt`, plus a new additive field `visitCount: Int = 1`.

Retention: `LocationSample` rows are kept rolling **13 months** on-device (enough for streaks, distance, and re-derivation), then deleted by a monthly maintenance task; `Visit` rows are kept forever (they are small and are the audit trail). Samples never sync (§6.2). Photo-derived visits come from `PhotoImportManager` writing `Visit` rows with `source = .photo` and the photo's timestamp/coordinate.

### 3.2 Capture pipeline

State machine, all on-device, no user action:

```
samples ──▶ stay-point clustering ──▶ candidate visit ──▶ dwell/accuracy gate ──▶ confirmed Visit
                                            │                                        │
                                            └── below gate ──▶ transit record      ▼
                                                              matcher (country→subdivision→county→city→regions)
                                                                                     │
                                                              VisitedPlace upsert + medal evaluation (§4.3)
```

- **Clustering:** a stay-point is a maximal run of samples within a 200 m radius spanning ≥5 minutes. Implemented as a pure function over `[LocationSample]` (unit-testable without CoreLocation).
- **Where samples come from** (layered, §5.1): significant-change service (always on), `CLVisit` events, region-exit/entry wakeups, and foreground fixes. Photo import backfills history.
- The pipeline runs opportunistically: on new samples, on app foreground, and in a nightly `BGProcessingTask` that also does retention cleanup and stats recomputation.

### 3.3 What counts: thresholds

A stay-point becomes a **confirmed visit** to a place when **all** hold:

| Rule | Value |
|---|---|
| Dwell | stay duration ≥ **10 min** for country / subdivision / county; ≥ **20 min** for a city to count as a city visit (a city you only drove through is transit) |
| Samples | ≥2 samples inside the boundary, **or** 1 sample + a photo with GPS inside the boundary in the same stay window |
| Accuracy | every counted sample has `horizontalAccuracy ≤ 250 m` for county/city, `≤ 1,000 m` for subdivision/country; worse samples are evidence of nothing and are dropped at ingest |
| Stability | the stay centroid is inside the boundary (not merely a sample near an edge) |

Below the dwell gate but with ≥2 in-boundary samples spanning ≥2 min: record as **transit**. A single fly-by sample: record nothing (this is the anti-phantom rule; a missed drive-through is acceptable, a phantom visit is not).

Overnight rule: a stay that spans local midnight inside a place always confirms, regardless of the 10/20-min gates (arriving at 23:55 and leaving at 00:10 is a visit to wherever you slept).

Flights: samples with implied speed > 250 km/h between consecutive fixes are marked in-transit at ingest and can only create `transit` records at country level (layover detection: a stay-point at an airport with dwell ≥45 min = transit visit to that country/city, matching the existing `transit` semantics users already have).

All thresholds live in one `VisitDetectionConfig` struct with the values above as defaults, so field-test tuning (§6) changes constants, not logic.

### 3.4 Matching order

For each confirmed/transit stay centroid, resolve in order and stop at the deepest level the data supports: country (point-in-polygon, exists) → subdivision (exists) → county (US only, new) → city (radius match within the resolved county/subdivision; if two city radii overlap, nearest centroid wins) → regions (member-key lookup, no geometry). `CLGeocoder` is demoted to a display-name nicety for UI text; it is never the source of a record (it is online, rate-limited, and its city boundaries do not match the gazetteer).

---

## 4. Medals and achievements

### 4.1 Architecture: medals v2, on-device

Badges v1 (server-evaluated, single-threshold) is replaced by a versioned, on-device medal engine. Rationale: medals must award offline, retroactively with historically correct dates, and against data (counties, cities, visits, distance) that v1's requirement types cannot express.

```swift
struct MedalDefinition: Codable, Identifiable {
    let id: String                 // "counties_total"
    let name: String               // "County Collector"
    let family: Family             // .countries .subdivisions .counties .cities .regions
                                   // .continents .completionist .distance .streaks .novelty
    let metric: Metric             // what is counted (enum below)
    let filter: [String: String]?  // e.g. ["continent": "Europe"], ["state": "US-VT"]
    let tiers: [Tier]              // ordered; tier = highest threshold met
    let icon: String               // SF Symbol
}
struct Tier: Codable { let level: TierLevel /* .bronze .silver .gold .platinum */; let threshold: Int }

@Model final class EarnedMedal {
    var medalId: String
    var tierLevel: String          // rawValue of highest tier earned
    var earnedAt: Date             // when the condition was FIRST met (from visit dates)
    var isRetroactive: Bool        // awarded by the §4.4 backfill pass
    var surfacedAt: Date?          // when the user was shown it (nil = unseen, drives the "new medal" moment)
}
```

- `Metric` cases (each a pure function over `Visit` + `VisitedPlace` + stats): `countriesVisited`, `subdivisionsVisited`, `countiesVisited`, `citiesVisited`, `capitalsVisited`, `regionsVisited`, `continentCountries(continent)`, `continentsTouched`, `countiesInState(state)`, `subdivisionsInCountry(country)`, `distanceKm`, `worldLandAreaPercent`, `newPlaceStreakWeeks`, `newPlaceStreakMonths`, `timeZonesVisited`, `hemispheresTouched`, `distinctYearsActive`. Adding a medal = adding a definition row, never new engine code, unless it needs a new metric.
- The catalog ships as `medals.json` in the app bundle (versioned, `catalogVersion`), generated from a single source file in the repo that **also** generates the backend copy, with a CI parity test (Phase 5) so iOS and backend can never drift the way the test counts did before PR #121.
- Evaluation runs on-device after every pipeline pass and after imports. The backend keeps serving `BadgesResponse` for friends/leaderboard compatibility: medals map onto it (one `BadgeProgress` per medal, `progress` = current metric, `progressTotal` = next tier threshold). Server-side evaluation is retired once the parity test is green for one full release.
- One medal, one row: tiers upgrade the same `EarnedMedal` (with `earnedAt` kept from the first tier and a `tierHistory` note in the detail view). The cabinet shows the highest tier earned.

### 4.2 The catalog (v1: 46 medal definitions, ~120 tiers)

Thresholds are bronze / silver / gold / platinum. "—" = tier not offered. Existing v1 badge names are kept where they exist so current users keep their cabinet recognizable.

**Countries** (`countriesVisited`, of 195)
| Medal | B | S | G | P |
|---|---|---|---|---|
| First Steps *(exists, 1)* | 1 | — | — | — |
| Explorer *(exists)* | 5 | 10 | — | — |
| Globetrotter *(exists)* | 25 | — | — | — |
| World Traveler *(exists)* | 50 | — | — | — |
| Elite Traveler *(exists)* | 100 | — | — | — |
| World Champion *(exists)* | 150 | — | — | — |
| Full Atlas | 195 | — | — | — |

(Single-threshold rows above are "milestone" medals: earned once, shown at platinum styling. The tiered families below carry the bronze→platinum progression.)

**US States** (`subdivisionsVisited`, filter country=US, of 51)
| Medal | B | S | G | P |
|---|---|---|---|---|
| State Starter | 5 | — | — | — |
| Road Tripper | 15 | 25 | — | — |
| Coast to Coast | 30 | 40 | — | — |
| Fifty Plus One | 49 | 50 | 51 | — |

**Counties** (`countiesVisited`, of 3,143)
| Medal | B | S | G | P |
|---|---|---|---|---|
| County Seat | 10 | 25 | — | — |
| County Hopper | 50 | 100 | — | — |
| Century Counties | 100 | 250 | — | — |
| County Connoisseur | 250 | 500 | — | — |
| Shire Reeve | 500 | 1,000 | — | — |
| County Royalty | 1,000 | 2,000 | 3,143 | — |

(Overlapping ladders are intentional: each medal is a named rung. The engine deduplicates display: the cabinet groups by family and highlights the highest rung in progress.)

**Cities & capitals** (`citiesVisited` / `capitalsVisited`)
| Medal | Metric | B | S | G | P |
|---|---|---|---|---|---|
| City Slicker | cities | 10 | 25 | — | — |
| Urban Explorer | cities | 50 | 100 | — | — |
| Metropolis | cities | 250 | 500 | 1,000 | — |
| Capital Gains | national capitals | 5 | 15 | 30 | 50 |
| Capital Collector | national capitals | 75 | 100 | 150 | 195 |
| State Capital Circuit | US state capitals | 10 | 25 | 40 | 51 |

**Subdivisions worldwide** (`subdivisionsVisited`, all 17 tracked countries)
| Medal | B | S | G | P |
|---|---|---|---|---|
| Regionalist | 25 | 50 | 100 | 250 |

**Regions** (`regionsVisited`, of the §2.4 v1 set)
| Medal | B | S | G | P |
|---|---|---|---|---|
| Metro Pass | 3 | 5 | 10 | — |
| Region Hopper | 15 | 25 | 40 | all (≈80) |

Plus one medal **per marquee region set**, generated from data, e.g. "Bay Area Native" (all 9 Bay Area counties), "New Englander" (all 6 New England states), "Tahoe Local" (all Tahoe member counties). These are `countiesInState`-style set medals with `filter` naming the region id; the catalog generator emits them from `NamedRegion` definitions flagged `medal: true`.

**Continents** (existing v1 continent badges are folded in as the bronze rung)
| Medal | Metric | B | S | G | P |
|---|---|---|---|---|---|
| Europe Explorer *(exists at 10)* | continentCountries(Europe) | 10 | 20 | 30 | all EU+EFTA+UK (≈34, data-defined) |
| Asia Adventurer *(exists at 10)* | continentCountries(Asia) | 10 | 20 | 30 | 40 |
| African Safari *(exists at 10)* | continentCountries(Africa) | 10 | 20 | 30 | 40 |
| Americas Explorer *(exists at 10)* | continentCountries(N. + S. America) | 10 | 15 | 20 | 25 |
| Island Hopper *(exists at 5)* | continentCountries(Oceania) | 5 | 8 | 12 | 14 |
| Continent Collector | continentsTouched (≥1 country each) | 3 | 5 | 6 | 7 |

Antarctica counts for Continent Collector platinum via a manual mark or a photo south of 60°S; there is no country record for it (noted on the medal detail).

**Completionist** (set medals; generated per target, one definition template, many instances)
| Medal template | Trigger |
|---|---|
| "<State> Complete" ×51 | all counties of that US state (`countiesInState`) |
| "Lower 48" | all 48 contiguous US states |
| "Great White North" | all 13 Canadian provinces/territories *(subdivision set)* |
| "Hexagone" | all FR subdivisions in the catalog (101) |
| "Land of the Rising Sun" | all 47 JP prefectures |
| "Home Turf" | 100% of the user's home country subdivisions (home = most-visited country; computed, one instance per user) |
| "Full Atlas: <Continent>" ×6 | every country of a continent |

**Distance & area** (from `Visit` centroids + sample track length; §3.1)
| Medal | Metric | B | S | G | P |
|---|---|---|---|---|---|
| Wanderer | distanceKm | 1,000 | — | — | — |
| Voyager | distanceKm | 5,000 | 10,000 | — | — |
| Around the World | distanceKm | 25,000 | 40,075 (Earth circumference) | 100,000 | 384,400 (Moon distance) |
| Surface Area | worldLandAreaPercent | 1% | 5% | 10% | 25% |

Distance = sum of great-circle segments between consecutive sample centroids (outliers >250 km/h filtered, §3.3), accumulated into a `TravelStats` singleton row so sample deletion (§3.1 retention) never reduces it. Pre-pipeline history has no track: distance medals start accumulating at install of the pipeline version, and the medal detail says so. (Retroactive distance from photo timestamps is explicitly not attempted: too sparse to be honest.)

**Streaks & cadence** (from `Visit` first-visit dates)
| Medal | Metric | B | S | G | P |
|---|---|---|---|---|---|
| Monthly Explorer | newPlaceStreakMonths (≥1 new place — any level — per calendar month) | 3 | 6 | 12 | 24 |
| Weekly Wanderer | newPlaceStreakWeeks | 4 | 8 | 12 | 26 |
| Regular Explorer | distinctYearsActive | 2 | 3 | 5 | 10 |
| Decade of Footprints | span between first and latest visit | 5 yrs | 10 yrs | — | — |

**Time zones** (extends existing `TimeZoneStats`; zones counted per the PR #121 semantics)
| Medal | Metric | B | S | G | P |
|---|---|---|---|---|---|
| Zone Hopper | timeZonesVisited (of 24) | 6 | 12 | 18 | — |
| All 24 Zones | timeZonesVisited | 24 | — | — | — |
| Date Line Crosser | visited both UTC≥+12 and UTC≤−11 zones | earned | — | — | — |

**Novelty / geography** (from `Visit` centroids; the app already computes farthest east/west for time zones — this generalizes it)
| Medal | Trigger |
|---|---|
| Four Hemispheres | ≥1 confirmed visit in each of N, S, E, W hemispheres |
| Equator Crosser | confirmed visits on both sides of 0° latitude |
| On the Equator | a confirmed visit with centroid within 0.5° of 0° |
| Polar Explorer | a confirmed visit north of the Arctic Circle (66.56°N) |
| Southern Cross | a confirmed visit south of the Tropic of Capricorn (−23.44°) |
| Meridian Split | confirmed visits on both sides of 0° longitude |
| Island Hopper is above; **Island Nations** | 5 / 10 / 20 island-nation countries (`isIslandNation` flag in `GeographicData`, new additive field) |
| Landlocked | 5 landlocked countries (`isLandlocked` flag, new additive field) |

### 4.3 Awarding UX

- Evaluation is silent; the *surfacing* is the product moment: the next time the user opens the app after an award, a medal sheet presents new medals (one at a time, highest family first) with tier, date earned, and the place that triggered it (the `Visit` that crossed the threshold). `surfacedAt` is set on dismissal. No push notifications for medals (the new-place notification already exists; medal pushes are noise — revisit only if Wouter asks).
- Medals screen (new tab-level destination, replacing the badges section of Advanced Stats): cabinet grid grouped by family, tier ring on each medal, progress bar to next tier (reusing `BadgeProgress`'s shape), filters (Earned / In progress / Locked), and a per-medal detail with tier history and the triggering place. Earned medals are shareable as an image card (rendered locally; no server round-trip).

### 4.4 Retroactive awarding

On first launch of the medals-v2 build:

1. **Backfill pass** over all existing `VisitedPlace` rows: they carry `visitedDate`, so every count-based medal (countries, subdivisions, continents, capitals via gazetteer match on subdivision/country, completionist sets) is evaluated against history as of each row's date. `earnedAt` = the `visitedDate` of the record that crossed the threshold; `isRetroactive = true`.
2. **Photo re-derivation:** if the user has photo-import permission, offer (one prompt, skippable) a re-scan that also derives county/city `Visit` rows from photo GPS (photos carry coordinates + timestamps — the only retroactive evidence that can honestly create county/city history). Declining leaves counties/cities starting from install; nothing is fabricated.
3. Existing v1 badges: any v1 badge the user already earned maps to its v2 medal at the matching rung; the cabinet shows them as earned with their original dates where the backend provides `unlockedAt`, else the earliest qualifying visit date.
4. The pass is idempotent and resumable (checkpointed per family), runs in the nightly background task if it can't finish in the foreground session, and its results are covered by tests over a fixture history (§6.4).

---

## 5. Automation

### 5.1 Background capture (battery-safe)

Layered, in priority order; each layer only wakes the next:

| Layer | Mechanism (all exist or are standard) | Duty |
|---|---|---|
| 1 | Significant-location-change service (exists) | Always on after opt-in; ~500 m cell-tower granularity, near-zero battery |
| 2 | `CLVisit` monitoring (new) | iOS delivers arrival/departure at places; the primary stay detector |
| 3 | Geofence wakeups (new) | A single rolling region around the last known position (radius 2 km) whose exit escalates sampling; plus fences are **not** used per-place (iOS caps at 20) |
| 4 | Standard location updates, deferred mode (new) | Only while movement is detected: `distanceFilter = 100 m`, `desiredAccuracy = kCLLocationAccuracyNearestTenMeters` while a candidate stay is forming, dropping to hundred-meters otherwise; `pausesLocationUpdatesAutomatically = true` (exists) |
| 5 | Motion coprocessor (new) | `CMMotionActivity` distinguishes stationary / walking / automotive / flight-speed; stationary ⇒ sampling floor, automotive ⇒ 100 m filter, flight ⇒ country-level only (§3.3) |

Budgets (acceptance-tested in §6): ≤1% battery per day attributable on a typical day; ≤3% on a heavy travel day; zero continuous-GPS operation while stationary for >15 min. `LocationManager` grows a `SamplingPolicy` that owns these transitions; the current class's country/state/city callbacks are re-pointed to consume pipeline results instead of driving records directly.

Permissions UX: request When-In-Use at first value moment (map centering), Always only from the dedicated "automatic tracking" onboarding screen that explains exactly what is recorded and that raw tracks never leave the phone. If Always is denied, the app degrades honestly: foreground + photo import still work, and Settings shows what is missing. No repeated nagging (App Store 5.1.1 and plain decency).

### 5.2 Offline resolution & gazetteer strategy

- Everything in §3.4 runs offline. `CLGeocoder` is display-only.
- Bundled data budget: countries (exists, 2.5 MB) + subdivisions (exists) + counties (new, ≤6 MB, per-state lazy) + cities gazetteer (≈4,500 rows, ≤1 MB) + regions (≤100 KB) + medals catalog (≤100 KB). Total added download ≤8 MB; anything bigger must ship as an on-demand resource pack (ODR) per continent, downloaded on Wi-Fi when the user first travels there — the loader API is written pack-aware from the start so this is a data decision, not a refactor.
- Gazetteer updates ride app releases (data is versioned in-bundle; `dataVersion` shown in Settings → About for support).

### 5.3 Sync

Current state: backend sync (`SyncManager`, version-vector-lite via `syncVersion` + `lastModifiedAt`, soft deletes) is the working system of record for `VisitedPlace`, and the backend powers friends, leaderboard, and stats APIs.

Target state in this spec:

- `VisitedPlace`, `Visit` **place keys + dates only** (never centroids at better than city granularity — `Visit` syncs as (placeKeys, arrivedAt, departedAt, source), its centroid stays on-device), and `EarnedMedal` sync through the existing backend path, extended with the new record kinds. Same conflict rule (last-write-wins per record, soft delete), now covered by the existing `SyncManagerTests` pattern extended per record kind.
- **CloudKit:** add a CloudKit private-database mirror of the SwiftData store (`VisitedPlace`, `Visit` keys-only form, `EarnedMedal`) so a user's devices stay in sync even with backend sync off, and a new phone restores fully from iCloud alone. CloudKit is a mirror, not a second master: the local store is the truth, CloudKit and the backend are both projections of it, and the backend remains the only path for anything social. (Whether CloudKit ships at all is Open Question 1 — it is specced here because the brief asks for it; the phases put it late, §7 Phase 6, so dropping it costs nothing upstream.)
- Sync is opportunistic and silent: on foreground, on pipeline completion, on BGAppRefresh; exponential backoff; a Settings line shows last-sync time and pending count. No sync = no data loss: everything queues locally.

### 5.4 Repair & backfill (standing machinery, not one-offs)

A `DataMaintenance` service, run nightly and on demand from Settings → Advanced:

1. **Dedupe:** merge `VisitedPlace` rows sharing (`regionType`, `regionCode`) — keep earliest `visitedDate`, max `visitCount`, union notes. (Duplicates are the known failure mode of callback-driven recording.)
2. **Re-resolve:** any `Visit` with unresolved keys is re-run through the matcher (fixes visits recorded before a data update, e.g. counties arriving in Phase 2 for a user whose samples predate it — samples within retention can re-derive county/city visits retroactively, with `source` preserved).
3. **Data-vs-code audit:** verify every GeoJSON feature code exists in `GeographicData` and vice versa (the GB `WRL`/`CKT`/`SHN` class of bug), every gazetteer `countyFips` exists in the county index, every medal `filter` references real places. Failures are logged and surfaced in the maintenance report, never silently.
4. **Stats recompute:** coverage, time zones, distance accumulator, and medal re-evaluation from the `Visit` ledger; the ledger wins over any cached stat.
5. **Import repair:** photo re-scan is incremental (asset-id watermark exists in the import manager's design; verify in Phase 6) and safe to re-run.

### 5.5 CI & release automation

Built on what exists (`ci.yml`, TestFlight workflows, self-hosted Mac runner):

- **PR gate (required, no exceptions):** iOS unit tests + backend pytest on the self-hosted runner; SwiftLint (config exists via pre-commit; enforce in CI); the data audit (§5.4.3) as a CI job over the bundled datasets; medals catalog parity test (iOS bundle vs backend copy byte-equal after generation). A red gate blocks merge under the standing assignment rules.
- **Data-driven test counts:** the PR #121 failure mode (hand-written expected counts going stale) is eliminated by generating subdivision/country count assertions from the data files at test time; literal counts survive only as sanity floors (e.g. countries ≥ 190).
- **Merge to main:** build + full test suite → automatic TestFlight **internal** upload (workflow exists) with the commit SHA as the build's internal notes.
- **Nightly:** UI tests + snapshot tests (§6.4) on the runner; a scheduled photo-import fixture run (synthetic photo library) to catch import regressions.
- **Release:** version tag `vX.Y.Z` → archive → TestFlight external → App Store submission via the existing `ios-app-store-release.yml`; phased release (Apple's 7-day rollout) default on; release notes generated from merged PR titles since the last tag, human-edited before submit.
- **Runner health:** the self-hosted runner is a single point of failure (PR #121's CI sat queued behind it). Add: runner offline >30 min ⇒ GitHub status ping to the owner via the existing monitoring workflow pattern; a documented runner-recovery runbook in `RELEASE.md`; and a fallback label so CI can fail over to a GitHub-hosted macOS runner for the unit-test job only (slower, but the PR gate never waits on one machine's uptime).
- Backend deploys stay as-is (Pulumi + `infrastructure-deploy.yml`) with one addition: badge/medals catalog deploy is part of the same pipeline run as the app data generation, so a catalog change ships atomically to both.

---

## 6. Production readiness

### 6.1 Crash & diagnostics

- MetricKit (`MXMetricManager`) for hangs, disk writes, and crash-adjacent diagnostics — on-device, Apple-mediated, no third party.
- Crash reporting: Sentry (self-hostable, and the repo already self-hosts its backend) **with location scrubbing**: a `beforeSend` hook that strips coordinates, place names, and free-form notes from every event; only code-level context ships. If Wouter prefers zero third-party SDKs, the fallback is MetricKit + backend crash-symbolication endpoint — decide in Phase 7, the scrubbing requirement stands either way.
- Structured logging via the existing `Log` categories; a user-initiated "Export diagnostics" in Settings bundles logs + the §5.4 maintenance report (user reviews before sharing; contains no raw coordinates by construction).

### 6.2 Privacy

- Raw `LocationSample` data: on-device only, excluded from iCloud and backend sync, excluded from device backups is **not** possible — instead samples are stored with `NSFileProtectionComplete` and the retention cap (§3.1) bounds exposure.
- Synced data is place-level only (§5.3) and sync is opt-in at onboarding (default on for backend account users, since friends/leaderboard need it; fully usable offline with sync off, medals and coverage unaffected).
- App Store privacy nutrition label: Location (precise) = App Functionality, linked to identity only if an account exists, **not** used for tracking; no ATT prompt (no cross-app tracking, no ad SDKs — keep it that way).
- Purpose strings must say what the spec does: background location exists to detect place visits automatically; the onboarding screen (§5.1) is the plain-language version of this section.
- Account deletion (exists: `AccountResetTests` suggests reset flows) must hard-delete backend rows and the CloudKit mirror, and offer "delete raw samples only" as a separate, lesser action.

### 6.3 Performance budgets

| Budget | Target |
|---|---|
| Cold start to interactive map | ≤1.5 s on iPhone 12 |
| Boundary + gazetteer load | lazy; country set ≤300 ms off the launch path; county state pack ≤150 ms on first entry to a state |
| Matcher throughput | ≥200 fixes/sec against loaded packs (batch re-resolution of 10k samples ≤1 min in background task) |
| Memory ceiling (steady state, map + packs) | ≤250 MB |
| Battery | §5.1 budgets |
| Storage | samples + visits ≤150 MB at retention cap; data packs per §5.2 |
| Medal evaluation | full re-evaluation over 10k visits ≤2 s (it runs on the pipeline path) |

### 6.4 Testing bar

- **Unit:** ≥90% line coverage on the new pure cores (stay clustering, matcher, medal engine, coverage math, maintenance jobs); ≥80% on services they touch. Geographic/timezone semantics tests from PR #121 are the template: behavior stated in the test name (e.g. `testTimeZoneMultiZoneCountryWithoutStates`).
- **Data tests:** §5.4.3 audit as a test suite over the real bundled files, in CI, on every PR.
- **UI tests:** the five flows — onboarding/permissions, manual mark/unmark, medal surfacing, county map drill-down, sync-off usage — on the nightly lane.
- **Snapshot tests:** medals cabinet (empty / partial / full), country page at 0/50/100% coverage, county map for one dense and one sparse state; light + dark.
- **Backend:** pytest green incl. `test_badges.py` successor (catalog parity + evaluation fixtures shared with iOS: the same fixture history JSON drives both test suites and must produce identical medal outcomes).
- **Field test (release gate for Phases 1 and 7):** owner's phone, 14 days incl. one multi-state trip: ≥98% of ground-truth visits captured (ground truth = owner's log), 0 phantom counties, battery within §5.1 budget.

### 6.5 App Store requirements

- Background location: `UIBackgroundModes` = location (exists via current tracking), with the review-notes paragraph pre-written in `RELEASE.md`: what it does, the onboarding video/screenshot of the consent flow, and the privacy posture of §6.2. This is the single most likely rejection vector; the consent UX ships in Phase 1, not at submission time.
- Sign in with Apple (exists) wherever third-party login is offered; account deletion in-app (verify in Phase 7); no external purchase links; widgets (exist) keep working with the new stats.
- Age rating, export compliance (standard encryption declaration), and per-release "What's New" discipline per §5.5.

### 6.6 Definition of done (every phase)

A phase is done when: its acceptance criteria (§7) are all demonstrably met; new pure-core code meets §6.4 coverage; the data audit is green; no existing test was weakened to pass (diff-visible); the PR description states what changed, what was tested, and the field-test impact; and the PR is merged under the standing rules (CI green + Devin Review green + assigned by Devin only then; merging is Nyx/Wouter's act, never Devin's).

---

## 7. Phasing

Each phase is sized for one Devin session and one PR. Dependencies are strictly in order unless noted. Phase numbering is the implementation order; § references point at the normative text.

### Phase 0 — Green tests, trustworthy CI
**Scope:** Land PR #121 (already written: stale GeographicData counts → FR 101 / IT 110 / GB 229, 17 subdivision countries, JP 47 / KR 17 / NO 15; timezone tests encode the visited-states-only semantics). Fix the GB GeoJSON mismatch it documented (codes `WRL`, `CKT`, `SHN`: determine whether the GeoJSON or `ukCouncilAreas` is wrong against an authoritative council list, fix the wrong side). Convert hand-written count assertions to data-generated ones (§5.5). Add the §5.4.3 data audit as a CI job. Document the runner runbook + offline alert (§5.5).
**Acceptance:** PR #121 merged with CI green on the self-hosted runner; full iOS + backend suites green on main; data audit job exists and fails when a GeoJSON code is deliberately corrupted in a test branch; no test deleted or assertion weakened (counts replaced by generated equivalents, not removed).

### Phase 1 — Visit evidence pipeline
**Scope:** `LocationSample` + `Visit` models and migration; stay-point clustering + `VisitDetectionConfig` gates (§3.2–3.3) as pure, tested code; `SamplingPolicy` layering (§5.1 layers 1–5) behind the existing `LocationManager` façade; pipeline writes `Visit` rows and upserts `VisitedPlace` (country/subdivision only — today's matcher scope); onboarding consent screen (§5.1); distance accumulator (§4.2) starts counting. No new UI beyond onboarding and a Settings → Advanced pipeline status line.
**Acceptance:** unit tests cover clustering/gates incl. flight, drive-through, and overnight cases from synthetic sample fixtures; existing callbacks' behavior preserved (LocationManagerTests extended, not replaced); a 7-day on-device soak on the owner's phone (internal TestFlight) captures every country/subdivision change on a known itinerary with 0 phantom records; battery within budget (§5.1) per MetricKit payloads.

### Phase 2 — US counties: data, matching, coverage
**Scope:** county dataset pipeline + bundled per-state packs (§2.2); matcher extension with pre-filter and lazy state loading (§5.2); `.usCounty` records from the pipeline (transit vs visited per §3.3); US page and state pages with county counts/%; county choropleth map (§2.6); §5.4 re-resolution backfills counties from retained samples and from photo re-scan (offer at first launch of this version).
**Acceptance:** matcher tests against known-coordinate fixtures for ≥200 counties incl. edge cases (independent cities, parishes, AK boroughs, PR); county map snapshot tests (one dense, one sparse state); data audit covers FIPS ↔ index consistency; backfill produces identical county sets from a fixture photo library on two runs (idempotent).

### Phase 3 — Cities & capitals
**Scope:** verify `world_cities.json` provenance/schema (or rebuild the gazetteer per §2.3 from GeoNames); `.city` records via radius matching; capitals flags + "Capitals" collection page; city pins layer; landmark inventory from `world_landmarks.json` with `.landmark` manual+photo detection only (no background landmark matching in this phase).
**Acceptance:** gazetteer build is reproducible from committed sources; capital lists verified against an authoritative source in the data PR (195 national, 51 US state); overlap disambiguation tests (e.g. stays in NYC match New York city, not nearer small centroids); cities appear in lists/maps/coverage per §2.5–2.6.

### Phase 4 — Regions
**Scope:** `NamedRegion` dataset v1 (§2.4, ~80 regions) as data + generator; region resolution from member keys in the pipeline; region pages and lists; set-medal hooks (definitions only — engine lands in Phase 5).
**Acceptance:** every region's member keys resolve against the place registry (data audit); coverage math tests per kind (metro/cultural/geographic); at least the marquee sets (Bay Area, New England, Tahoe) verified by hand against their real-world definitions in the data PR description.

### Phase 5 — Medals v2
**Scope:** catalog source file + generator producing iOS `medals.json` and the backend copy (§4.1); on-device engine + `EarnedMedal`; full §4.2 catalog (46 definitions) incl. generated completionist and region-set instances; retroactive pass (§4.4) incl. v1-badge mapping and the optional photo re-derivation prompt; medals screen + surfacing sheet + share card (§4.3); backend `BadgesResponse` mapping so friends/leaderboard keep working; shared iOS/backend evaluation fixtures (§6.4).
**Acceptance:** fixture history produces the exact expected medal set + `earnedAt` dates in both iOS and backend test suites; retroactive pass is idempotent and resumable (killed mid-pass in test, completes correctly on relaunch); a user with v1 badges loses none; catalog parity test in CI; medals screen snapshot tests green.

### Phase 6 — Sync hardening, CloudKit mirror, maintenance
**Scope:** sync extended to `Visit` keys-only records and `EarnedMedal` (§5.3); CloudKit private-DB mirror (skippable per Open Question 1 — if skipped, this phase is sync-hardening only); `DataMaintenance` service (§5.4) with Settings UI and exportable report; account deletion verified end-to-end (backend + mirror + local samples choice).
**Acceptance:** two-device test (phone + iPad or simulator pair) converges to identical place/medal state from disjoint offline edits; conflict fixtures resolve per §5.3 rules; maintenance dedupe/repair proven on a corrupted-fixture store; deletion test asserts zero residual records server-side.

### Phase 7 — Production hardening & release
**Scope:** §6.1 crash/diagnostics wiring with scrubbing tests; performance budgets (§6.3) measured and enforced as CI benchmarks where automatable; privacy label + purpose strings + review-notes pack (§6.5); 14-day field test (§6.4); release automation dry run: tag → TestFlight external → phased App Store release of the Phase 1–6 build.
**Acceptance:** field-test numbers meet §6.4; a scrubbing test proves a synthetic crash event containing coordinates leaves the process with none; App Store Connect metadata + privacy answers complete in the repo (`metadata.yml` workflow updated); the release dry run reaches "Waiting for Review" or better without manual steps beyond the human edit of release notes.

**Explicitly out of scope for these phases:** Android parity, UNESCO/national-park layers (IDEAS.md #46/#40 — natural Phase 8 candidates on the landmark machinery), social features beyond keeping friends/leaderboard working, any web dashboard work.

---

## 8. Open questions for Wouter

1. **CloudKit:** Phase 6 specs a CloudKit private-DB mirror alongside the existing backend sync. Keep both (iCloud restores + backend for social), or is backend-only sync good enough and CloudKit dropped? This changes Phase 6's size by roughly half.
2. **Android:** the repo contains an Android app with its own `GeographicData.kt`. Is "production-ready" iOS-only for this push, or must counties/medals land on Android in the same program (each phase grows ~40%)?
3. **County scope:** US counties only at v1 (this spec), or are UK/Irish/other county systems in the same program? (GB council areas already exist as subdivisions, which is why the spec treats US counties as the gap.)
4. **Raw-track retention:** distance and streak medals need the on-device sample store; the spec caps it at 13 months, on-device only, never synced. Is that acceptable, or should retention be shorter (less retroactive power) / longer (more storage + privacy surface)?
5. **Drive-through default:** the spec records sub-threshold crossings as `transit` (shown, but not counted for coverage/medals). Should a highway crossing of a county instead count as a full visit by default, with transit reserved for airport layovers? This changes §3.3's gates and every county medal's difficulty.

---

*End of spec. Implementation starts at Phase 0; PR #121 is its first deliverable and is already written.*
