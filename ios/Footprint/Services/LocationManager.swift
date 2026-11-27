import CoreLocation
#if canImport(CoreMotion)
import CoreMotion
#endif
import MapKit
import SwiftUI
import UserNotifications

/// Manages location services for the app
@MainActor
@Observable
final class LocationManager: NSObject, CLLocationManagerDelegate {
    static let shared = LocationManager()

    private let locationManager = CLLocationManager()
    #if canImport(CoreMotion)
    private let motionManager = CMMotionActivityManager()
    #endif
    private nonisolated static let rollingRegionIdentifier = "footprint.rolling-geofence"

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

    /// Visit pipeline that turns fixes into `Visit` / `VisitedPlace` records (§3.2).
    var pipeline = VisitPipeline.shared
    var samplingPolicy = SamplingPolicy()
    private(set) var samplingInputs = SamplingInputs(automaticTrackingEnabled: false)
    private(set) var samplingMode = SamplingMode.off
    /// User consented to automatic tracking but Always authorization is still pending.
    private var enableWhenAuthorizedAlways = false

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

    /// Request When-In-Use permission at the first value moment (map centering, §5.1).
    func requestWhenInUsePermission() {
        locationManager.requestWhenInUseAuthorization()
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
            requestWhenInUsePermission()
            return
        }
        #else
        guard authorizationStatus == .authorizedAlways else {
            requestPermission()
            return
        }
        #endif
        isTracking = true
        applySamplingMode()
    }

    /// Stop tracking location
    func stopTracking() {
        isTracking = false
        applySamplingMode()
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

    /// Enable automatic (background) tracking: the layered, battery-safe capture stack of §5.1.
    /// Works even when the app is terminated (significant changes and visits relaunch it).
    func enableBackgroundTracking() {
        #if os(iOS)
        guard authorizationStatus == .authorizedAlways else {
            Log.location.info("Need 'Always' permission for background tracking")
            enableWhenAuthorizedAlways = true
            requestPermission()
            return
        }

        enableWhenAuthorizedAlways = false
        isBackgroundTrackingEnabled = true
        UserDefaults.standard.set(true, forKey: "backgroundLocationTracking")
        startMotionUpdates()
        applySamplingMode()
        Log.location.info("Background tracking enabled")
        #endif
    }

    /// Disable background location tracking
    func disableBackgroundTracking() {
        #if os(iOS)
        enableWhenAuthorizedAlways = false
        isBackgroundTrackingEnabled = false
        UserDefaults.standard.set(false, forKey: "backgroundLocationTracking")
        stopMotionUpdates()
        applySamplingMode()
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
            startMotionUpdates()
            applySamplingMode()
            Log.location.info("Resumed background tracking")
        }
        #endif
        pipeline.run()
    }

    // MARK: - Sampling policy (§5.1)

    /// Re-evaluates the sampling policy and applies the resulting mode to CoreLocation.
    func applySamplingMode(now: Date = Date()) {
        samplingInputs.automaticTrackingEnabled = isBackgroundTrackingEnabled && authorizationStatus == .authorizedAlways
        samplingInputs.now = now
        let mode = samplingPolicy.mode(for: samplingInputs)
        let previous = samplingMode
        samplingMode = mode

        #if os(iOS)
        if mode.significantChanges != previous.significantChanges {
            if mode.significantChanges {
                locationManager.startMonitoringSignificantLocationChanges()
            } else {
                locationManager.stopMonitoringSignificantLocationChanges()
            }
        }
        if mode.visitMonitoring != previous.visitMonitoring {
            if mode.visitMonitoring {
                locationManager.startMonitoringVisits()
            } else {
                locationManager.stopMonitoringVisits()
            }
        }
        if mode.geofenceRadiusMeters == nil {
            stopRollingGeofence()
        }
        #endif

        if mode.standardUpdates {
            locationManager.desiredAccuracy = mode.desiredAccuracyMeters
            locationManager.distanceFilter = mode.distanceFilterMeters
        } else {
            locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
            locationManager.distanceFilter = 1000
        }
        if mode.standardUpdates || isTracking {
            locationManager.startUpdatingLocation()
        } else {
            locationManager.stopUpdatingLocation()
        }
    }

    func updateMotion(_ motion: MotionState, at date: Date = Date()) {
        guard motion != samplingInputs.motion else { return }
        samplingInputs.motion = motion
        samplingInputs.stationarySince = motion == .stationary ? date : nil
        applySamplingMode(now: date)
        if motion == .stationary {
            scheduleStationaryCheck(since: date)
        }
    }

    /// Re-evaluates once the stationary cutoff passes, so GPS stops without needing another event.
    private func scheduleStationaryCheck(since date: Date) {
        let delay = samplingPolicy.stationaryCutoff
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(delay))
            guard let self, self.samplingInputs.stationarySince == date else { return }
            self.settle()
        }
    }

    /// The device has settled: drop back to the sampling floor until the geofence is exited again.
    private func settle() {
        samplingInputs.exitedGeofence = false
        samplingInputs.stayForming = false
        applySamplingMode()
    }

    private func startMotionUpdates() {
        #if canImport(CoreMotion) && os(iOS)
        guard CMMotionActivityManager.isActivityAvailable() else { return }
        motionManager.startActivityUpdates(to: .main) { [weak self] activity in
            guard let activity else { return }
            let state = Self.motionState(for: activity)
            MainActor.assumeIsolated {
                self?.updateMotion(state)
            }
        }
        #endif
    }

    private func stopMotionUpdates() {
        #if canImport(CoreMotion) && os(iOS)
        motionManager.stopActivityUpdates()
        #endif
        samplingInputs.motion = .unknown
        samplingInputs.stationarySince = nil
    }

    #if canImport(CoreMotion)
    private nonisolated static func motionState(for activity: CMMotionActivity) -> MotionState {
        if activity.automotive { return .automotive }
        if activity.walking || activity.running || activity.cycling { return .walking }
        if activity.stationary { return .stationary }
        return .unknown
    }
    #endif

    /// Layer 3: one rolling region around the last fix; exiting it escalates sampling.
    private var rollingGeofenceCenter: CLLocationCoordinate2D?

    private func moveRollingGeofence(to coordinate: CLLocationCoordinate2D) {
        #if os(iOS)
        guard let radius = samplingMode.geofenceRadiusMeters,
              CLLocationManager.isMonitoringAvailable(for: CLCircularRegion.self) else { return }
        if let center = rollingGeofenceCenter,
           GeoMath.distanceMeters(lat1: center.latitude, lon1: center.longitude,
                                  lat2: coordinate.latitude, lon2: coordinate.longitude) < radius / 2 {
            return
        }
        rollingGeofenceCenter = coordinate
        let region = CLCircularRegion(center: coordinate, radius: radius, identifier: Self.rollingRegionIdentifier)
        region.notifyOnEntry = false
        region.notifyOnExit = true
        locationManager.startMonitoring(for: region)
        #endif
    }

    private func stopRollingGeofence() {
        rollingGeofenceCenter = nil
        #if os(iOS)
        for region in locationManager.monitoredRegions where region.identifier == Self.rollingRegionIdentifier {
            locationManager.stopMonitoring(for: region)
        }
        #endif
    }

    // MARK: - Pipeline

    /// Feeds fixes to the visit pipeline and announces newly recorded places.
    func ingest(_ samples: [EvidenceSample]) {
        let newPlaces = pipeline.record(samples)
        deliver(newPlaces)
        updateStayForming()
    }

    /// Fires the existing detection callbacks for places the pipeline newly recorded.
    func deliver(_ newPlaces: [VisitPipeline.NewPlace]) {
        for place in newPlaces {
            if let stateCode = place.subdivisionCode {
                if place.countryCode == "US" || place.countryCode == "CA" {
                    onStateDetected?(place.countryCode, stateCode)
                }
            } else {
                onCountryDetected?(place.countryCode)
            }
        }
    }

    /// A candidate stay is forming when the latest fixes are within the stay radius of each other.
    private var recentFixes: [EvidenceSample] = []

    private func updateStayForming() {
        let forming = recentFixes.count >= 2
            && GeoMath.distanceMeters(recentFixes[0], recentFixes[recentFixes.count - 1]) <= pipeline.config.stayRadiusMeters
        if forming != samplingInputs.stayForming {
            samplingInputs.stayForming = forming
            applySamplingMode()
        }
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

                    // Country/state records come from the visit pipeline; the geocoder only
                    // supplies display names (§3.4).
                    _ = previousCountry

                    var stateCode: String?

                    // Check for US states or Canadian provinces
                    if countryCode == "US" || countryCode == "CA" {
                        if let stateName = placemark.administrativeArea {
                            // Convert state name to code
                            let code = self.stateNameToCode(stateName, country: countryCode)
                            stateCode = code
                            self.currentStateCode = code
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
            if status == .authorizedAlways, self.enableWhenAuthorizedAlways {
                self.enableBackgroundTracking()
            }
            self.applySamplingMode()
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
        let samples = locations.map {
            EvidenceSample(
                timestamp: $0.timestamp,
                latitude: $0.coordinate.latitude,
                longitude: $0.coordinate.longitude,
                horizontalAccuracy: $0.horizontalAccuracy
            )
        }

        Task { @MainActor in
            self.currentLocation = coord
            self.recentFixes = Array((self.recentFixes + samples).suffix(3))
            self.moveRollingGeofence(to: coord)
            self.ingest(samples)
            self.reverseGeocode(loc)
        }
    }

    /// Layer 2: iOS-detected arrivals/departures become samples at both ends of the stay.
    nonisolated func locationManager(_ manager: CLLocationManager, didVisit visit: CLVisit) {
        let samples = [visit.arrivalDate, visit.departureDate]
            .filter { $0 != .distantPast && $0 != .distantFuture }
            .map {
                EvidenceSample(
                    timestamp: $0,
                    latitude: visit.coordinate.latitude,
                    longitude: visit.coordinate.longitude,
                    horizontalAccuracy: visit.horizontalAccuracy
                )
            }
        Task { @MainActor in
            self.ingest(samples)
        }
    }

    /// iOS paused standard updates because the device stopped moving.
    nonisolated func locationManagerDidPauseLocationUpdates(_ manager: CLLocationManager) {
        Task { @MainActor in
            self.settle()
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        guard region.identifier == Self.rollingRegionIdentifier else { return }
        Task { @MainActor in
            self.samplingInputs.exitedGeofence = true
            self.applySamplingMode()
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Log.location.error("Location error: \(error.localizedDescription)")
    }
}
