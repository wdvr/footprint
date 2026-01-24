# Footprint Travel Tracker - Progress & Tasks

## Project Status: MVP DEVELOPMENT
**Last Updated**: 2026-01-20

## Current Sprint: Testing & Polish

### Phase 1: Project Foundation ✅ COMPLETED
| Task | Status | Notes |
|------|---------|-------|
| Initialize git repository | ✅ COMPLETED | GitHub repo at wdvr/footprint |
| Create CLAUDE.md with instructions | ✅ COMPLETED | Includes iOS tooling research |
| Create PROGRESS.md (this file) | ✅ COMPLETED | Task tracking system |
| Create README.md | ✅ COMPLETED | Project overview |
| Create .env template | ✅ COMPLETED | AWS credentials template |
| Create .gitignore | ✅ COMPLETED | Swift, Python, AWS secrets |
| Setup GitHub private repository | ✅ COMPLETED | wdvr/footprint |
| Setup pre-commit hooks | ✅ COMPLETED | Ruff linting/formatting |

### Phase 2: Architecture & Research ✅ COMPLETED
| Task | Status | Notes |
|------|---------|-------|
| Research geographic data sources | ✅ COMPLETED | Using country list data |
| Design database schema | ✅ COMPLETED | DynamoDB single-table design |
| Design API endpoints | ✅ COMPLETED | REST API with FastAPI |
| Design sync architecture | ✅ COMPLETED | Version-based conflict resolution |
| Create system architecture diagram | ✅ COMPLETED | AWS Lambda + API Gateway |

### Phase 3: Backend Infrastructure ✅ COMPLETED
| Task | Status | Notes |
|------|---------|-------|
| Setup Pulumi project | ✅ COMPLETED | infrastructure/__main__.py |
| Create DynamoDB tables | ✅ COMPLETED | Single table with GSI |
| Setup API Gateway | ✅ COMPLETED | HTTP API v2 |
| Create Lambda function | ✅ COMPLETED | FastAPI on Lambda |
| Setup CloudWatch monitoring | ✅ COMPLETED | Basic logging enabled |
| Implement Sign in with Apple backend | ✅ COMPLETED | JWT verification ready |

### Phase 4: Geographic Data Pipeline 🟡 PARTIAL
| Task | Status | Notes |
|------|---------|-------|
| Acquire country boundary data | 🟡 PENDING | For map visualization |
| Acquire US state boundary data | 🟡 PENDING | All 50 states + DC |
| Acquire Canadian province data | 🟡 PENDING | 10 provinces + 3 territories |
| Country list with codes | ✅ COMPLETED | 195 countries in app |
| Store geographic data in S3 | ✅ COMPLETED | Bucket configured |

