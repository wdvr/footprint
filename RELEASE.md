# Footprint App Store Release Guide

This document outlines the complete process for releasing Footprint to the App Store, including all steps, gotchas, and automation details.

## Prerequisites

### Ruby Environment (IMPORTANT)
The system Ruby (2.6) on macOS is too old for Fastlane. You must use Homebrew Ruby:

```bash
# Check if Homebrew Ruby is installed
brew list ruby

# If not installed
brew install ruby

# Always use Homebrew Ruby for Fastlane commands
/opt/homebrew/opt/ruby/bin/bundle exec fastlane <lane>

# Or add to your shell profile (~/.zshrc)
export PATH="/opt/homebrew/opt/ruby/bin:$PATH"
```

**Gotcha**: The system `/usr/bin/ruby` is version 2.6 which doesn't support bundler 4.x. Always use `/opt/homebrew/opt/ruby/bin/ruby` for Fastlane operations.

### App Store Connect API Key
Ensure these environment variables are set (in GitHub Secrets for CI, locally for manual runs):
- `APP_STORE_CONNECT_KEY_ID`
- `APP_STORE_CONNECT_ISSUER_ID`
- `APP_STORE_CONNECT_KEY_PATH` (path to .p8 file)

## Release Process

### 1. Version Bump

Update version in multiple places:

```bash
# ios/Footprint/Info.plist
<key>CFBundleShortVersionString</key>
<string>X.Y.Z</string>

# ios/project.yml (if using XcodeGen)
MARKETING_VERSION: "X.Y.Z"

# Reset build number for new version
<key>CFBundleVersion</key>
<string>1</string>
```

Then regenerate Xcode project:
```bash
cd ios && xcodegen generate
```

### 2. Update App Store Metadata

All metadata files are in `ios/fastlane/metadata/en-US/`:

| File | Purpose | Character Limit |
|------|---------|-----------------|
| `name.txt` | App name | 30 chars |
| `subtitle.txt` | App subtitle | 30 chars |
| `description.txt` | Full description | 4000 chars |
| `keywords.txt` | Search keywords | 100 chars, comma-separated |
| `promotional_text.txt` | Promotional text (can be updated without review) | 170 chars |
| `release_notes.txt` | What's New for this version | 4000 chars |

### 3. Generate Screenshots

Run from the `ios/fastlane` directory:

```bash
cd ios/fastlane

# Install dependencies (first time or after Gemfile changes)
/opt/homebrew/opt/ruby/bin/bundle install

# Generate screenshots for iPhone only (faster)
/opt/homebrew/opt/ruby/bin/bundle exec fastlane screenshots_iphone

# Generate for all devices (required for App Store)
/opt/homebrew/opt/ruby/bin/bundle exec fastlane screenshots
```

**Gotcha**: Screenshot tests require the `FootprintUITests` scheme and `ScreenshotTests.swift` test file. Tests use launch arguments:
- `-SampleDataMode YES` - Loads sample data for attractive screenshots
- `-UITestingMode YES` - Enables UI testing mode
- `-DisableAnimations YES` - Speeds up tests

Screenshots are saved to `ios/fastlane/screenshots/` organized by device and language.

### 4. Build and Upload to TestFlight

#### Automated (GitHub Actions)
```bash
# Trigger TestFlight build
gh workflow run "iOS TestFlight Internal" --ref main
```

The workflow:
1. Builds the IPA using Xcode Cloud or local runner
2. Uploads to App Store Connect
3. Waits for Apple processing (may timeout after ~20 min)
4. Distributes to internal TestFlight testers

**Gotcha**: Apple's build processing can take 10-30+ minutes. The GitHub workflow may timeout waiting, but the build will still be available in App Store Connect.

#### Manual Upload
```bash
cd ios/fastlane
/opt/homebrew/opt/ruby/bin/bundle exec fastlane testflight_upload
```

### 5. Upload Metadata and Screenshots

```bash
cd ios/fastlane

# Upload everything (metadata + screenshots)
/opt/homebrew/opt/ruby/bin/bundle exec fastlane deliver_metadata app_version:X.Y.Z

# Upload only metadata (no screenshots)
/opt/homebrew/opt/ruby/bin/bundle exec fastlane upload_metadata_only app_version:X.Y.Z

# Upload only screenshots
/opt/homebrew/opt/ruby/bin/bundle exec fastlane upload_screenshots
```

### 6. Submit for Review

```bash
cd ios/fastlane
/opt/homebrew/opt/ruby/bin/bundle exec fastlane submit_for_review app_version:X.Y.Z
```

Or manually via App Store Connect:
1. Go to https://appstoreconnect.apple.com
2. Select Footprint > App Store > Version X.Y.Z
3. Complete all required fields
4. Click "Submit for Review"

## Fastlane Lanes Reference

| Lane | Description |
|------|-------------|
| `screenshots` | Generate screenshots for all devices |
| `screenshots_iphone` | Generate screenshots for iPhone only (faster) |
| `deliver_metadata` | Upload metadata and screenshots |
| `upload_screenshots` | Upload only screenshots |
| `upload_metadata_only` | Upload only metadata |
| `submit_for_review` | Upload everything and submit for review |
| `testflight_upload` | Build and upload to TestFlight |
| `download_metadata` | Download existing metadata from App Store Connect |

