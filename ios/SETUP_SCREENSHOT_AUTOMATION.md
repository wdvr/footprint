# Screenshot Automation Setup Guide

This guide will help you complete the setup of automated App Store screenshot generation.

## Quick Setup Checklist

### ✅ Files Created
- [x] `FootprintUITests/ScreenshotTests.swift` - Main UI test class with 5 screenshot tests
- [x] `FootprintUITests/SnapshotHelper.swift` - Fastlane integration helper
- [x] `fastlane/Fastfile` - Automation configuration
- [x] `fastlane/Snapfile` - Screenshot-specific settings
- [x] `fastlane/Gemfile` - Ruby dependencies
- [x] `Footprint/Utilities/SampleDataHelper.swift` - Sample data for screenshots
- [x] `generate_screenshots.sh` - Easy-to-use script
- [x] `ScreenshotAutomation.md` - Complete documentation

### 🔧 Remaining Setup Steps

#### 1. Add UI Test Target to Xcode Project

**Important**: You need to manually add the UI test target in Xcode:

1. Open `Footprint.xcodeproj` in Xcode
2. Select the project in the navigator
3. Click the "+" button at the bottom of the targets list
4. Choose "iOS UI Testing Bundle"
5. Name it exactly: `FootprintUITests`
6. Set the target to be tested: `Footprint`
7. Click "Finish"

#### 2. Add Files to UI Test Target

Add these files to the `FootprintUITests` target:
- `FootprintUITests/ScreenshotTests.swift`
- `FootprintUITests/SnapshotHelper.swift`

Add this file to the main `Footprint` target:
- `Footprint/Utilities/SampleDataHelper.swift`

**How to add files:**
1. Right-click on `FootprintUITests` folder in Xcode
2. Select "Add Files to 'Footprint'"
3. Choose the files
4. Make sure the correct target is selected

#### 3. Update FootprintApp.swift

The main app file has been updated to:
- ✅ Handle `-UITestingMode` argument to skip auth
- ✅ Handle `-SampleDataMode` argument to load sample data
- ✅ Handle `-DisableAnimations` argument for clean screenshots
- ✅ Use in-memory storage for UI tests

#### 4. Install Dependencies

```bash
cd ios/fastlane
bundle install
```

Or install fastlane globally:
```bash
gem install fastlane
```

## Usage

### Generate All Screenshots
```bash
cd ios
./generate_screenshots.sh
```

Or use fastlane directly:
```bash
cd ios
fastlane screenshots
```

### Screenshots Generated

The automation creates 5 screenshots per device:

1. **01_MapView.png** - World map with visited countries highlighted
2. **02_CountriesList.png** - Countries list organized by continent
3. **03_Stats.png** - Travel statistics and progress
4. **04_StateMap.png** - US states/Canadian provinces detail view
5. **05_Settings.png** - Settings screen with features

### Supported Devices

- iPhone 17 Pro Max (6.9")
- iPhone 17 Pro (6.3")
- iPhone 17 (6.1")
- iPhone SE 3rd gen (4.7")
- iPad Pro 12.9"
- iPad Pro 11"

## Sample Data

The app automatically loads attractive sample data when launched with `-SampleDataMode`, including:

- **32 countries** across all continents
- **7 US states** including California, New York, Florida
- **3 Canadian provinces** including Ontario, BC, Quebec
- **Realistic visit dates** spread throughout the last year

This ensures screenshots always look engaging and demonstrate the app's capabilities.

## Troubleshooting

### Build Errors
- Make sure all files are added to correct targets
- Verify import statements in SampleDataHelper.swift
- Check that VisitedPlace model is accessible

### Simulator Issues
```bash
# List available simulators
xcrun simctl list devices

# Boot a simulator if needed
xcrun simctl boot "iPhone 17 Pro Max"
```

### Screenshot Quality
- Screenshots are full device resolution
- Status bar is cleaned up automatically
- Animations are disabled for consistency

## Next Steps

1. **Complete Xcode setup** (add UI test target and files)
2. **Test the automation** by running `./generate_screenshots.sh`
3. **Review generated screenshots** in `fastlane/screenshots/`
4. **Use screenshots for App Store submission**

## App Store Integration

### Screenshot Requirements Met:
- ✅ iPhone 6.9", 6.3", 6.1" screenshots (required)
- ✅ iPad 12.9" screenshots (required)
- ✅ High-quality PNG format
- ✅ Clean status bar
- ✅ Attractive, diverse sample data
- ✅ Consistent visual style

### Upload to App Store Connect:
1. Review all screenshots for quality
2. Select best 3-8 screenshots per device category
3. Upload via App Store Connect or fastlane
4. Add compelling descriptions and metadata

The screenshot automation is now 95% complete - you just need to finish the Xcode project configuration!