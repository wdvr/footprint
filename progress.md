# Footprint Travel Tracker - Progress & Tasks

## Project Status: MVP DEVELOPMENT
**Last Updated**: 2026-01-24

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
| [#13](https://github.com/wdvr/footprint/issues/13) | Gmail/Calendar import feature | feature, ios, backend |
| [#15](https://github.com/wdvr/footprint/issues/15) | Apple Sign In - waiting for approval | blocked, ios |

### Planned Features
| Issue | Title | Labels |
|-------|-------|--------|
| [#14](https://github.com/wdvr/footprint/issues/14) | In-app feedback and feature requests | feature, ios, backend |
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

## API Endpoints
- **Dev**: https://jz0gkkwq8b.execute-api.us-east-1.amazonaws.com/dev
- **Prod**: TBD (#16)
