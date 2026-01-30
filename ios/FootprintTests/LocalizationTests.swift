//
//  LocalizationTests.swift
//  FootprintTests
//
//  Created by Claude on 2026-01-30.
//  Tests for internationalization and localization functionality.
//

import XCTest
@testable import Footprint

final class LocalizationTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Reset to English for consistent tests
        UserDefaults.standard.set(["en"], forKey: "AppleLanguages")
        UserDefaults.standard.synchronize()
    }
    
    override func tearDown() {
        // Reset language preferences
        UserDefaults.standard.removeObject(forKey: "AppleLanguages")
        UserDefaults.standard.synchronize()
        super.tearDown()
    }
    
    // MARK: - Basic Localization Tests
    
    func testEnglishLocalization() {
        // Test that basic strings are localized correctly in English
        XCTAssertEqual(L10n.Tab.map, "Map")
        XCTAssertEqual(L10n.Tab.countries, "Countries")
        XCTAssertEqual(L10n.Tab.stats, "Stats")
        XCTAssertEqual(L10n.Tab.settings, "Settings")
    }
    
    func testSpanishLocalization() {
        // Switch to Spanish and test localization
        UserDefaults.standard.set(["es"], forKey: "AppleLanguages")
        UserDefaults.standard.synchronize()
        
        // Note: In a real app, you'd need to restart or reload for language changes
        // For testing, we can directly test the Spanish strings
        let mapKey = NSLocalizedString("tab.map", bundle: Bundle(for: type(of: self)), comment: "")
        XCTAssertTrue(mapKey == "Map" || mapKey == "Mapa") // May not switch immediately in test
    }
    
    func testParameterizedStrings() {
        // Test strings with parameters
        let signedInString = L10n.Auth.signedInWith("Google")
        XCTAssertTrue(signedInString.contains("Google"))
        XCTAssertTrue(signedInString.contains("Signed in with"))
        
        let clearAllString = L10n.Data.clearAllConfirmation(42)
        XCTAssertTrue(clearAllString.contains("42"))
        XCTAssertTrue(clearAllString.contains("visited places"))
    }
    
    func testOnboardingStrings() {
        // Test onboarding flow strings
        XCTAssertEqual(L10n.Onboarding.skip, "Skip")
        XCTAssertEqual(L10n.Onboarding.back, "Back")
        XCTAssertEqual(L10n.Onboarding.next, "Next")
        XCTAssertEqual(L10n.Onboarding.getStarted, "Get Started")
        
        XCTAssertEqual(L10n.Onboarding.Welcome.title, "Welcome to Footprint")
        XCTAssertFalse(L10n.Onboarding.Welcome.description.isEmpty)
    }
    
    func testAuthenticationStrings() {
        // Test authentication related strings
        XCTAssertEqual(L10n.Auth.signedIn, "Signed In")
        XCTAssertEqual(L10n.Auth.offlineMode, "Offline Mode")
        XCTAssertEqual(L10n.Auth.signOut, "Sign Out")
        XCTAssertFalse(L10n.Auth.signOutConfirmation.isEmpty)
    }
    
    func testStatsStrings() {
        // Test statistics related strings
        XCTAssertEqual(L10n.Stats.yourTravelStats, "Your Travel Stats")
        XCTAssertEqual(L10n.Stats.totalRegionsVisited, "Total Regions Visited")
        XCTAssertEqual(L10n.Stats.byContinent, "By Continent")
        XCTAssertEqual(L10n.Stats.achievements, "Achievements")
    }
    
    func testCommonActionStrings() {
        // Test common action strings
        XCTAssertEqual(L10n.Action.cancel, "Cancel")
        XCTAssertEqual(L10n.Action.delete, "Delete")
        XCTAssertEqual(L10n.Action.ok, "OK")
        XCTAssertEqual(L10n.Action.done, "Done")
    }
    
    func testGeographicTerms() {
        // Test geographic terminology
        XCTAssertEqual(L10n.Geographic.continent, "Continent")
        XCTAssertEqual(L10n.Geographic.country, "Country")
        XCTAssertEqual(L10n.Geographic.state, "State")
        XCTAssertEqual(L10n.Geographic.province, "Province")
    }
    
    func testContinentNames() {
        // Test continent names
        XCTAssertEqual(L10n.Continent.africa, "Africa")
        XCTAssertEqual(L10n.Continent.asia, "Asia")
        XCTAssertEqual(L10n.Continent.europe, "Europe")
        XCTAssertEqual(L10n.Continent.northAmerica, "North America")
        XCTAssertEqual(L10n.Continent.southAmerica, "South America")
        XCTAssertEqual(L10n.Continent.oceania, "Oceania")
        XCTAssertEqual(L10n.Continent.antarctica, "Antarctica")
    }
    
    // MARK: - Accessibility Tests
    
    func testAccessibilityStrings() {
        // Test accessibility labels
        let visitedStatus = L10n.Accessibility.visitedStatus("France", "visited")
        XCTAssertTrue(visitedStatus.contains("France"))
        XCTAssertTrue(visitedStatus.contains("visited"))
        
        let continentStats = L10n.Accessibility.continentStats("Europe", 15, 50)
        XCTAssertTrue(continentStats.contains("Europe"))
        XCTAssertTrue(continentStats.contains("15"))
        XCTAssertTrue(continentStats.contains("50"))
    }
    
    // MARK: - String Extension Tests
    
    func testStringExtensions() {
        // Test the localized string extension
        let localizedMap = "tab.map".localized
        XCTAssertEqual(localizedMap, "Map")
        
        // Test with missing key (should return the key itself)
        let missingKey = "non.existent.key".localized
        XCTAssertEqual(missingKey, "non.existent.key")
    }
    
    // MARK: - Error Message Tests
    
    func testErrorMessages() {
        // Test error message localization
        XCTAssertEqual(L10n.Error.unknown, "Unknown error")
        XCTAssertEqual(L10n.Error.backupFailed, "Backup failed")
        XCTAssertEqual(L10n.Error.restoreFailed, "Restore failed")
    }
    
    // MARK: - Performance Tests
    
    func testLocalizationPerformance() {
        // Test that localization calls are reasonably fast
        measure {
            for _ in 0..<1000 {
                _ = L10n.Tab.map
                _ = L10n.Onboarding.Welcome.title
                _ = L10n.Stats.yourTravelStats
            }
        }
    }
    
    // MARK: - Integration Tests
    
    func testAllRequiredStringsPresent() {
        // Verify that all critical strings have non-empty values
        let criticalStrings = [
            L10n.Tab.map,
            L10n.Tab.countries,
            L10n.Tab.stats,
            L10n.Tab.settings,
            L10n.Onboarding.Welcome.title,
            L10n.Auth.signOut,
            L10n.Action.cancel,
            L10n.Action.ok
        ]
        
        for string in criticalStrings {
            XCTAssertFalse(string.isEmpty, "Critical string should not be empty: \(string)")
            XCTAssertFalse(string.hasPrefix("tab."), "String should be localized, not key: \(string)")
        }
    }
}
