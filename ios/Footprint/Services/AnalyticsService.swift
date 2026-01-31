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
