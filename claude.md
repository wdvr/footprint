# Claude Working Instructions - Footprint Travel Tracker

## Quick Start

### Environment Setup
```bash
# GitHub CLI (required for issue management)
# If gh is not installed (common on mobile/remote environments):
curl -sL https://github.com/cli/cli/releases/download/v2.40.1/gh_2.40.1_linux_amd64.tar.gz | tar xz
mkdir -p ~/.local/bin && mv gh_*/bin/gh ~/.local/bin/
export PATH="$HOME/.local/bin:$PATH"

# GitHub authentication is available via GITHUB_TOKEN environment variable
# Verify: gh auth status

# Backend tests
cd backend && uv run python -m pytest tests/ -v

# iOS tests (on macOS only)
xcodebuild test -project ios/Footprint.xcodeproj -scheme Footprint -destination 'platform=iOS Simulator,name=iPhone 17'
```

### Project Structure
```
footprint/
├── ios/              # SwiftUI iOS app (Swift 6, SwiftData)
├── backend/          # Python FastAPI Lambda functions
├── infrastructure/   # Pulumi AWS setup
├── docs/             # Architecture docs
├── .github/          # CI/CD workflows
└── progress.md       # Current status
```

## Tech Stack

| Layer | Technology |
|-------|------------|
| iOS | Swift 6, SwiftUI, SwiftData, MapKit |
| Backend | Python 3.11, FastAPI, AWS Lambda |
| Database | DynamoDB (single-table design) |
| Infrastructure | Pulumi, API Gateway, S3, CloudWatch |
| Auth | Sign in with Apple + Dev mode fallback |
| CI/CD | GitHub Actions |

## Development Workflow

### Agent/Human Collaboration
This project uses a hybrid workflow. Check issue labels:
- `agent-friendly` - Can be done autonomously
- `quick-win` - Small, fast tasks
- `needs-user-input` - Requires human decisions
- `needs-clarification` - Requirements unclear
- `complex` - Large features, may need breakdown
- `external-dependency` - Blocked by external factors
- `blocked` - Cannot proceed

### Git Workflow
1. Create feature branch from main
2. Make changes with frequent commits
3. Run tests before PR
4. All changes go through PR review

### Testing Requirements
Always run tests before submitting PRs:
- **Backend**: `cd backend && uv run python -m pytest tests/ -v`
- **iOS**: `xcodebuild test -scheme Footprint -destination 'platform=iOS Simulator,name=iPhone 17'`

### Deploy to Physical Device (macOS only)
```bash
cd /Users/wouter/dev/footprint/ios
xcodebuild -project Footprint.xcodeproj -scheme Footprint -destination 'id=00008150-001625E20AE2401C' build
xcrun devicectl device install app --device 00008150-001625E20AE2401C [path-to-app]
xcrun devicectl device process launch --device 00008150-001625E20AE2401C com.wd.footprint.app
```

## Key APIs & Endpoints

Base URL (dev): `https://jz0gkkwq8b.execute-api.us-east-1.amazonaws.com/dev`

| Endpoint | Description |
|----------|-------------|
| POST /auth/dev | Dev mode auth (device ID) |
| POST /auth/apple | Apple Sign In |
| GET /users/me | Current user profile |
| GET/POST /places | Visited places CRUD |
| POST /sync | Sync local changes |
| POST /import/google/* | Google Calendar/Gmail import |

## Architecture Notes

### Offline-First Design
- SwiftData for local persistence
- Background sync when online
- Version-based conflict resolution
- Works fully offline

### Data Models
- **Country**: ISO codes, names, continent
- **VisitedPlace**: User's visited locations with dates
- **User**: Profile, preferences, friend connections

## Current Priorities
See `progress.md` for detailed status. Key blockers:
1. Apple Developer approval for Sign in with Apple
2. Production AWS deployment

## Files to Know

| File | Purpose |
|------|---------|
| `backend/src/main.py` | FastAPI app entry |
| `backend/src/services/` | Business logic |
| `ios/Footprint/Services/APIClient.swift` | Network layer |
| `ios/Footprint/Services/SyncManager.swift` | Sync logic |
| `ios/Footprint/Models/` | SwiftData models |
| `infrastructure/__main__.py` | Pulumi AWS setup |
