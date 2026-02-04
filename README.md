# Footprint - Travel Tracker

<p align="center">
  <img src="https://footprintmaps.com/logo-120.png" alt="Footprint Logo" width="120" height="120">
</p>

<p align="center">
  <strong>Track your travels on a beautiful interactive world map</strong>
</p>

<p align="center">
  <a href="https://apps.apple.com/app/footprint-travel-tracker">
    <img src="https://img.shields.io/badge/App_Store-Coming_Soon-blue?style=flat&logo=apple" alt="App Store">
  </a>
  <a href="https://footprintmaps.com">
    <img src="https://img.shields.io/badge/Website-footprintmaps.com-green?style=flat" alt="Website">
  </a>
  <a href="https://github.com/wdvr/footprint/issues">
    <img src="https://img.shields.io/github/issues/wdvr/footprint" alt="Issues">
  </a>
</p>

---

<p align="center">
  <img src="https://footprintmaps.com/screenshot-iphone.png" alt="Footprint App Screenshot" width="300">
</p>

## Features

### Core Tracking
- **195 Countries** - Every UN member state with accurate boundaries
- **US States** - All 50 states + DC
- **Canadian Provinces** - 10 provinces + 3 territories
- **International Regions** - States/provinces for Russia, UK, France, Italy, Spain, Netherlands, Belgium, Argentina

### Smart Import
- **Apple Photos** - Automatically detect countries from your photo library's GPS data
- **Background Location** - Get notified when you visit new countries

### Stats & Gamification
- **Travel Timeline** - Track when you visited each place
- **Continent Breakdown** - See your progress by continent
- **Time Zones** - Track how many of the 24 time zones you've visited
- **Badges & Achievements** - Earn rewards for travel milestones
- **Friends Leaderboard** - Compare stats with friends

### Privacy & Sync
- **Sign in with Apple** - No email collection
- **Offline-First** - Works without internet, syncs when connected
- **iOS Widgets** - See your stats on your home screen

---

## Tech Stack

| Component | Technology |
|-----------|------------|
| **iOS App** | Swift 6, SwiftUI, SwiftData, MapKit |
| **Backend** | Python 3.11, FastAPI, AWS Lambda |
| **Database** | DynamoDB (single-table design) |
| **Infrastructure** | Pulumi, GitHub Actions |
| **Auth** | Sign in with Apple, Google OAuth |

---

## Getting Started

### Prerequisites

