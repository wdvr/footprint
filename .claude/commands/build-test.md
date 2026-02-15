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

# Deploy to physical device
xcodebuild -project Footprint.xcodeproj -scheme Footprint \
  -destination 'id=00008150-001625E20AE2401C' -configuration Debug build
xcrun devicectl device install app --device 00008150-001625E20AE2401C \
  ~/Library/Developer/Xcode/DerivedData/Footprint-*/Build/Products/Debug-iphoneos/Footprint.app
xcrun devicectl device process launch --device 00008150-001625E20AE2401C com.wd.footprint.app
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
- Device ID: `00008150-001625E20AE2401C`
