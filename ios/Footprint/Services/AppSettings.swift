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
        static let countryTrackingMode = "countryTrackingMode"
        static let stateTrackingCountries = "stateTrackingCountries"
    }

    // MARK: - Country Tracking Mode

    /// Controls which countries use state/province-level tracking
    enum CountryTrackingMode: String, CaseIterable {
        case all = "all"         // Track states for all supported countries
        case none = "none"       // Country-only for all (visited country = all states filled)
        case custom = "custom"   // Pick specific countries for state-level tracking

        var displayName: String {
            switch self {
            case .all: return "All Countries"
            case .none: return "None"
            case .custom: return "Custom"
            }
        }

        var description: String {
            switch self {
            case .all: return "Track individual states/provinces for all supported countries"
            case .none: return "Track at country level only. Visiting a country fills all its regions on the map."
            case .custom: return "Choose which countries to track at state/province level"
            }
        }
    }

    /// List of countries that support state-level tracking
    static let supportedStateCountries: [(code: String, name: String)] = [
        ("US", "United States"),
        ("CA", "Canada"),
        ("AU", "Australia"),
        ("MX", "Mexico"),
        ("BR", "Brazil"),
        ("DE", "Germany"),
        ("FR", "France"),
        ("ES", "Spain"),
        ("IT", "Italy"),
        ("NL", "Netherlands"),
        ("BE", "Belgium"),
        ("GB", "United Kingdom"),
        ("RU", "Russia"),
        ("AR", "Argentina"),
    ]

    /// Current country tracking mode
    var countryTrackingMode: CountryTrackingMode {
        get {
            if let raw = defaults.string(forKey: Keys.countryTrackingMode),
               let value = CountryTrackingMode(rawValue: raw) {
                return value
            }
            // Migrate from old setting
            if let oldRaw = defaults.string(forKey: Keys.trackingGranularity) {
                if oldRaw == "country" { return .none }
                if oldRaw == "state" { return .all }
            }
            return .all  // Default to state-level tracking for all
        }
        set {
            defaults.set(newValue.rawValue, forKey: Keys.countryTrackingMode)
            AnalyticsService.shared.trackGranularityChanged(
                granularity: newValue == .none ? .country : .state
            )
        }
    }

    /// Countries selected for state-level tracking in custom mode
    var stateTrackingCountries: Set<String> {
        get {
            if let array = defaults.stringArray(forKey: Keys.stateTrackingCountries) {
                return Set(array)
            }
            // Default: all supported countries
            return Set(Self.supportedStateCountries.map { $0.code })
        }
        set {
            defaults.set(Array(newValue).sorted(), forKey: Keys.stateTrackingCountries)
        }
    }

    /// Whether to track states/provinces for a specific country
    func shouldTrackStates(for countryCode: String) -> Bool {
        // Only relevant for countries that support state tracking
        guard Self.supportedStateCountries.contains(where: { $0.code == countryCode }) else {
            return false
        }
        switch countryTrackingMode {
        case .all:
            return true
        case .none:
            return false
        case .custom:
            return stateTrackingCountries.contains(countryCode)
        }
    }

    private init() {}
}
