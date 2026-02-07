import CoreLocation
import MapKit
import SwiftUI
import UserNotifications

/// Manages location services for the app
@MainActor
@Observable
final class LocationManager: NSObject, CLLocationManagerDelegate {
    static let shared = LocationManager()

    private let locationManager = CLLocationManager()

    var currentLocation: CLLocationCoordinate2D?
    var authorizationStatus: CLAuthorizationStatus = .notDetermined
    var isTracking = false
    var isBackgroundTrackingEnabled = false
    var currentCountryCode: String?
    var currentStateCode: String?
    var currentCity: String?

    /// Callback when user enters a new country
    var onCountryDetected: ((String) -> Void)?
    /// Callback when user enters a new state (US/CA)
    var onStateDetected: ((String, String) -> Void)? // (countryCode, stateCode)
    /// Callback when user enters a new city
    var onCityDetected: ((String, String, String?) -> Void)? // (city, countryCode, stateCode)

    private override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        locationManager.distanceFilter = 1000 // Update every 1km
        #if os(iOS)
        locationManager.allowsBackgroundLocationUpdates = true
        locationManager.pausesLocationUpdatesAutomatically = true
        #endif
        authorizationStatus = locationManager.authorizationStatus

        // Load saved tracking preference
        isBackgroundTrackingEnabled = UserDefaults.standard.bool(forKey: "backgroundLocationTracking")
    }

    /// Request location permission (always for background tracking)
    func requestPermission() {
        locationManager.requestAlwaysAuthorization()
    }

    /// Request the user's current location once (for centering map)
    func requestCurrentLocation() {
        locationManager.requestLocation()
    }

    /// Start tracking location
    func startTracking() {
        #if os(iOS)
        guard authorizationStatus == .authorizedWhenInUse ||
              authorizationStatus == .authorizedAlways else {
            requestPermission()
            return
        }
        #else
        guard authorizationStatus == .authorizedAlways else {
            requestPermission()
            return
        }
        #endif
        isTracking = true
        locationManager.startUpdatingLocation()
    }

    /// Stop tracking location
    func stopTracking() {
        isTracking = false
        locationManager.stopUpdatingLocation()
    }

    /// Toggle tracking on/off
    func toggleTracking() {
        if isTracking {
            stopTracking()
        } else {
            startTracking()
        }
    }

    // MARK: - Background Location Tracking

    /// Enable background location tracking using significant location changes
    /// This is battery efficient and works even when app is terminated
    func enableBackgroundTracking() {
        #if os(iOS)
        guard authorizationStatus == .authorizedAlways else {
            Log.location.info("Need 'Always' permission for background tracking")
            requestPermission()
            return
        }

        locationManager.startMonitoringSignificantLocationChanges()
        isBackgroundTrackingEnabled = true
        UserDefaults.standard.set(true, forKey: "backgroundLocationTracking")
        Log.location.info("Background tracking enabled")
        #endif
    }

    /// Disable background location tracking
    func disableBackgroundTracking() {
        #if os(iOS)
        locationManager.stopMonitoringSignificantLocationChanges()
        isBackgroundTrackingEnabled = false
        UserDefaults.standard.set(false, forKey: "backgroundLocationTracking")
        Log.location.info("Background tracking disabled")
        #endif
    }

    /// Toggle background tracking
    func toggleBackgroundTracking() {
        if isBackgroundTrackingEnabled {
            disableBackgroundTracking()
        } else {
            enableBackgroundTracking()
        }
    }

    /// Resume background tracking if it was enabled (call on app launch)
    func resumeBackgroundTrackingIfEnabled() {
        #if os(iOS)
        if isBackgroundTrackingEnabled && authorizationStatus == .authorizedAlways {
            locationManager.startMonitoringSignificantLocationChanges()
            Log.location.info("Resumed background tracking")
        }
        #endif
    }

    /// Send notification for new location detected
    func notifyNewLocation(city: String?, stateName: String?, countryName: String, regionType: String) {
        let locationName: String
        if let city = city {
            locationName = city
        } else if let state = stateName {
            locationName = state
        } else {
            locationName = countryName
        }

        PushNotificationManager.shared.notifyNewLocationDetected(
            regionName: locationName,
            regionType: regionType
        )
    }

    /// Reverse geocode to get country/state/city from coordinates
    private func reverseGeocode(_ location: CLLocation) {
        let geocoder = CLGeocoder()
        geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, error in
            guard let self = self, error == nil,
                  let placemark = placemarks?.first else { return }

            DispatchQueue.main.async {
                // Get country code (ISO 3166-1 alpha-2)
                if let countryCode = placemark.isoCountryCode {
                    let previousCountry = self.currentCountryCode
                    self.currentCountryCode = countryCode

                    // Notify if country changed
                    if previousCountry != countryCode {
                        self.onCountryDetected?(countryCode)
                    }

                    var stateCode: String?

                    // Check for US states or Canadian provinces
                    if countryCode == "US" || countryCode == "CA" {
                        if let stateName = placemark.administrativeArea {
                            // Convert state name to code
                            let code = self.stateNameToCode(stateName, country: countryCode)
                            stateCode = code
                            let previousState = self.currentStateCode
                            self.currentStateCode = code

                            if previousState != code {
                                self.onStateDetected?(countryCode, code)
                            }
                        }
                    }

                    // Track city changes
                    if let city = placemark.locality {
                        let previousCity = self.currentCity
                        self.currentCity = city

                        if previousCity != city {
                            self.onCityDetected?(city, countryCode, stateCode)
                        }
                    }
                }
            }
        }
    }

    /// Convert state/province name to code
    private func stateNameToCode(_ name: String, country: String) -> String {
        // US States
        let usStates: [String: String] = [
            "Alabama": "AL", "Alaska": "AK", "Arizona": "AZ", "Arkansas": "AR",
            "California": "CA", "Colorado": "CO", "Connecticut": "CT", "Delaware": "DE",
            "Florida": "FL", "Georgia": "GA", "Hawaii": "HI", "Idaho": "ID",
            "Illinois": "IL", "Indiana": "IN", "Iowa": "IA", "Kansas": "KS",
            "Kentucky": "KY", "Louisiana": "LA", "Maine": "ME", "Maryland": "MD",
            "Massachusetts": "MA", "Michigan": "MI", "Minnesota": "MN", "Mississippi": "MS",
            "Missouri": "MO", "Montana": "MT", "Nebraska": "NE", "Nevada": "NV",
            "New Hampshire": "NH", "New Jersey": "NJ", "New Mexico": "NM", "New York": "NY",
            "North Carolina": "NC", "North Dakota": "ND", "Ohio": "OH", "Oklahoma": "OK",
            "Oregon": "OR", "Pennsylvania": "PA", "Rhode Island": "RI", "South Carolina": "SC",
            "South Dakota": "SD", "Tennessee": "TN", "Texas": "TX", "Utah": "UT",
            "Vermont": "VT", "Virginia": "VA", "Washington": "WA", "West Virginia": "WV",
            "Wisconsin": "WI", "Wyoming": "WY", "District of Columbia": "DC"
        ]

        // Canadian Provinces
        let caProvinces: [String: String] = [
            "Alberta": "AB", "British Columbia": "BC", "Manitoba": "MB",
            "New Brunswick": "NB", "Newfoundland and Labrador": "NL",
            "Northwest Territories": "NT", "Nova Scotia": "NS", "Nunavut": "NU",
            "Ontario": "ON", "Prince Edward Island": "PE", "Quebec": "QC",
            "Saskatchewan": "SK", "Yukon": "YT"
        ]

        if country == "US" {
            return usStates[name] ?? name
        } else if country == "CA" {
            return caProvinces[name] ?? name
        }
        return name
    }

    // MARK: - CLLocationManagerDelegate

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            self.authorizationStatus = status
            #if os(iOS)
            if status == .authorizedWhenInUse || status == .authorizedAlways {
                if self.isTracking {
                    self.locationManager.startUpdatingLocation()
                }
            }
            #else
            if status == .authorizedAlways {
                if self.isTracking {
                    self.locationManager.startUpdatingLocation()
                }
            }
            #endif
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        let coord = location.coordinate
        let loc = location

        Task { @MainActor in
            self.currentLocation = coord
            self.reverseGeocode(loc)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Log.location.error("Location error: \(error.localizedDescription)")
    }
}
