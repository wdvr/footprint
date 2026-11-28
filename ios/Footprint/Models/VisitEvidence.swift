import Foundation
import SwiftData

/// Raw location evidence (§3.1). On-device only, never synced; kept for 13 months.
@Model
final class LocationSample {
    var id: UUID = UUID()
    var timestamp: Date = Date.distantPast
    var latitude: Double = 0
    var longitude: Double = 0
    /// Meters.
    var horizontalAccuracy: Double = 0
    var sourceRaw: String = SampleSource.gps.rawValue
    /// nil = not yet consumed by the visit pipeline.
    var processedAt: Date?

    init(
        timestamp: Date,
        latitude: Double,
        longitude: Double,
        horizontalAccuracy: Double,
        source: SampleSource = .gps,
        processedAt: Date? = nil
    ) {
        self.timestamp = timestamp
        self.latitude = latitude
        self.longitude = longitude
        self.horizontalAccuracy = horizontalAccuracy
        self.sourceRaw = source.rawValue
        self.processedAt = processedAt
    }

    var source: SampleSource { SampleSource(rawValue: sourceRaw) ?? .gps }

    var evidence: EvidenceSample {
        EvidenceSample(
            timestamp: timestamp, latitude: latitude, longitude: longitude,
            horizontalAccuracy: horizontalAccuracy, source: source
        )
    }
}

/// A confirmed (or transit) stay derived from samples: the evidence ledger behind `VisitedPlace` (§3.1).
@Model
final class Visit {
    var id: UUID = UUID()
    var arrivedAt: Date = Date.distantPast
    /// nil = ongoing.
    var departedAt: Date?
    var centroidLat: Double = 0
    var centroidLon: Double = 0
    var sampleCount: Int = 0
    var sourceRaw: String = SampleSource.gps.rawValue
    /// `PlaceLevel` raw value: the deepest place this row is evidence for.
    var levelRaw: String = PlaceLevel.country.rawValue
    /// `DetectedVisitKind` raw value.
    var kindRaw: String = DetectedVisitKind.visited.rawValue
    var countryCode: String?
    /// Short subdivision code as used by `GeographicData` (e.g. "CA" for US-CA).
    var subdivisionCode: String?
    var countyFips: String?
    var cityId: String?
    var regionIds: [String] = []
    /// `VisitEvidenceKind` raw value. Rows written before this field default to detected.
    var evidenceRaw: String = VisitEvidenceKind.detected.rawValue
    /// False for a grandfathered place saved without a visit date.
    var isDateKnown: Bool = true

    init(_ detected: DetectedVisit) {
        self.arrivedAt = detected.arrivedAt
        self.departedAt = detected.departedAt
        self.centroidLat = detected.centroidLatitude
        self.centroidLon = detected.centroidLongitude
        self.sampleCount = detected.sampleCount
        self.sourceRaw = detected.source.rawValue
        self.levelRaw = detected.level.rawValue
        self.kindRaw = detected.kind.rawValue
        self.countryCode = detected.countryCode
        self.subdivisionCode = detected.subdivisionCode
    }

    var source: SampleSource { SampleSource(rawValue: sourceRaw) ?? .gps }
    var level: PlaceLevel { PlaceLevel(rawValue: levelRaw) ?? .country }
    var kind: DetectedVisitKind { DetectedVisitKind(rawValue: kindRaw) ?? .visited }
    var evidence: VisitEvidenceKind { VisitEvidenceKind(rawValue: evidenceRaw) ?? .detected }
    /// Rows of a level the log has no `PlaceLevel` for (e.g. city evidence) stay out of the log
    /// instead of being read as country rows.
    var isLogRow: Bool { PlaceLevel(rawValue: levelRaw) != nil }

    var logEntry: VisitLogEntry {
        VisitLogEntry(
            level: level, countryCode: countryCode ?? "", subdivisionCode: subdivisionCode, kind: kind,
            arrivedAt: arrivedAt, departedAt: departedAt, centroidLatitude: centroidLat, centroidLongitude: centroidLon,
            source: source, evidence: evidence, isDateKnown: isDateKnown
        )
    }
}
