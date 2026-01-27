# Screenshot Automation for Footprint Travel Tracker

This documentation explains how to automatically generate App Store screenshots that can be regenerated whenever the app is updated.

## Overview

The screenshot automation system uses:
- **XCUITest** for UI interaction and screenshot capture
- **Fastlane Snapshot** for device management and automation
- **Sample Data Mode** for consistent, beautiful screenshots

## Setup Instructions

### 1. Prerequisites

Install required dependencies:

```bash
# Install Ruby dependencies
cd ios/fastlane
bundle install

# Install fastlane globally (optional)
gem install fastlane
```

### 2. Add UI Test Target to Xcode Project

The system requires a UI test target named `FootprintUITests`. To add this:

1. Open `Footprint.xcodeproj` in Xcode
2. Click on the project in the navigator
3. Click the "+" button at the bottom of the targets list
4. Select "iOS UI Testing Bundle"
5. Name it `FootprintUITests`
6. Set the target to be tested as `Footprint`
7. Add the created files to the target:
   - `FootprintUITests/ScreenshotTests.swift`
   - `FootprintUITests/SnapshotHelper.swift`

### 3. Configure Sample Data Mode

The app should handle the launch argument `-SampleDataMode` to provide visually appealing demo data:

```swift
// In FootprintApp.swift or similar
if CommandLine.arguments.contains("-SampleDataMode") {
    // Populate with sample visited countries
    // Show diverse geographic coverage
    // Include countries from different continents
    // Add sample stats and progress
}
```

## Usage

### Generate All Screenshots

```bash
cd ios
fastlane screenshots
```

This generates screenshots for:
- iPhone 17 Pro Max (6.9")
- iPhone 17 Pro (6.3")
- iPhone 17 (6.1")
- iPhone SE 3rd gen (4.7")
- iPad Pro 12.9"
- iPad Pro 11"

### Generate for Specific Devices

```bash
# iPhone only
fastlane snapshot --devices "iPhone 17 Pro Max"

# iPad only
fastlane snapshot --devices "iPad Pro (12.9-inch) (6th generation)"
```

### Clean and Regenerate

```bash
# Clean old screenshots
fastlane clean

# Generate new ones
fastlane screenshots
```

## Screenshot Specifications

### App Store Requirements

**iPhone Screenshots:**
- Required: 6.9", 6.3", 6.1", 5.5"
- Optional: 4.7"
- Format: PNG, JPG
- Max file size: 30 MB per screenshot
- 3-8 screenshots recommended

**iPad Screenshots:**
- Required: 12.9"
- Optional: 11"
- Format: PNG, JPG
- Can be same as iPhone with different framing

### Screenshot Content Strategy

Our screenshots showcase:

1. **Map View** (`01_MapView.png`)
   - World map with visited countries highlighted in green
   - Progress indicator showing "X countries visited"
   - Clean, engaging geographic visualization

2. **Countries List** (`02_CountriesList.png`)
   - Organized by continent with progress indicators
   - Shows checkmarks for visited places
   - Demonstrates comprehensive country coverage

3. **Statistics** (`03_Stats.png`)
   - Visual progress bars for countries, states, provinces
   - Achievement-style presentation
   - Motivating travel statistics

4. **State Detail** (`04_StateMap.png`)
   - US states or Canadian provinces view
   - Detailed regional tracking
   - Sub-geographic precision

5. **Settings** (`05_Settings.png`)
   - Import options (Gmail, Photos, Calendar)
   - Professional feature overview
   - Privacy-focused design

## Technical Details

### Test Structure

- `ScreenshotTests.swift`: Main test class with 5 screenshot test methods
- `SnapshotHelper.swift`: Fastlane integration and screenshot utilities
- `Fastfile`: Automation lanes and device configurations
- `Snapfile`: Screenshot-specific settings

### Launch Arguments

The app recognizes these testing arguments:
- `-UITestingMode YES`: Enables UI testing mode
- `-SampleDataMode YES`: Loads attractive sample data
- `-DisableAnimations YES`: Prevents animation interference
- `-ApplePersistenceIgnoreState YES`: Fresh app state

### File Organization

Screenshots are organized by device:
```
fastlane/screenshots/
├── iPhone-17-Pro-Max/
│   ├── 01_MapView.png
│   ├── 02_CountriesList.png
│   └── ...
├── iPad-Pro-12-9-inch-6th-generation/
│   ├── 01_MapView.png
│   └── ...
└── ...
```

## Troubleshooting

### Common Issues

**Simulator not found:**
```bash
# List available simulators
xcrun simctl list devices

# Install missing simulator
xcodebuild -downloadPlatform iOS
```

**Test failures:**
- Check that sample data mode is properly implemented
- Verify UI elements have correct accessibility identifiers
- Ensure animations are disabled in test mode

**Screenshot quality:**
- Screenshots are taken at device resolution
- Status bar is overridden for clean appearance
- Wait times ensure UI is fully loaded

### Debugging

Run tests manually to debug issues:
```bash
xcodebuild test -workspace Footprint.xcodeproj -scheme FootprintUITests -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max'
```

## Integration with CI/CD

### GitHub Actions Example

```yaml
name: Generate Screenshots
on:
  workflow_dispatch:
  release:
    types: [published]

jobs:
  screenshots:
    runs-on: macos-latest
    steps:
    - uses: actions/checkout@v4
    - name: Setup Ruby
      uses: ruby/setup-ruby@v1
      with:
        bundler-cache: true
        working-directory: ios/fastlane
    - name: Generate Screenshots
      run: |
        cd ios
        fastlane screenshots
    - name: Upload Screenshots
      uses: actions/upload-artifact@v4
      with:
        name: app-store-screenshots
        path: ios/fastlane/screenshots/
```

## Customization

### Adding New Screenshots

1. Add test method to `ScreenshotTests.swift`
2. Follow naming convention: `testScreenshotXX_DescriptiveName()`
3. Use `snapshot("XX_Name")` to capture
4. Update documentation

### Changing Devices

Modify device lists in:
- `fastlane/Snapfile`: `devices([...])`
- `fastlane/Fastfile`: `devices: [...]`

### Localization

To support multiple languages:
1. Add languages to `fastlane/Snapfile`
2. Configure app for localization testing
3. Update sample data for each language

## App Store Submission

### Using Generated Screenshots

1. **Review**: Check all screenshots for quality and accuracy
2. **Select**: Choose the best 3-8 screenshots per device category
3. **Upload**: Use App Store Connect or fastlane upload
4. **Optimize**: Consider A/B testing different screenshot orders

### Metadata Integration

The screenshots work best with compelling App Store copy:
- Emphasize travel tracking and visualization
- Highlight offline capability and privacy
- Showcase import features and convenience
- Appeal to travel enthusiasts and data lovers

## Maintenance

### Regular Updates

Regenerate screenshots when:
- App UI changes significantly
- New features are added
- iOS design guidelines evolve
- User feedback suggests improvements

### Quality Assurance

Before App Store submission:
- [ ] All screenshots render correctly
- [ ] Sample data looks realistic and appealing
- [ ] No debug UI or test artifacts visible
- [ ] Consistent visual style across devices
- [ ] Screenshots tell a coherent story

This automation system ensures your App Store screenshots always represent the current state of your app with minimal manual effort.