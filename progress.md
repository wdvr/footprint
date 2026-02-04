# Footprint Travel Tracker - Progress & Tasks

## Project Status: v2.0 RELEASED
**Last Updated**: 2026-02-04

## Source of Truth: GitHub Issues

All open tasks, bugs, and feature requests are tracked in GitHub Issues:
https://github.com/wdvr/footprint/issues

---

## v2.0.0 Release (2026-02-04)

### Core Features
- Interactive world map with 195 countries
- US states (50) and Canadian provinces (13) tracking
- International states/provinces: Russia, UK, France, Italy, Spain, Netherlands, Belgium, Argentina
- Apple Photos import with GPS detection
- Sign in with Apple authentication
- Offline-first with cloud sync
- iOS widgets
- Background location tracking
- Push notifications

### Stats & Gamification
- Continent breakdown statistics
- Time zones visited tracking
- Transit vs Visited distinction
- Badges & achievements system
- Travel timeline with visit dates
- Friends leaderboard

### Infrastructure
- Marketing website: https://footprintmaps.com
- Support page with email: support@footprintmaps.com
- API: https://api.footprintmaps.com
- Automated CI/CD pipeline
- App Store submission ready

---

## Open Issues (Future Features)

| Issue | Title | Priority |
|-------|-------|----------|
| [#16](https://github.com/wdvr/footprint/issues/16) | Deploy production AWS environment | High |
| [#18](https://github.com/wdvr/footprint/issues/18) | Cities & Landmarks tracking | Medium |
| [#19](https://github.com/wdvr/footprint/issues/19) | macOS app (Universal purchase) | Medium |
| [#20](https://github.com/wdvr/footprint/issues/20) | Data export - share travel maps | Medium |
| [#21](https://github.com/wdvr/footprint/issues/21) | Accessibility improvements | Medium |
| [#23](https://github.com/wdvr/footprint/issues/23) | Performance testing | Low |
| [#28](https://github.com/wdvr/footprint/issues/28) | Pretty splash screen | Low |
| [#31](https://github.com/wdvr/footprint/issues/31) | Reduce console logging | Low |
| [#35](https://github.com/wdvr/footprint/issues/35) | Photos & memories | Medium |
| [#40](https://github.com/wdvr/footprint/issues/40) | National Parks tracking | Medium |
| [#43](https://github.com/wdvr/footprint/issues/43) | Apple Watch app | Low |
| [#45](https://github.com/wdvr/footprint/issues/45) | Annual travel summary | Low |
| [#46](https://github.com/wdvr/footprint/issues/46) | UNESCO World Heritage Sites | Low |
| [#47](https://github.com/wdvr/footprint/issues/47) | Siri Shortcuts | Low |
| [#88](https://github.com/wdvr/footprint/issues/88) | iPad screenshot tests | Low |

---

## Technical Stack

- **Backend**: Python 3.11, FastAPI, AWS Lambda
- **Database**: DynamoDB (single-table design)
- **Infrastructure**: Pulumi, GitHub Actions
- **iOS**: Swift 6, SwiftUI, SwiftData, MapKit
- **Auth**: Sign in with Apple, Google OAuth

## Development Commands

```bash
# Backend tests
cd backend && uv run python -m pytest tests/

# iOS tests
xcodebuild test -project ios/Footprint.xcodeproj -scheme Footprint \
  -destination 'platform=iOS Simulator,name=iPhone 17'

# Deploy infrastructure
cd infrastructure && source ../venv/bin/activate
AWS_PROFILE=personal pulumi up --yes --stack dev

# Deploy website
cd website && npm run build
AWS_PROFILE=personal aws s3 sync dist s3://footprint-website-dev-383757231925 --delete
```

## Notes
- Google Calendar/Gmail import temporarily disabled (re-enable in ImportSourcesView.swift)
- Swift 6 strict concurrency requires `nonisolated(unsafe)` for test properties
- Domain registered in [default] AWS account, infrastructure in [personal] account

---

## v2.0.1 Work In Progress (2026-02-04)

### Investigated Features & Fixes

**Google Calendar/Gmail Import**: Already hidden on main branch (ImportSourcesView.swift lines 18-98)

**Sharing Feature**: Issue #20 is open - "Data export - share travel maps". No dedicated branch exists yet.

**Russia/Timezone Bug Investigation**:
- The "visiting Russia marks all as visited" bug was not found in open issues
- Russia federal subjects (85 regions) are properly implemented in GeographicData.swift
- State matching uses short codes (e.g., "MOW" for Moscow) mapped from ISO format
- No existing branch for timezone fixes found

### CI/CD Improvements

**TestFlight Deployment Fix**: Updated ios-build.yml to produce signed IPA artifacts:
- Added App Store Connect API authentication
- Added archive and export steps
- Added artifact upload for TestFlight workflow consumption

### Open Branches (Remote)

| Branch | Purpose |
|--------|---------|
| `feature/cities-provinces-expansion` | International regions support |
| `feature/i18n-translations` | Internationalization |
| `feature/import-improvements` | Import flow enhancements |
| `fix/auto-token-refresh` | Token refresh fixes |
| `claude/google-login-integration-*` | Google OAuth integration |