## Troubleshooting

### Ruby/Bundler Version Mismatch
```
Could not find 'bundler' (4.0.4) required by your Gemfile.lock
```
**Solution**: Use Homebrew Ruby, not system Ruby:
```bash
/opt/homebrew/opt/ruby/bin/bundle exec fastlane <lane>
```

### xcpretty Ruby Conflict
```
uninitialized constant Gem::Resolver::APISet::GemParser (NameError)
```
**Solution**: xcpretty tries to use the system Ruby. Add `xcodebuild_formatter: ""` to the Fastfile capture_screenshots call to skip xcpretty and use raw xcodebuild output instead.

### TestFlight Processing Timeout
```
Build not found after waiting
```
**Solution**: The build was uploaded successfully. Check App Store Connect directly - it will appear once Apple finishes processing.

### Screenshots Not Generating
```
xcodebuild: error: The flag -testPlan <name> cannot be used
```
**Solution**: The scheme doesn't use test plans. Remove `-testPlan` flag or update scheme settings.

### Simulator Issues
```
Failed to launch simulator
```
**Solution**:
```bash
# Reset simulators
xcrun simctl shutdown all
xcrun simctl erase all
```

### Test Crashes During Screenshot Generation
```
Test crashed with signal kill while preparing to run tests
```
**Solution**: This happens when the simulator is unstable. Try these steps in order:
1. Reset simulators: `xcrun simctl shutdown all && xcrun simctl erase all`
2. Allow more boot time with: `SNAPSHOT_SIMULATOR_WAIT_FOR_BOOT_TIMEOUT=30 bundle exec fastlane screenshots_iphone`
3. Run non-headless to observe: Remove `headless(true)` from Snapfile temporarily
4. If issues persist, take screenshots manually or use existing screenshots

### Snapfile Not Using Fastfile Settings
If `xcodebuild_formatter` or other settings in Fastfile aren't being applied, add them to `ios/fastlane/Snapfile` directly:
```ruby
# Skip xcpretty to avoid Ruby version conflicts
xcodebuild_formatter("")
```

### Swift 6 Concurrency in UI Tests (IMPORTANT)
```
Sending 'self' risks causing data races
```
**Root Cause**: Swift 6 strict concurrency requires proper actor isolation for UI tests.

**Solution**: Use `@MainActor` on the test class with `nonisolated(unsafe)` for the app property:
```swift
@MainActor
final class ScreenshotTests: XCTestCase {
    nonisolated(unsafe) var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        setupSnapshot(app)
        app.launchArguments = ["-SampleDataMode", "YES"]
        app.launch()
        _ = app.wait(for: .runningForeground, timeout: 10)
    }

    func testScreenshot() throws {
        let tab = app.tabBars.buttons["Map"]
        tab.tap()
        Thread.sleep(forTimeInterval: 2)
        snapshot("01_Map")
    }
}
```

This approach:
- Works with Swift 6 strict concurrency
- Avoids "data races" warnings
- Keeps test code clean without `MainActor.assumeIsolated` blocks

### Recommended Snapfile Stability Settings
For stable screenshot generation, add these to your Snapfile:
```ruby
concurrent_simulators(false)   # Run one at a time
erase_simulator(true)          # Clean slate each run
reinstall_app(true)            # Force reinstall
headless(false)                # Disable headless mode
localize_simulator(false)      # Disable when using reinstall_app
derived_data_path("./fastlane/DerivedData")  # Consistent build path
```

## File Structure

```
ios/
├── fastlane/
│   ├── Fastfile              # Lane definitions
│   ├── Snapfile              # Screenshot configuration
│   ├── Gemfile               # Ruby dependencies
│   ├── Gemfile.lock          # Locked versions
│   ├── metadata/
│   │   └── en-US/
│   │       ├── name.txt
│   │       ├── subtitle.txt
│   │       ├── description.txt
│   │       ├── keywords.txt
│   │       ├── promotional_text.txt
│   │       ├── release_notes.txt
│   │       ├── privacy_url.txt
│   │       └── support_url.txt
│   └── screenshots/          # Generated screenshots
├── FootprintUITests/
│   └── ScreenshotTests.swift # Screenshot test code
└── Footprint/
    └── Info.plist            # Version numbers
```

## Checklist for Each Release

- [ ] Update version in `Info.plist`
- [ ] Update version in `project.yml`
- [ ] Run `xcodegen generate`
- [ ] Update `release_notes.txt`
- [ ] Update `description.txt` if features changed
- [ ] Update `promotional_text.txt` if desired
- [ ] Generate screenshots (if UI changed)
- [ ] Commit and push changes
- [ ] Trigger TestFlight build
- [ ] Verify build in App Store Connect
- [ ] Upload metadata and screenshots
- [ ] Submit for review
- [ ] Monitor review status

## CI/CD Integration

The GitHub Actions workflow `.github/workflows/testflight.yml` automates:
1. Building the IPA
2. Uploading to App Store Connect
3. Waiting for processing
4. Distributing to internal testers

To trigger manually:
```bash
gh workflow run "iOS TestFlight Internal" --ref main
```

## Notes

- Apple's review typically takes 24-48 hours
- Promotional text can be updated anytime without review
- Screenshots are required for each device size on first submission
- Keywords are comma-separated, max 100 characters total