- **Xcode 26+** (Swift 6)
- **iOS 17.0+** deployment target
- **Python 3.11+** with [uv](https://github.com/astral-sh/uv)
- **AWS Account** with credentials configured
- **Pulumi** CLI installed

### 1. Clone & Setup Environment

```bash
git clone https://github.com/wdvr/footprint.git
cd footprint

# Copy environment template
cp .env.template .env
# Edit .env with your values:
# - PULUMI_CONFIG_PASSPHRASE
# - AWS credentials (or use AWS_PROFILE)
```

### 2. Deploy Backend Infrastructure

```bash
# Create Python virtual environment
python3 -m venv venv
source venv/bin/activate
pip install -r infrastructure/requirements.txt

# Deploy to AWS
cd infrastructure
pulumi up --yes --stack dev
```

### 3. Build iOS App

```bash
open ios/Footprint.xcodeproj
```

In Xcode:
1. Select your development team in Signing & Capabilities
2. Update the bundle identifier if needed
3. Build and run on simulator or device

---

## Authentication Setup

### Sign in with Apple

1. **Apple Developer Console** → Certificates, Identifiers & Profiles
2. Create an **App ID** with "Sign in with Apple" capability
3. Create a **Service ID** for web authentication (used by backend)
4. Create a **Key** for Sign in with Apple
5. Update `ios/Footprint/Info.plist` with your bundle ID

Required capabilities in Xcode:
- Sign in with Apple

### Google OAuth (Optional - for Calendar/Gmail import)

> Note: Google import is currently disabled in the UI but the infrastructure exists.

1. **Google Cloud Console** → Create a new project
2. **APIs & Services** → OAuth consent screen
   - Add scopes: `openid`, `profile`, `email`
   - (Optional) `gmail.readonly`, `calendar.readonly` for import features
3. **Credentials** → Create OAuth 2.0 Client ID
   - Application type: iOS
   - Bundle ID: `com.yourcompany.footprint`
4. Download `GoogleService-Info.plist` and add to Xcode project
5. Update URL schemes in `Info.plist`:
   ```xml
   <key>CFBundleURLSchemes</key>
   <array>
     <string>com.googleusercontent.apps.YOUR_CLIENT_ID</string>
   </array>
   ```

---

## Project Structure

```
footprint/
├── ios/                    # iOS App
│   ├── Footprint/          # Main app target
│   │   ├── Map/            # Map views and overlays
│   │   ├── Views/          # SwiftUI views
│   │   ├── Models/         # SwiftData models
│   │   ├── Services/       # Auth, sync, location managers
│   │   ├── Import/         # Photo/Google import features
│   │   └── Resources/      # GeoJSON boundaries, assets
│   ├── FootprintTests/     # Unit tests
│   ├── FootprintUITests/   # UI & screenshot tests
│   └── fastlane/           # App Store automation
│
├── backend/                # Python Backend
│   ├── src/
│   │   ├── api/            # FastAPI routes
│   │   ├── models/         # Pydantic models
│   │   └── services/       # Business logic
│   └── tests/              # pytest tests
│
├── infrastructure/         # AWS Infrastructure (Pulumi)
│   └── __main__.py         # Lambda, API Gateway, DynamoDB, S3, SES
│
├── website/                # Marketing website (Vite + React)
│   └── src/
│
└── scripts/                # Data processing scripts
```

---

## Development

### Running Tests

```bash
# Backend tests
cd backend
uv run python -m pytest tests/ -v

# iOS unit tests
xcodebuild test -project ios/Footprint.xcodeproj -scheme Footprint \
  -destination 'platform=iOS Simulator,name=iPhone 17'

# iOS UI tests (generates screenshots)
xcodebuild test -project ios/Footprint.xcodeproj -scheme FootprintUITests \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max'
```

### Deploying

```bash
# Deploy infrastructure
cd infrastructure
source ../venv/bin/activate
AWS_PROFILE=personal pulumi up --yes --stack dev

# Deploy website
cd website
npm run build
aws s3 sync dist s3://footprint-website-dev-ACCOUNT_ID --delete
aws cloudfront create-invalidation --distribution-id DIST_ID --paths "/*"
```

### App Store Release

```bash
cd ios/fastlane
bundle exec fastlane release
```

See [RELEASE.md](RELEASE.md) for detailed release instructions.

---

## API Endpoints

| Endpoint | Description |
|----------|-------------|
| `GET /health` | Health check |
| `POST /auth/apple` | Apple Sign In token exchange |
| `GET /sync` | Get user's visited places |
| `POST /sync` | Sync visited places |
| `GET /stats` | Get travel statistics |
| `GET /friends` | Get friends list |
| `POST /feedback` | Submit feedback |

API Base URL: `https://api.footprintmaps.com`

---

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

Please read [CLAUDE.md](CLAUDE.md) for development guidelines.

---

## Support

- **Email**: [support@footprintmaps.com](mailto:support@footprintmaps.com)
- **Issues**: [GitHub Issues](https://github.com/wdvr/footprint/issues)
- **Website**: [footprintmaps.com](https://footprintmaps.com)

---

## License

PolyForm Noncommercial License 1.0.0 - see [LICENSE](LICENSE) for details.

Free for personal and noncommercial use.

---

<p align="center">
  <strong>Built with ❤️ for travel enthusiasts</strong>
</p>
