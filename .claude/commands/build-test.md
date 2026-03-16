# Build and Test Footprint

## iOS

```bash
# Generate project
cd ios && xcodegen generate

# Build
xcodebuild -project Footprint.xcodeproj -scheme Footprint \
  -destination 'platform=iOS Simulator,name=iPhone 17' build

# Unit tests
xcodebuild test -project Footprint.xcodeproj -scheme Footprint \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:FootprintTests -quiet

# UI tests
xcodebuild test -project Footprint.xcodeproj -scheme Footprint \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:FootprintUITests -quiet

# Deploy to physical device (i17pw)
# 1. Unlock the CI signing keychain for codesign access
security unlock-keychain -p "ios-signing-shared" ~/ios-signing.keychain-db
# 2. Build for device
xcodebuild -project Footprint.xcodeproj -scheme Footprint \
  -destination 'id=00008150-001625E20AE2401C' -allowProvisioningUpdates build
# 3. Restore default keychain so local Xcode signing still works
security default-keychain -s ~/Library/Keychains/login.keychain-db
# 4. Install and launch
xcrun devicectl device install app --device 00008150-001625E20AE2401C \
  ~/Library/Developer/Xcode/DerivedData/Footprint-*/Build/Products/Debug-iphoneos/Footprint.app
xcrun devicectl device process launch --device 00008150-001625E20AE2401C com.wouterdevriendt.footprint
```

## Backend

```bash
cd backend
uv sync  # or: pip install -r requirements.txt

# Run tests
uv run python -m pytest tests/ -v --cov=src

# Linting
uv run ruff check src/ tests/
uv run ruff format --check src/ tests/
```

## Notes
- iOS: XcodeGen-based (regenerate after project.yml changes)
- Backend: Python 3.11, FastAPI, uv for dependency management
- Device ID: `00008150-001625E20AE2401C` (i17pw)
- Signing keychain: `~/ios-signing.keychain-db` (password: `ios-signing-shared`)
- ALWAYS restore default keychain to login after device builds
- ALWAYS test in simulator before deploying to device
