# Footprint Travel Tracker - Progress & Tasks

## Project Status: MVP DEVELOPMENT
**Last Updated**: 2026-01-25

## Source of Truth: GitHub Issues

All open tasks, bugs, and feature requests are tracked in GitHub Issues:
https://github.com/wdvr/footprint/issues

### Open Bugs
| Issue | Title | Labels |
|-------|-------|--------|
| [#11](https://github.com/wdvr/footprint/issues/11) | Auth token not persisted across app relaunch | bug |
| [#12](https://github.com/wdvr/footprint/issues/12) | Push notifications not configured for production | bug, infrastructure, ios |

### In Progress Features
| Issue | Title | Labels |
|-------|-------|--------|
| [#15](https://github.com/wdvr/footprint/issues/15) | Apple Sign In - waiting for approval | blocked, ios |

### Recently Completed
| Issue | Title | Labels |
|-------|-------|--------|
| [#13](https://github.com/wdvr/footprint/issues/13) | Gmail/Calendar import feature | feature, ios, backend |
| [#14](https://github.com/wdvr/footprint/issues/14) | In-app feedback and feature requests | feature, ios, backend |

### Planned Features
| Issue | Title | Labels |
|-------|-------|--------|
| [#16](https://github.com/wdvr/footprint/issues/16) | Deploy production AWS environment | infrastructure |
| [#17](https://github.com/wdvr/footprint/issues/17) | States/provinces for other countries | feature |
| [#18](https://github.com/wdvr/footprint/issues/18) | Cities & Landmarks tracking | feature |
| [#19](https://github.com/wdvr/footprint/issues/19) | macOS app (Universal purchase) | feature |
| [#20](https://github.com/wdvr/footprint/issues/20) | Data export - share travel maps | feature, ios |
| [#21](https://github.com/wdvr/footprint/issues/21) | Accessibility improvements | feature, ios |
| [#22](https://github.com/wdvr/footprint/issues/22) | iOS UI tests | ios |
| [#23](https://github.com/wdvr/footprint/issues/23) | Performance testing | ios, backend |

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

### High Priority - Core Features
| # | Feature | Description | Status |
|---|---------|-------------|--------|
| 4 | **Bucket list mode** | Mark places you WANT to visit, toggle between "visited" and "want to visit" | 🔲 TODO |
| 5 | **Travel timeline** | Add visit dates to places, "When did I visit France?", chronological history | 🔲 TODO |
| 6 | **Photos & memories** | Attach photos to visited places, integrate with Photos app | 🔲 TODO |
| 7 | **Photo library import** | Scan photo library GPS metadata, auto-suggest places you've visited | ✅ DONE |
| 8 | **Badges & achievements** | Gamification: "10 countries", "All US states", "Europe explorer", unlock rewards | 🔲 TODO |
| 9 | **Push notifications** | "You're near a new country!", weekly travel stats, achievement unlocks | 🔲 TODO |

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
