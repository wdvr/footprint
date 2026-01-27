import XCTest
import MapKit

final class ScreenshotTests: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false

        app = XCUIApplication()
        setupSnapshot(app)

        // Reset app state for consistent screenshots
        app.launchArguments = [
            "-ApplePersistenceIgnoreState", "YES",
            "-UITestingMode", "YES",
            "-DisableAnimations", "YES",
            "-SampleDataMode", "YES"
        ]

        app.launch()

        // Wait for app to fully load
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10))
        sleep(2) // Allow time for initial UI setup
    }

    override func tearDownWithError() throws {
        app?.terminate()
        app = nil
    }

    // MARK: - Screenshots for App Store

    func testScreenshot01_MapViewWithVisitedCountries() throws {
        // Skip authentication for screenshots
        skipAuthenticationIfPresent()

        // Navigate to map view (should be default)
        let mapTab = app.tabBars.buttons["Map"]
        if mapTab.exists {
            mapTab.tap()
        }

        // Wait for map to load
        let mapView = app.maps.firstMatch
        XCTAssertTrue(mapView.waitForExistence(timeout: 5))

        // Add some sample visited countries for the screenshot
        addSampleVisitedCountries()

        // Wait for map overlays to render
        sleep(3)

        snapshot("01_MapView")
    }

    func testScreenshot02_CountriesListView() throws {
        skipAuthenticationIfPresent()

        // Navigate to countries tab
        let countriesTab = app.tabBars.buttons["Countries"]
        XCTAssertTrue(countriesTab.waitForExistence(timeout: 5))
        countriesTab.tap()

        // Wait for list to load
        sleep(2)

        // Expand a continent section to show more detail
        let africaButton = app.buttons["Africa: 8/54 countries"]
        if africaButton.exists {
            africaButton.tap()
            sleep(1)
        }

        snapshot("02_CountriesList")
    }

    func testScreenshot03_StatsView() throws {
        skipAuthenticationIfPresent()

        // Navigate to stats tab
        let statsTab = app.tabBars.buttons["Stats"]
        XCTAssertTrue(statsTab.waitForExistence(timeout: 5))
        statsTab.tap()

        // Wait for stats to load
        sleep(2)

        snapshot("03_Stats")
    }

    func testScreenshot04_StateMapView() throws {
        skipAuthenticationIfPresented()

        // Go to map view first
        let mapTab = app.tabBars.buttons["Map"]
        if mapTab.exists {
            mapTab.tap()
        }

        // Wait for map to load
        sleep(2)

        // Tap on United States to show state view
        let usRegion = app.maps.firstMatch
        usRegion.coordinate(withNormalizedOffset: CGVector(dx: 0.25, dy: 0.45)).tap() // Approximate US location

        // Look for "View States" button or state detail sheet
        let viewStatesButton = app.buttons["View States"]
        if viewStatesButton.waitForExistence(timeout: 3) {
            viewStatesButton.tap()
        }

        // Wait for state map to load
        sleep(3)

        snapshot("04_StateMap")
    }

    func testScreenshot05_SettingsView() throws {
        skipAuthenticationIfPresent()

        // Navigate to settings tab
        let settingsTab = app.tabBars.buttons["Settings"]
        XCTAssertTrue(settingsTab.waitForExistence(timeout: 5))
        settingsTab.tap()

        // Wait for settings to load
        sleep(2)

        snapshot("05_Settings")
    }

    // MARK: - Helper Methods

    private func skipAuthenticationIfPresent() {
        // Look for login screen and skip it
        let continueWithoutAccountButton = app.buttons["Continue without account"]
        if continueWithoutAccountButton.waitForExistence(timeout: 3) {
            continueWithoutAccountButton.tap()
            sleep(2)
        }

        // Alternative: look for Sign in with Apple and skip
        let signInWithAppleButton = app.buttons["Sign in with Apple"]
        if signInWithAppleButton.exists {
            // If we see login screen, try to find skip option or handle it
            if continueWithoutAccountButton.exists {
                continueWithoutAccountButton.tap()
                sleep(2)
            }
        }
    }

    private func addSampleVisitedCountries() {
        // In sample data mode, the app should have pre-populated data
        // This method ensures we have good visual data for screenshots

        // For UI testing, we'll rely on the app's sample data mode
        // The app should show several visited countries when launched with -SampleDataMode

        // Additional countries can be marked by tapping on the map
        let mapView = app.maps.firstMatch

        // Tap on a few strategic locations to mark them as visited
        let locations = [
            CGVector(dx: 0.15, dy: 0.3),  // Europe
            CGVector(dx: 0.8, dy: 0.4),   // Asia
            CGVector(dx: 0.05, dy: 0.6),  // South America
            CGVector(dx: 0.45, dy: 0.35), // North America
        ]

        for location in locations {
            mapView.coordinate(withNormalizedOffset: location).tap()
            sleep(0.5)
        }
    }

    private func skipAuthenticationIfPresented() {
        // Check for login screen elements
        if app.staticTexts["Track your travels around the world"].exists {
            let continueButton = app.buttons["Continue without account"]
            if continueButton.exists {
                continueButton.tap()
                sleep(2)
            }
        }
    }
}

// MARK: - Snapshot Helper

extension ScreenshotTests {
    func snapshot(_ name: String, timeWaitingForIdle timeout: TimeInterval = 20) {
        // Use fastlane's snapshot function if available, otherwise XCUIScreen
        #if SNAPSHOT
        Snapshot.snapshot(name, timeWaitingForIdle: timeout)
        #else
        // Fallback for manual testing
        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        #endif
    }
}