### Phase 5: API Development ✅ COMPLETED
| Task | Status | Notes |
|------|---------|-------|
| Create user profile endpoints | ✅ COMPLETED | /api/v1/users/* |
| Create visited places endpoints | ✅ COMPLETED | /api/v1/places/* |
| Create sync endpoints | ✅ COMPLETED | /api/v1/sync/* |
| Create statistics endpoints | ✅ COMPLETED | Stats in user/places |
| Implement API authentication | ✅ COMPLETED | JWT tokens |
| Create API documentation | ✅ COMPLETED | OpenAPI auto-generated |

### Phase 6: iOS App Foundation ✅ COMPLETED
| Task | Status | Notes |
|------|---------|-------|
| Create Xcode project | ✅ COMPLETED | ios/Footprint |
| Setup project structure | ✅ COMPLETED | MVVM architecture |
| Implement Sign in with Apple UI | 🟡 BLOCKED | Requires paid Apple Developer ($99/yr) |
| Create networking layer | ✅ COMPLETED | APIClient with async/await |
| Setup SwiftData models | ✅ COMPLETED | Country, VisitedPlace models |
| Create data sync manager | ✅ COMPLETED | SyncManager service |

### Phase 7: Map Interface Development 🟡 PENDING
| Task | Status | Notes |
|------|---------|-------|
| Setup MapKit integration | 🟡 PENDING | World map view |
| Implement custom map overlays | 🟡 PENDING | Region highlighting |
| Create region selection logic | 🟡 PENDING | Tap detection |
| Implement map interactions | 🟡 PENDING | Pan, zoom, region focus |

### Phase 8: Core Feature Implementation ✅ MOSTLY COMPLETE
| Task | Status | Notes |
|------|---------|-------|
| Implement visit tracking | ✅ COMPLETED | Toggle countries visited |
| Create statistics calculator | ✅ COMPLETED | Progress percentages |
| Implement offline storage | ✅ COMPLETED | SwiftData integration |
| Create sync conflict resolution | ✅ COMPLETED | Version-based merge |
| Add data export features | 🟡 PENDING | Share travel maps |
| Implement search functionality | ✅ COMPLETED | Filter countries |

### Phase 9: UI/UX Polish ✅ MOSTLY COMPLETE
| Task | Status | Notes |
|------|---------|-------|
| Design app navigation | ✅ COMPLETED | TabView with 4 tabs |
| Create statistics dashboard | ✅ COMPLETED | Stats view |
| Create settings/profile view | ✅ COMPLETED | Settings tab with sign-out |
| Add sync status indicator | ✅ COMPLETED | Toolbar indicator |
| Add pull-to-refresh | ✅ COMPLETED | On country list |
| Implement accessibility | 🟡 PENDING | VoiceOver, Dynamic Type |

### Phase 10: Testing & Quality ✅ MOSTLY COMPLETE
| Task | Status | Notes |
|------|---------|-------|
| Setup unit tests (Backend) | ✅ COMPLETED | 92 tests passing |
| Setup integration tests (API) | ✅ COMPLETED | API route tests |
| Setup unit tests (iOS) | ✅ COMPLETED | 31 tests passing |
| Setup UI tests (iOS) | 🟡 PENDING | SwiftUI testing |
| Test sync scenarios | ✅ COMPLETED | In test suite |
| Performance testing | 🟡 PENDING | Map rendering, sync speed |

### Phase 11: Deployment & Launch 🟡 PARTIAL
| Task | Status | Notes |
|------|---------|-------|
| Deploy dev environment | ✅ COMPLETED | AWS dev stack live |
| Deploy production environment | 🟡 PENDING | AWS production setup |
| Setup CI/CD pipeline | ✅ COMPLETED | GitHub Actions |
| App Store preparation | 🟡 PENDING | Screenshots, metadata |
| Beta testing | 🟡 PENDING | TestFlight distribution |
| Production launch | 🟡 PENDING | App Store submission |

## Active PRs
- PR #4: Backend tests (feature/backend-tests) - Ready for merge

## Blocking Issues

### 🔴 Apple Developer Program Required
Sign in with Apple requires a paid Apple Developer Program membership ($99/year).
Without this, users cannot authenticate. Options:
1. Purchase Apple Developer membership
2. Implement alternative auth (email/password) as fallback

## Next Steps (Priority Order)

### Immediate (This Week)
1. **Apple Developer Setup** - Purchase membership to enable Sign in with Apple
2. **Merge PR #4** - Backend tests are ready
3. **Map Visualization** - Add MapKit with country overlays

### Short Term
4. **Geographic Boundary Data** - Acquire GeoJSON for country borders
5. **US States & Canadian Provinces** - Expand beyond countries
6. **Production Deployment** - Deploy prod AWS stack

### Medium Term
7. **UI Polish** - Accessibility, animations, haptic feedback
8. **Data Export** - Share travel maps as images
9. **TestFlight Beta** - Internal testing

## Technical Stack
- **Backend**: Python 3.11, FastAPI, AWS Lambda
- **Database**: DynamoDB (single-table design)
- **Infrastructure**: Pulumi (TypeScript config, Python runtime)
- **iOS**: Swift 6, SwiftUI, SwiftData
- **CI/CD**: GitHub Actions
- **Code Quality**: Ruff (linting/formatting), pre-commit hooks

## Development Setup
```bash
# Install pre-commit hooks
pip install pre-commit
pre-commit install

# Run hooks manually
pre-commit run --all-files

# Backend tests
cd backend && uv run python -m pytest tests/

# iOS tests
xcodebuild test -project ios/Footprint.xcodeproj -scheme Footprint -destination 'platform=iOS Simulator,name=iPhone 16'
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
| 7 | **Photo library import** | Scan photo library GPS metadata, auto-suggest places you've visited | 🔲 TODO |
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
| 19 | **Feature requests & feedback** | In-app feedback form that saves to DynamoDB for async review | 🔲 TODO |

### Future Ideas
| # | Feature | Description | Status |
|---|---------|-------------|--------|
| 20 | **Gmail/Calendar import** | Read travel confirmations from email/calendar, suggest locations to add | 🔲 TODO |
| 21 | **Annual travel summary** | Year-end recap like "Spotify Wrapped" for travel | 🔲 TODO |
| 22 | **UNESCO World Heritage Sites** | Track 1,199 heritage sites visited | 🔲 TODO |
| 23 | **Siri Shortcuts** | "Hey Siri, add Japan to my visited places" | 🔲 TODO |

## Notes & Learnings
- Swift 6 strict concurrency requires `nonisolated(unsafe)` for test mocks
- Moto library excellent for DynamoDB testing
- Pre-commit hooks catch issues before CI (saves time)
- XcodeGen useful for managing multiple iOS projects (Footprint + Snow)
