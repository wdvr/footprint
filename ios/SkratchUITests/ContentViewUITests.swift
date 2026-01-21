import XCTest

final class ContentViewUITests: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    func testAppLaunch() throws {
        // Test that the app launches and displays main content
        XCTAssertTrue(app.staticTexts["Welcome to Skratch"].exists)
        XCTAssertTrue(app.staticTexts["Track your travels around the world"].exists)
    }

    func testNavigationElements() throws {
        // Test navigation bar
        XCTAssertTrue(app.navigationBars["Skratch"].exists)

        // Test add button in navigation bar
        XCTAssertTrue(app.buttons["Add Place"].exists)
    }

    func testStatCards() throws {
        // Test that all stat cards are displayed
        XCTAssertTrue(app.staticTexts["Countries"].exists)
        XCTAssertTrue(app.staticTexts["US States"].exists)
        XCTAssertTrue(app.staticTexts["Canadian Provinces"].exists)

        // Test that initial counts are displayed
        XCTAssertTrue(app.staticTexts["0/195"].exists) // Countries
        XCTAssertTrue(app.staticTexts["0/51"].exists)  // US States
        XCTAssertTrue(app.staticTexts["0/13"].exists)  // Canadian Provinces
    }

    func testAddSamplePlace() throws {
        // Test adding a sample place
        let addButton = app.buttons["Add Sample Place"]
        XCTAssertTrue(addButton.exists)

        // Tap the add button
        addButton.tap()

        // Verify the count has updated (this might need adjustment based on actual UI behavior)
        // Note: In a real app, this would check for actual UI updates after adding a place
    }

    func testProgressBars() throws {
        // Test that progress bars exist for each region type
        let progressViews = app.progressIndicators

        // Should have 3 progress bars (Countries, US States, Canadian Provinces)
        XCTAssertGreaterThanOrEqual(progressViews.count, 3)
    }

    func testAccessibility() throws {
        // Test that key elements have accessibility labels
        let addButton = app.buttons["Add Sample Place"]
        XCTAssertTrue(addButton.isHittable)

        let navButton = app.buttons["Add Place"]
        XCTAssertTrue(navButton.isHittable)
    }

    func testLandscapeOrientation() throws {
        // Test app behavior in landscape orientation
        XCUIDevice.shared.orientation = .landscapeLeft

        // Verify main elements are still accessible
        XCTAssertTrue(app.staticTexts["Welcome to Skratch"].exists)
        XCTAssertTrue(app.staticTexts["Countries"].exists)

        // Return to portrait
        XCUIDevice.shared.orientation = .portrait
    }

    func testScreenshotCapture() throws {
        // Capture screenshot for documentation/debugging
        let screenshot = app.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "Main Screen"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    // MARK: - Performance Tests

    func testAppLaunchPerformance() throws {
        // Test app launch performance
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            app.launch()
        }
    }

    func testScrollPerformance() throws {
        // If we had scrollable content, test scroll performance
        measure(metrics: [XCTClockMetric()]) {
            // Perform scrolling operations
            // This is a placeholder - implement when we have scrollable content
        }
    }
}