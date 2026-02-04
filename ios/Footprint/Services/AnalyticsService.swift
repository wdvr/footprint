//
//  AnalyticsService.swift
//  Footprint
//
//  Firebase Analytics and Crashlytics integration
//

import Foundation
#if canImport(FirebaseCore)
import FirebaseCore
#endif
#if canImport(FirebaseAnalytics)
import FirebaseAnalytics
#endif
#if canImport(FirebaseCrashlytics)
import FirebaseCrashlytics
#endif

/// Analytics service for tracking user behavior and crashes
final class AnalyticsService: @unchecked Sendable {
    static let shared = AnalyticsService()

    private init() {}

    // MARK: - Configuration

    /// Call this in AppDelegate.didFinishLaunching
    func configure() {
        #if canImport(FirebaseCore)
        // Only configure if not already configured
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }
        #endif

        // Enable analytics
        #if canImport(FirebaseAnalytics)
        Analytics.setAnalyticsCollectionEnabled(true)
        #endif
    }

    // MARK: - Event Tracking

    /// Track place visited
    func trackPlaceVisited(placeId: String, country: String?, city: String?) {
        logEvent("place_visited", parameters: [
            "place_id": placeId,
            "country": country ?? "unknown",
            "city": city ?? "unknown"
        ])
    }

    /// Track place added manually
    func trackPlaceAdded(source: String) {
        logEvent("place_added", parameters: [
            "source": source
        ])
    }

    /// Track place deleted
    func trackPlaceDeleted(placeId: String) {
        logEvent("place_deleted", parameters: [
            "place_id": placeId
        ])
    }

    /// Track photo imported
    func trackPhotoImported(count: Int) {
        logEvent("photos_imported", parameters: [
            "count": count
        ])
    }

    // MARK: - Import Events

    /// Track photo scan completed
    func trackPhotoScanCompleted(
        photosScanned: Int,
        photosWithLocation: Int,
        countriesFound: Int,
        statesFound: Int,
        locationsImported: Int
    ) {
        logEvent("photo_scan_completed", parameters: [
            "photos_scanned": photosScanned,
            "photos_with_location": photosWithLocation,
            "countries_found": countriesFound,
            "states_found": statesFound,
            "locations_imported": locationsImported
        ])
    }

    /// Track Google Calendar import
    func trackCalendarImportCompleted(eventsScanned: Int, locationsFound: Int, locationsImported: Int) {
        logEvent("calendar_import_completed", parameters: [
            "events_scanned": eventsScanned,
            "locations_found": locationsFound,
            "locations_imported": locationsImported
        ])
    }

    /// Track Gmail import
    func trackGmailImportCompleted(emailsScanned: Int, locationsFound: Int, locationsImported: Int) {
        logEvent("gmail_import_completed", parameters: [
            "emails_scanned": emailsScanned,
            "locations_found": locationsFound,
            "locations_imported": locationsImported
        ])
    }

    // MARK: - Place Management Events

    /// Track country added/removed
    func trackCountryChanged(countryCode: String, action: PlaceAction, source: PlaceSource) {
        logEvent("country_changed", parameters: [
            "country_code": countryCode,
            "action": action.rawValue,
            "source": source.rawValue
        ])
    }

    /// Track state/province added/removed
    func trackStateChanged(stateCode: String, countryCode: String, action: PlaceAction, source: PlaceSource) {
        logEvent("state_changed", parameters: [
            "state_code": stateCode,
            "country_code": countryCode,
            "action": action.rawValue,
            "source": source.rawValue
        ])
    }

    /// Track bucket list change
    func trackBucketListChanged(regionCode: String, regionType: String, action: PlaceAction) {
        logEvent("bucket_list_changed", parameters: [
            "region_code": regionCode,
            "region_type": regionType,
            "action": action.rawValue
        ])
    }

    /// Track auto-detection from location tracking
    func trackAutoDetection(countryCode: String, stateCode: String?) {
        logEvent("auto_detection", parameters: [
            "country_code": countryCode,
            "state_code": stateCode ?? "none"
        ])
    }

    /// Track boundary reprocess (migration)
    func trackBoundaryReprocess(locationsProcessed: Int, newCountryMatches: Int, newStateMatches: Int) {
        logEvent("boundary_reprocess", parameters: [
            "locations_processed": locationsProcessed,
            "new_country_matches": newCountryMatches,
            "new_state_matches": newStateMatches
        ])
    }

    /// Track granularity setting change
    func trackGranularityChanged(granularity: TrackingGranularity) {
        logEvent("granularity_changed", parameters: [
            "granularity": granularity.rawValue
        ])
    }

    // MARK: - Enums

    enum PlaceAction: String {
        case added = "added"
        case removed = "removed"
    }

    enum PlaceSource: String {
        case manual = "manual"
        case photoImport = "photo_import"
        case calendarImport = "calendar_import"
        case gmailImport = "gmail_import"
        case locationTracking = "location_tracking"
        case migration = "migration"
    }

    enum TrackingGranularity: String {
        case country = "country"
        case state = "state"  // includes city-level for supported countries
    }

    /// Track map viewed
    func trackMapViewed(placesCount: Int) {
        logEvent("map_viewed", parameters: [
            "places_count": placesCount
        ])
    }

    /// Track statistics viewed
    func trackStatisticsViewed(countriesCount: Int, placesCount: Int) {
        logEvent("statistics_viewed", parameters: [
            "countries_count": countriesCount,
            "places_count": placesCount
        ])
    }

    /// Track sync completed
    func trackSyncCompleted(placesCount: Int, success: Bool) {
        logEvent("sync_completed", parameters: [
            "places_count": placesCount,
            "success": success
        ])
    }

    /// Track sign in
    func trackSignIn(provider: String, isNewUser: Bool) {
        logEvent("sign_in", parameters: [
            "provider": provider,
            "is_new_user": isNewUser
        ])
    }

    /// Track location tracking enabled/disabled
    func trackLocationTracking(enabled: Bool) {
        logEvent("location_tracking_toggled", parameters: [
            "enabled": enabled
        ])
    }

    // MARK: - Screen Tracking

    func trackScreen(_ screenName: String) {
        #if canImport(FirebaseAnalytics)
        Analytics.logEvent(AnalyticsEventScreenView, parameters: [
            AnalyticsParameterScreenName: screenName
        ])
        #endif
    }

    // MARK: - Crash Reporting

    /// Record a non-fatal error
    func recordError(_ error: Error, context: [String: Any]? = nil) {
        #if canImport(FirebaseCrashlytics)
        if let context = context {
            for (key, value) in context {
                Crashlytics.crashlytics().setCustomValue(value, forKey: key)
            }
        }
        Crashlytics.crashlytics().record(error: error)
        #endif
    }

    /// Set user identifier for crash reports (anonymized)
    func setUserId(_ userId: String?) {
        #if canImport(FirebaseCrashlytics)
        Crashlytics.crashlytics().setUserID(userId ?? "")
        #endif
        #if canImport(FirebaseAnalytics)
        Analytics.setUserID(userId)
        #endif
    }

    /// Log a breadcrumb message for crash context
    func log(_ message: String) {
        #if canImport(FirebaseCrashlytics)
        Crashlytics.crashlytics().log(message)
        #endif
    }

    // MARK: - Private

    private func logEvent(_ name: String, parameters: [String: Any]? = nil) {
        #if canImport(FirebaseAnalytics)
        Analytics.logEvent(name, parameters: parameters)
        #endif
    }
}
