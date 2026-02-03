# Footprint Travel Tracker - Progress & Tasks

## Project Status: MVP DEVELOPMENT
**Last Updated**: 2026-02-03

## Source of Truth: GitHub Issues

All open tasks, bugs, and feature requests are tracked in GitHub Issues:
https://github.com/wdvr/footprint/issues

## ✅ NEW: International States/Provinces (2026-02-03)

Added state/province tracking for 8 new countries:

| Country | Subdivisions | Count |
|---------|-------------|-------|
| 🇷🇺 Russia | Federal subjects | 84 |
| 🇬🇧 United Kingdom | Counties/Districts | 232 |
| 🇫🇷 France | Departments | 101 |
| 🇮🇹 Italy | Provinces | 110 |
| 🇪🇸 Spain | Provinces | 52 |
| 🇳🇱 Netherlands | Provinces | 15 |
| 🇧🇪 Belgium | Provinces | 11 |
| 🇦🇷 Argentina | Provinces | 24 |

**Implementation Details:**
- Downloaded GeoJSON boundaries from Natural Earth Data
- Added region types to VisitedPlace model
- Added state arrays to GeographicData
- Updated StateMapView to center on correct country
- Fixed state selection overlay to work for all countries

**Bug Fixes (same commit):**
- Fixed auth persistence (Keychain now uses proper service/accessibility attributes)
- Fixed map jumping to US when selecting states for other countries

## ✅ RESOLVED: Domain & Auth Issues (2026-02-03)

### Problem (FIXED)
- ~~Google Sign In fails: "server with hostname could not be found"~~
- ~~Apple Sign In also fails with same error~~
- ~~`api.footprintmaps.com` not resolving correctly~~

### Root Cause
Domain registered in [default] AWS account, infrastructure in [personal] account. DNS was pointing to stale API Gateway endpoint.

### Resolution (2026-02-03)
1. ✅ Deployed actual FastAPI Lambda code (38 MB package) to personal account
2. ✅ Created ACM certificate for `api.footprintmaps.com` in personal account
3. ✅ Created API Gateway custom domain: `d-o89prx28nk.execute-api.us-east-1.amazonaws.com`
4. ✅ Updated Route53 A record in default account to point to new custom domain
5. ✅ DNS propagating globally (authoritative NS returns correct IPs: 52.5.194.95, 44.220.97.148)
6. ✅ API health check working: `{"status":"healthy","service":"footprint-api"}`

**Note**: Local DNS cache may take time to update. Google/Apple Sign In should work on devices once DNS propagates.

