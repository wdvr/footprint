import Foundation

/// Coarse motion state from the motion coprocessor (§5.1 layer 5).
enum MotionState: String, Sendable {
    case unknown
    case stationary
    case walking
    case automotive
    case flight
}

/// What the location stack should be doing right now (§5.1 layers 1–4).
struct SamplingMode: Sendable, Equatable {
    /// Layer 1: significant-location-change service.
    var significantChanges: Bool
    /// Layer 2: `CLVisit` monitoring.
    var visitMonitoring: Bool
    /// Layer 3: radius of the single rolling geofence around the last fix; nil = none.
    var geofenceRadiusMeters: Double?
    /// Layer 4: standard (GPS) location updates.
    var standardUpdates: Bool
    /// Meters; only meaningful while `standardUpdates` is on.
    var desiredAccuracyMeters: Double
    var distanceFilterMeters: Double
    /// Flight: only country-level evidence is meaningful.
    var countryLevelOnly: Bool

    static let off = SamplingMode(
        significantChanges: false, visitMonitoring: false, geofenceRadiusMeters: nil,
        standardUpdates: false, desiredAccuracyMeters: 100, distanceFilterMeters: 1_000, countryLevelOnly: false
    )
}

struct SamplingInputs: Sendable, Equatable {
    /// User opted into automatic tracking and granted Always authorization.
    var automaticTrackingEnabled: Bool
    var motion: MotionState = .unknown
    /// When the device was last seen to become stationary.
    var stationarySince: Date?
    /// The rolling geofence was exited since the last stationary period.
    var exitedGeofence = false
    /// Recent fixes are clustering into a candidate stay.
    var stayForming = false
    var now = Date()
}

/// Battery-safe layering of the capture stack: each layer only wakes the next (§5.1).
struct SamplingPolicy: Sendable {
    var geofenceRadiusMeters: Double = 2_000
    var movingDistanceFilterMeters: Double = 100
    var stayAccuracyMeters: Double = 10
    var movingAccuracyMeters: Double = 100
    /// No continuous GPS once stationary this long.
    var stationaryCutoff: TimeInterval = 15 * 60

    func mode(for inputs: SamplingInputs) -> SamplingMode {
        guard inputs.automaticTrackingEnabled else { return .off }

        var mode = SamplingMode(
            significantChanges: true,
            visitMonitoring: true,
            geofenceRadiusMeters: geofenceRadiusMeters,
            standardUpdates: false,
            desiredAccuracyMeters: inputs.stayForming ? stayAccuracyMeters : movingAccuracyMeters,
            distanceFilterMeters: movingDistanceFilterMeters,
            countryLevelOnly: false
        )

        switch inputs.motion {
        case .flight:
            // At flight speed only country-level evidence is meaningful; significant changes suffice.
            mode.countryLevelOnly = true
        case .stationary:
            let stationaryFor = inputs.stationarySince.map { inputs.now.timeIntervalSince($0) } ?? 0
            mode.standardUpdates = stationaryFor < stationaryCutoff && (inputs.stayForming || inputs.exitedGeofence)
        case .walking, .automotive:
            mode.standardUpdates = true
        case .unknown:
            mode.standardUpdates = inputs.exitedGeofence
        }
        return mode
    }
}
