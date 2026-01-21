# Claude Working Instructions - Skratch Travel Tracker

## Project Overview
This is a travel tracking application that allows users to mark countries, US states, and Canadian provinces they have visited on an interactive world map. The app focuses on simple, intuitive tracking with offline sync capabilities and beautiful data visualization.

## Tech Stack

### Frontend (iOS)
- **Language**: Swift 6
- **UI Framework**: SwiftUI
- **IDE**: Xcode 26
- **Target**: iOS app compatible with Mac and iPhone
- **Authentication**: Sign in with Apple
- **Offline Storage**: SwiftData for offline-first architecture
- **Map Framework**: MapKit with custom overlays

### Backend (AWS)
- **Language**: Python
- **Infrastructure**: AWS (API Gateway, Lambda, DynamoDB)
- **Deployment**: Lambda
- **Infrastructure as Code**: Pulumi
- **Database**: DynamoDB
- **File Storage**: S3 (for map data and assets)

### Development Workflow
- **Version Control**: Git with GitHub (private repository)
- **Workflow**: Pull Request based development with frequent commits
- **Permissions**: Use dangerously disable sandbox after initial setup
- **Testing**: Comprehensive automated testing for all components

## iOS Development Tools & Setup (2026)

### Modern iOS Development Stack
- **Xcode 26**: 35% faster build times, AI-powered code assistance, instant SwiftUI previews
- **Swift 6**: Enhanced performance, reduced boilerplate with macros, better type checking
- **SwiftUI**: Declarative UI with live previews, new container views, material-aware animations
- **MapKit**: For interactive world map with custom region highlighting
- **SwiftData**: Modern replacement for CoreData for offline storage
- **Combine**: Reactive programming for handling sync operations

### Key Features in Xcode 26
- Instant SwiftUI previews that behave like real app
- Timeline view for tracing async operations
- AI code assistant integration
- Enhanced debugging tools
- Live render previews

### Best Practices
- Use native Swift/SwiftUI for maximum performance
- Implement proper testing (unit, integration, UI tests)
- Follow accessibility guidelines (VoiceOver, Dynamic Type, high contrast)
- Leverage async/await for API calls and sync operations
- Use MVVM architecture pattern
- Offline-first data architecture with background sync

## Environment Setup

### Required Files
- `.env` - AWS credentials and configuration
- `.gitignore` - Standard Swift/Python ignores plus AWS secrets
- `Pulumi.yaml` - Infrastructure configuration

### AWS Services
- **API Gateway**: REST API endpoints for user data sync
- **Lambda**: Serverless functions for data processing and sync
- **DynamoDB**: User profiles, visited places, sync metadata
- **S3**: Geographic data, map assets, user exports
- **CloudWatch**: Monitoring and logging
- **Cognito**: User authentication (Apple Sign In integration)

### Geographic Data Sources
Research needed for:
- **Countries**: ISO 3166 country codes and boundaries
- **US States**: State boundaries and coordinates
- **Canadian Provinces**: Provincial boundaries and coordinates
- **Map Data**: High-quality boundary files for visualization

## Development Workflow

### Git Workflow - COMMIT FREQUENTLY
1. **Frequent Commits**: Commit every logical change, don't batch work
2. **Feature Branches**: Create branches from main for each feature/fix
3. **Clear Messages**: Use descriptive commit messages explaining the "why"
4. **Pull Requests**: ALL changes must go through PR review process
5. **PR Requirements**:
   - All tests must pass
   - Code review approval required
   - No direct pushes to main
6. **Merge Strategy**: Squash and merge for clean history

### Testing Strategy - TEST EVERYTHING

#### Backend Testing (Python)
- **Unit Tests**: Test all services, models, and utilities (`pytest`)
- **Integration Tests**: Test Lambda functions end-to-end
- **API Tests**: Test all REST endpoints with various inputs
- **Database Tests**: Test DynamoDB operations with mocked tables
- **Local Lambda Testing**: Use SAM CLI or localstack for local testing
- **Coverage**: Aim for >90% code coverage

#### Frontend Testing (iOS/Swift)
- **Unit Tests**: Test ViewModels, services, and business logic (`XCTest`)
- **UI Tests**: Test user flows and map interactions
- **Snapshot Tests**: Verify UI layout consistency
- **Network Tests**: Mock API calls and test offline/sync scenarios
- **Device Tests**: Test on multiple iOS versions and devices
- **Map Tests**: Test geographic calculations and region highlighting

#### Infrastructure Testing
- **Pulumi Tests**: Validate infrastructure configuration
- **Security Tests**: Scan for IAM policy issues and vulnerabilities
- **Performance Tests**: Load testing for API endpoints
- **Deployment Tests**: Verify infrastructure deploys correctly

#### Automated Testing Pipeline
- **GitHub Actions**: Run tests on every PR and push
- **Local Testing**: Commands to run all tests locally before push
- **Pre-commit Hooks**: Run linting and quick tests before commits
- **Test Environments**: Separate dev/staging/prod with test data

#### Local Development Testing Commands
```bash
# Backend testing
cd backend
python -m pytest tests/ -v --cov=src --cov-report=html

# Lambda local testing
sam local start-api
sam local invoke UserSyncFunction

# Infrastructure testing
cd infrastructure
pulumi preview --diff

# iOS testing (from Xcode or command line)
xcodebuild test -scheme Skratch -destination 'platform=iOS Simulator,name=iPhone 15'
```

### Initial Geographic Regions
- **Countries**: All 195 UN member states
- **US States**: All 50 states + DC
- **Canadian Provinces**: 10 provinces + 3 territories

### Project Structure
```
skratch/
├── ios/              # SwiftUI iOS app
├── backend/          # Python Lambda functions
├── infrastructure/   # Pulumi AWS setup
├── data/            # Geographic boundary files
├── .env             # Environment variables
├── README.md        # Project overview
├── claude.md        # This file
└── progress.md      # Task tracking and status
```

## Key Features to Implement

### Core Functionality
1. **Interactive World Map**: Pan, zoom, tap to select regions
2. **Visit Tracking**: Mark countries, states, provinces as visited
3. **Progress Statistics**: Calculate percentages and visit counts
4. **Offline-First**: Works without internet, syncs when connected
5. **Data Export**: Generate shareable travel maps and statistics

### Technical Implementation
1. **Backend API**: User authentication, data sync, statistics
2. **iOS App**: Map interface, offline storage, sync management
3. **Geographic Engine**: Boundary detection, region calculations
4. **Sync System**: Conflict resolution, offline queue, background sync

## Research Tasks
- [ ] Geographic boundary data sources and formats
- [ ] MapKit custom overlay implementation
- [ ] Offline-first architecture patterns
- [ ] Data sync conflict resolution strategies
- [ ] iOS app store requirements for travel apps
- [ ] AWS cost optimization for geographic applications

## Development Phases
See `progress.md` for detailed task breakdown and current status.

---

**Architecture Philosophy:**
- Offline-first: App should work perfectly without internet
- Privacy-focused: Minimal data collection, user owns their data
- Simple UX: Focus on core travel tracking without feature bloat
- Performance: Smooth map interactions, fast sync
- Accessibility: VoiceOver support, Dynamic Type, high contrast