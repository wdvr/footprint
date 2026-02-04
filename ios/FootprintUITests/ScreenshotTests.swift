import XCTest
import MapKit

// NOTE: Do NOT use @MainActor on XCTestCase classes - XCTest (Obj-C) doesn't support Swift actor isolation
// This causes "Test crashed with signal kill" errors. Instead, use MainActor.assumeIsolated
// for XCUITest API calls since UI tests actually run on the main thread.
final class ScreenshotTests: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false

        // All XCUITest APIs are @MainActor in Swift 6, so we need to use assumeIsolated
        MainActor.assumeIsolated {
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
            _ = app.wait(for: .runningForeground, timeout: 10)
        }
        Thread.sleep(forTimeInterval: 2) // Allow time for initial UI setup
    }

    override func tearDownWithError() throws {
        MainActor.assumeIsolated {
            app?.terminate()
        }
        app = nil
    }

    // MARK: - Screenshots for App Store

    func testScreenshot01_MapViewWithVisitedCountries() throws {
        MainActor.assumeIsolated {
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
        }

        // Wait for map overlays to render
        Thread.sleep(forTimeInterval: 3)

        snapshot("01_MapView")
    }

    func testScreenshot02_CountriesListView() throws {
        MainActor.assumeIsolated {
            skipAuthenticationIfPresent()

            // Navigate to countries tab
            let countriesTab = app.tabBars.buttons["Countries"]
            XCTAssertTrue(countriesTab.waitForExistence(timeout: 5))
            countriesTab.tap()
        }

        // Wait for list to load
        Thread.sleep(forTimeInterval: 2)

        MainActor.assumeIsolated {
            // Expand a continent section to show more detail
            let africaButton = app.buttons["Africa: 8/54 countries"]
            if africaButton.exists {
                africaButton.tap()
            }
        }
        Thread.sleep(forTimeInterval: 1)

        snapshot("02_CountriesList")
    }

    func testScreenshot03_StatsView() throws {
        MainActor.assumeIsolated {
            skipAuthenticationIfPresent()

            // Navigate to stats tab
            let statsTab = app.tabBars.buttons["Stats"]
            XCTAssertTrue(statsTab.waitForExistence(timeout: 5))
            statsTab.tap()
        }

        // Wait for stats to load
        Thread.sleep(forTimeInterval: 2)

        snapshot("03_Stats")
    }

    func testScreenshot04_StateMapView() throws {
        MainActor.assumeIsolated {
            skipAuthenticationIfPresent()

            // Go to map view first
            let mapTab = app.tabBars.buttons["Map"]
            if mapTab.exists {
                mapTab.tap()
            }
        }

        // Wait for map to load
        Thread.sleep(forTimeInterval: 2)

        MainActor.assumeIsolated {
            // Tap on United States to show state view
            let usRegion = app.maps.firstMatch
            usRegion.coordinate(withNormalizedOffset: CGVector(dx: 0.25, dy: 0.45)).tap()

            // Look for "View States" button or state detail sheet
            let viewStatesButton = app.buttons["View States"]
            if viewStatesButton.waitForExistence(timeout: 3) {
                viewStatesButton.tap()
            }
        }

        // Wait for state map to load
        Thread.sleep(forTimeInterval: 3)

        snapshot("04_StateMap")
    }

    func testScreenshot05_SettingsView() throws {
        MainActor.assumeIsolated {
            skipAuthenticationIfPresent()

            // Navigate to settings tab
            let settingsTab = app.tabBars.buttons["Settings"]
            XCTAssertTrue(settingsTab.waitForExistence(timeout: 5))
            settingsTab.tap()
        }

        // Wait for settings to load
        Thread.sleep(forTimeInterval: 2)

        snapshot("05_Settings")
    }

    // MARK: - Helper Methods (must be called from MainActor.assumeIsolated context)

    @MainActor
    private func skipAuthenticationIfPresent() {
        // Look for login screen and skip it
        let continueWithoutAccountButton = app.buttons["Continue without account"]
        if continueWithoutAccountButton.waitForExistence(timeout: 3) {
            continueWithoutAccountButton.tap()
            Thread.sleep(forTimeInterval: 2)
        }

        // Alternative: look for Sign in with Apple and skip
        let signInWithAppleButton = app.buttons["Sign in with Apple"]
        if signInWithAppleButton.exists {
            // If we see login screen, try to find skip option or handle it
            if continueWithoutAccountButton.exists {
                continueWithoutAccountButton.tap()
                Thread.sleep(forTimeInterval: 2)
            }
        }
    }

    @MainActor
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
            Thread.sleep(forTimeInterval: 0.5)
        }
    }

}

// MARK: - Snapshot Helper

extension ScreenshotTests {
    func snapshot(_ name: String, timeWaitingForIdle timeout: TimeInterval = 20) {
        // Use fastlane's snapshot function if available, otherwise XCUIScreen
        #if SNAPSHOT
        // UI tests run on the main thread, so we can use assumeIsolated
        // This avoids needing @MainActor on the test class (which causes crashes)
        MainActor.assumeIsolated {
            Snapshot.snapshot(name, timeWaitingForIdle: timeout)
        }
        #else
        // Fallback for manual testing
        MainActor.assumeIsolated {
            let screenshot = XCUIScreen.main.screenshot()
            let attachment = XCTAttachment(screenshot: screenshot)
            attachment.name = name
            attachment.lifetime = .keepAlways
            add(attachment)
        }
        #endif
    }
}