### Open Bugs
| Issue | Title | Labels |
|-------|-------|--------|
| [#30](https://github.com/wdvr/footprint/issues/30) | Persist Google connection - avoid re-auth on every import | bug, ios, backend |
| [#31](https://github.com/wdvr/footprint/issues/31) | Reduce console logging spam on device | ios |
| LOCAL | Apple Photos import doesn't resume - re-processes all images on restart | bug, ios |
| LOCAL | Apple Photos import misses coastal photos (geocoding fails for near-ocean coordinates) | bug, ios |

## ✅ Already Implemented Features

### Photo Pins with Clustering
- **Status**: ✅ ALREADY IN MAIN
- **Location**: `ios/Footprint/Map/CountryMapView.swift`
- Photo locations show as pins on map
- Clusters automatically when zoomed out (MKClusterAnnotation)
- Expands to individual pins when zoomed in

### Cities/Provinces for International Regions
- **Status**: ✅ MERGED (PR #76)
- Cities and provinces tracking for multiple countries

### Apple Photos Import Issues (Detailed Analysis) - FIXED

**Issue 1: Import doesn't resume properly (re-processes all 70,000 images)** - FIXED
- **Location**: `PhotoImportManager.swift`
- **Root causes identified**:
  1. `scanPhotoLibrary()` calls `clearScanProgress()` immediately, clearing any saved progress
  2. Phase 1 (photo enumeration) always runs completely even during resume
  3. No incremental scan support - always processes ALL photos
- **Fixes implemented**:
  1. Added `scanAllPhotos` parameter - when false (default), only scans photos newer than `lastScannedPhotoDate`
  2. Added `pendingClusters` to `PhotoScanProgress` - resume now skips Phase 1 entirely by using saved clusters
  3. Updated UI: "Scan New Photos" (incremental) vs "Full Rescan (All Photos)" options
  4. Clusters are saved immediately when geocoding phase starts, so resume always works

**Issue 2: Coastal photos not detected (Australia example)** - FIXED
- **Location**: `PhotoImportManager.swift`, new `GeoLocationMatcher.swift`
- **Root cause**: Photos on coast have GPS coordinates slightly in ocean; `CLGeocoder` returns no country code
- **Fix implemented**:
  1. Created `GeoLocationMatcher` utility class that uses on-device GeoJSON boundary polygons
  2. When geocoding fails or returns no country, fallback to `matchCoordinateWithTolerance()`:
     - First tries exact point-in-polygon match
     - If no match, tries 8 nearby points (N, S, E, W, NE, NW, SE, SW) at 500m tolerance
  3. Uses existing country boundary GeoJSON data (same used for map rendering)
  4. Also handles US states and Canadian provinces in the fallback

### In Progress Features
| Issue | Title | Labels |
|-------|-------|--------|
| [#16](https://github.com/wdvr/footprint/issues/16) | Deploy production AWS environment | infrastructure |

### Recently Completed
| Issue | Title | Labels |
|-------|-------|--------|
| [#17](https://github.com/wdvr/footprint/issues/17) | States/provinces for other countries (RU, GB, FR, IT, ES, NL, BE, AR) | feature |
| [#11](https://github.com/wdvr/footprint/issues/11) | Auth token persistence (Keychain-based) | bug |
| [#12](https://github.com/wdvr/footprint/issues/12) | Push notifications configured | bug, infrastructure, ios |
| [#14](https://github.com/wdvr/footprint/issues/14) | In-app feedback and feature requests | feature, ios, backend |
| [#15](https://github.com/wdvr/footprint/issues/15) | Apple Sign In | ios |
| [#22](https://github.com/wdvr/footprint/issues/22) | iOS UI tests (5 screenshot tests) | ios |
| [#24](https://github.com/wdvr/footprint/issues/24) | Link Google Account | feature, ios, backend |
| [#25](https://github.com/wdvr/footprint/issues/25) | Import from Google Calendar | feature, ios, backend |
| [#26](https://github.com/wdvr/footprint/issues/26) | Import from Gmail | feature, ios, backend |
| [#33](https://github.com/wdvr/footprint/issues/33) | Bucket list mode | feature, ios |
| [#38](https://github.com/wdvr/footprint/issues/38) | Push notifications - travel alerts | feature, ios |

### Planned Features
| Issue | Title | Labels |
|-------|-------|--------|
| [#18](https://github.com/wdvr/footprint/issues/18) | Cities & Landmarks tracking | feature |
| [#19](https://github.com/wdvr/footprint/issues/19) | macOS app (Universal purchase) | feature |
| [#20](https://github.com/wdvr/footprint/issues/20) | Data export - share travel maps | feature, ios |
| [#21](https://github.com/wdvr/footprint/issues/21) | Accessibility improvements | feature, ios |
| [#23](https://github.com/wdvr/footprint/issues/23) | Performance testing | ios, backend |
| [#28](https://github.com/wdvr/footprint/issues/28) | Pretty splash screen with animated world map | feature, ios |
| [#34](https://github.com/wdvr/footprint/issues/34) | Travel timeline - visit dates | feature, ios, backend |
| [#35](https://github.com/wdvr/footprint/issues/35) | Photos & memories | feature, ios |
| [#37](https://github.com/wdvr/footprint/issues/37) | Badges & achievements | feature, ios, backend |
| [#39](https://github.com/wdvr/footprint/issues/39) | Transit vs Visited distinction | feature, ios, backend |
| [#40](https://github.com/wdvr/footprint/issues/40) | National Parks tracking | feature, ios, backend |
| [#41](https://github.com/wdvr/footprint/issues/41) | Continent statistics breakdown | feature, ios |
| [#42](https://github.com/wdvr/footprint/issues/42) | Time zones visited tracking | feature, ios |
| [#43](https://github.com/wdvr/footprint/issues/43) | Apple Watch app | feature |
| [#44](https://github.com/wdvr/footprint/issues/44) | Friends leaderboard | feature, ios, backend |
| [#45](https://github.com/wdvr/footprint/issues/45) | Annual travel summary | feature, ios |
| [#46](https://github.com/wdvr/footprint/issues/46) | UNESCO World Heritage Sites | feature, ios, backend |
| [#47](https://github.com/wdvr/footprint/issues/47) | Siri Shortcuts integration | feature, ios |

## Completed Phases

### Phase 1-6: Foundation ✅
- Project setup, architecture, backend infrastructure, API development, iOS foundation

### Phase 7-8: Core Features ✅
- Map interface, visit tracking, offline storage, sync, statistics

### Phase 9-10: Polish ✅
- UI navigation, settings, tests (92 backend + 31 iOS)

### Phase 11: Deployment 🟡
- Dev environment deployed
- Production pending (#16)

## Completed Features
- ✅ Live location tracking
- ✅ iOS Widget (code ready)
- ✅ Friend lists & sharing
- ✅ Bucket list mode

## Technical Stack
- **Backend**: Python 3.11, FastAPI, AWS Lambda
- **Database**: DynamoDB (single-table design)
- **Infrastructure**: Pulumi
- **iOS**: Swift 6, SwiftUI, SwiftData
- **CI/CD**: GitHub Actions

## API Endpoints
- **Dev**: https://jz0gkkwq8b.execute-api.us-east-1.amazonaws.com/dev
- **Prod**: TBD (#16)

## Development Commands
```bash
# Backend tests
cd backend && uv run python -m pytest tests/

# iOS tests
xcodebuild test -project ios/Footprint.xcodeproj -scheme Footprint \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'

# Deploy to AWS
cd infrastructure && python3 deploy_lambda.py
pulumi up --yes
```

## Key Metrics & Success Criteria
- **Test Coverage**: 68 backend + 71 iOS tests passing
- **CI/CD**: All PRs run automated tests (backend + iOS)
- **Code Quality**: Pre-commit hooks enforce standards
- **Offline Capability**: Full functionality without internet ✅

## Future Features Roadmap (Priority Order)

### Completed
| # | Feature | Description | Status |
|---|---------|-------------|--------|
| 1 | **Live location tracking** | Request location permission, show current position on map, auto-detect visited places | ✅ DONE |
| 2 | **iOS Widget** | Home screen widget showing travel stats (code ready, add target in Xcode) | ✅ DONE |
| 3 | **Friend lists & sharing** | Connect with friends, share/compare travel lists (backend + iOS UI complete) | ✅ DONE |
| 4 | **Bucket list mode** | Mark places you WANT to visit, toggle between "visited" and "bucket list" | ✅ DONE |

### High Priority - Core Features
| # | Feature | Description | Status |
|---|---------|-------------|--------|
| 5 | **Travel timeline** | Add visit dates to places, "When did I visit France?", chronological history | 🔲 TODO |
| 6 | **Photos & memories** | Attach photos to visited places, integrate with Photos app | 🔲 TODO |
| 7 | **Photo library import** | Scan photo library GPS metadata, auto-suggest places you've visited | ✅ DONE |
| 8 | **Badges & achievements** | Gamification: "10 countries", "All US states", "Europe explorer", unlock rewards | 🔲 TODO |
| 9 | **Push notifications** | "You're near a new country!", weekly travel stats, achievement unlocks | ✅ DONE |

### Medium Priority - Expanded Tracking
| # | Feature | Description | Status |
|---|---------|-------------|--------|
| 10 | **Transit vs visited** | Distinguish "passed through/layover" from "actually visited" for each place | 🔲 TODO |
| 11 | **National Parks** | Track national parks visited (US 63 parks, expand globally) | 🔲 TODO |
| 12 | **Continent statistics** | "You've visited 45% of Europe" - breakdown by continent/region | 🔲 TODO |
| 13 | **Time zones visited** | Fun stat: track how many of the 24 time zones you've been in | 🔲 TODO |
| 14 | **States for other countries** | Add state/province boundaries for Australia, Mexico, etc. | 🔲 TODO |
| 15 | **Cities & landmarks** | Track visited cities and famous landmarks | 🔲 TODO |

### Platform Expansion
| # | Feature | Description | Status |
|---|---------|-------------|--------|
| 16 | **Apple Watch app** | Quick glance at stats, complications, "countries visited" on wrist | 🔲 TODO |
| 17 | **macOS app** | Native Mac app (Universal purchase) | 🔲 TODO |

### Social & Sharing
| # | Feature | Description | Status |
|---|---------|-------------|--------|
| 18 | **Friends leaderboard** | Compare travel stats with friends, rankings, friendly competition | 🔲 TODO (long-term) |
| 19 | **Feature requests & feedback** | In-app feedback form that saves to DynamoDB for async review | ✅ DONE |

### Future Ideas
| # | Feature | Description | Status |
|---|---------|-------------|--------|
| 20 | **Gmail/Calendar import** | Read travel confirmations from email/calendar, suggest locations to add | ✅ DONE |
| 21 | **Annual travel summary** | Year-end recap like "Spotify Wrapped" for travel | 🔲 TODO |
| 22 | **UNESCO World Heritage Sites** | Track 1,199 heritage sites visited | 🔲 TODO |
| 23 | **Siri Shortcuts** | "Hey Siri, add Japan to my visited places" | 🔲 TODO |

## Notes & Learnings
- Swift 6 strict concurrency requires `nonisolated(unsafe)` for test mocks
- Moto library excellent for DynamoDB testing
- Pre-commit hooks catch issues before CI (saves time)
- XcodeGen useful for managing multiple iOS projects (Footprint + Snow)
