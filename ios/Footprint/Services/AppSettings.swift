//
//  AppSettings.swift
//  Footprint
//
//  User preferences and app settings
//

import Foundation

/// Manages user preferences and app settings
@MainActor
@Observable
final class AppSettings {
    static let shared = AppSettings()

    private let defaults = UserDefaults.standard

    // MARK: - Keys

    private enum Keys {
        static let trackingGranularity = "trackingGranularity"
    }

    // MARK: - Tracking Granularity

    /// The level of detail for location tracking
    enum TrackingGranularity: String, CaseIterable {
        case country = "country"
        case state = "state"  // Includes states/provinces for supported countries

        var displayName: String {
            switch self {
            case .country: return "Country Only"
            case .state: return "State/Province"
            }
        }

        var description: String {
            switch self {
            case .country: return "Only track countries you visit"
            case .state: return "Track states and provinces for supported countries (US, CA, RU, etc.)"
            }
        }
    }

    /// Current tracking granularity setting
    var trackingGranularity: TrackingGranularity {
        get {
            if let raw = defaults.string(forKey: Keys.trackingGranularity),
               let value = TrackingGranularity(rawValue: raw) {
                return value
            }
            return .state  // Default to state-level tracking
        }
        set {
            defaults.set(newValue.rawValue, forKey: Keys.trackingGranularity)
            AnalyticsService.shared.trackGranularityChanged(granularity: .init(rawValue: newValue.rawValue) ?? .state)
        }
    }

    /// Whether to track states/provinces (based on granularity setting)
    var shouldTrackStates: Bool {
        trackingGranularity == .state
    }

    private init() {}
}
