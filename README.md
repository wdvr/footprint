# Skratch Travel Tracker

A beautiful iOS app for tracking your travels on an interactive world map. Mark countries, US states, and Canadian provinces you've visited, see your progress statistics, and share your travel achievements.

## ✨ Features

- **Interactive World Map**: Intuitive tap-to-select interface using native MapKit
- **Comprehensive Coverage**: Track visits to 195 countries, 50 US states + DC, and 13 Canadian provinces/territories
- **Offline-First**: Works perfectly without internet connection, syncs when connected
- **Privacy-Focused**: Sign in with Apple, your data stays yours
- **Beautiful Statistics**: See your travel progress with elegant visualizations
- **Data Export**: Share your travel map and generate statistics

## 🛠 Tech Stack

### Frontend
- **iOS**: Swift 6 + SwiftUI
- **Maps**: MapKit with custom overlays
- **Storage**: SwiftData for offline-first architecture
- **Auth**: Sign in with Apple

### Backend
- **Infrastructure**: AWS (Lambda, API Gateway, DynamoDB)
- **Language**: Python 3.11
- **IaC**: Pulumi for infrastructure management
- **Storage**: S3 for geographic data and exports

## 🚀 Getting Started

### Prerequisites
- Xcode 26 or later
- iOS 17.0+ deployment target
- AWS account for backend services
- GitHub CLI for repository management

### Development Setup

1. **Clone the repository**
   ```bash
   git clone https://github.com/wdvr/skratch.git
   cd skratch
   ```

2. **Setup environment variables**
   ```bash
   cp .env.template .env
   # Edit .env with your AWS credentials
   ```

3. **Install backend dependencies**
   ```bash
   cd backend
   pip install -r requirements.txt
   ```

4. **Deploy infrastructure**
   ```bash
   cd infrastructure
   pulumi up
   ```

5. **Open iOS project**
   ```bash
   open ios/Skratch.xcodeproj
   ```

## 📁 Project Structure

```
skratch/
├── ios/              # SwiftUI iOS application
│   ├── Skratch/      # Main app target
│   ├── SkratchTests/ # Unit tests
│   └── SkratchUITests/ # UI tests
├── backend/          # Python Lambda functions
│   ├── src/          # Source code
│   ├── tests/        # Backend tests
│   └── requirements.txt
├── infrastructure/   # Pulumi AWS infrastructure
│   ├── __main__.py   # Infrastructure definition
│   └── Pulumi.yaml   # Project configuration
├── data/            # Geographic boundary data
└── docs/            # Additional documentation
```

## 🗺 Geographic Data

The app includes comprehensive geographic data:
- **Countries**: All 195 UN member states with accurate boundaries
- **US States**: 50 states plus District of Columbia
- **Canadian Regions**: 10 provinces and 3 territories

Data sources are optimized for mobile performance while maintaining geographic accuracy.

## 🧪 Testing

Run the test suites:

```bash
# Backend tests
cd backend
python -m pytest tests/ -v --cov=src

# iOS tests
cd ios
xcodebuild test -scheme Skratch -destination 'platform=iOS Simulator,name=iPhone 15'
```

## 📱 App Architecture

- **MVVM Pattern**: Clear separation of concerns with SwiftUI
- **Offline-First**: Local-first architecture with background sync
- **Reactive Updates**: Combine framework for real-time data flow
- **Geographic Engine**: Efficient point-in-polygon calculations
- **Conflict Resolution**: Smart merging for simultaneous edits

## 🔒 Privacy & Security

- **Minimal Data Collection**: Only travel progress is stored
- **User Ownership**: Full data export and deletion capabilities
- **Apple Sign In**: No email collection, enhanced privacy
- **Secure Sync**: End-to-end encryption for cloud synchronization

## 📈 Development Workflow

We follow a strict pull request workflow:
- All changes require PR review
- Comprehensive test coverage required
- Frequent commits with clear messages
- No direct pushes to main branch

See `claude.md` for detailed development guidelines and `progress.md` for current task status.

## 🚀 Deployment

The app uses AWS infrastructure for scalable, reliable backend services:
- **API Gateway**: RESTful API endpoints
- **Lambda**: Serverless compute for data processing
- **DynamoDB**: NoSQL database for user data
- **S3**: Geographic data and user exports
- **CloudWatch**: Monitoring and logging

## 📄 License

Private repository - All rights reserved.

## 🤝 Contributing

This is a private project. See `claude.md` for development guidelines if you have access.

---

**Built with ❤️ for travel enthusiasts**
