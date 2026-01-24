# Footprint Travel Tracker - Progress

**Status**: MVP Development | **Updated**: 2026-01-24

## Quick Status

| Component | Status | Notes |
|-----------|--------|-------|
| Backend API | ✅ Complete | FastAPI on Lambda, 92 tests |
| iOS App | ✅ Mostly Complete | SwiftUI, SwiftData, 31 tests |
| Infrastructure | 🟡 Dev Only | Prod deployment pending |
| Auth | 🟡 Dev Mode | Apple Sign In awaiting approval |
| CI/CD | ✅ Complete | GitHub Actions |

## Active Blockers

1. **Apple Sign In** (#15) - Requires Apple Developer approval
2. **Production Deploy** (#16) - Need to create prod Pulumi stack

## Current Bugs

| # | Issue | Priority |
|---|-------|----------|
| 11 | Auth token not persisted across relaunch | High |
| 12 | Push notifications not configured | Medium |
| 30 | Google connection requires re-auth | Medium |
| 31 | Console logging spam on device | Low |

## Completed Phases

- ✅ Project foundation & repo setup
- ✅ Architecture & research
- ✅ Backend infrastructure (Lambda, DynamoDB, API Gateway)
- ✅ API development (all endpoints)
- ✅ iOS app foundation (MVVM, SwiftData, networking)
- ✅ Core features (visit tracking, stats, offline, sync)
- ✅ Friends & sharing (backend + iOS UI)
- ✅ Location tracking & iOS Widget prep
- ✅ Google import (Calendar & Gmail)

## Pending Work

### Infrastructure
- [ ] Production AWS deployment (#16)
- [ ] Configure production APNS (#12)

### iOS Polish
- [ ] Accessibility improvements (#21)
- [ ] UI tests (#22)
- [ ] Performance testing (#23)
- [ ] Animated splash screen (#28)
- [ ] Data export/share (#20)

### Feature Backlog
See GitHub issues for full roadmap. Key upcoming features:
- Bucket list mode (#33)
- Travel timeline (#34)
- Photos & memories (#35, #36)
- Badges & achievements (#37)
- National Parks (#40)

## Development Commands

```bash
# Backend
cd backend && uv run python -m pytest tests/ -v

# iOS (macOS only)
xcodebuild test -scheme Footprint -destination 'platform=iOS Simulator,name=iPhone 17'

# Infrastructure
cd infrastructure && pulumi preview

# GitHub CLI (if not installed)
curl -sL https://github.com/cli/cli/releases/download/v2.40.1/gh_2.40.1_linux_amd64.tar.gz | tar xz
mv gh_*/bin/gh ~/.local/bin/
```

## Issue Labels for Workflow

| Label | Meaning |
|-------|---------|
| `agent-friendly` | Can be completed autonomously |
| `quick-win` | Small, fast task |
| `needs-user-input` | Requires human decisions |
| `needs-clarification` | Requirements unclear |
| `complex` | Large feature, needs breakdown |
| `external-dependency` | Blocked by external service |
