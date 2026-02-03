import Foundation
import SwiftData

@Model
final class VisitedPlace {
    enum RegionType: String, Codable, CaseIterable {
        case country = "country"
        case usState = "us_state"
        case canadianProvince = "canadian_province"
        // International regions
        case australianState = "australian_state"
        case mexicanState = "mexican_state"
        case brazilianState = "brazilian_state"
        case germanState = "german_state"
        case frenchRegion = "french_region"
        case spanishCommunity = "spanish_community"
        case italianRegion = "italian_region"
        case dutchProvince = "dutch_province"
        case belgianProvince = "belgian_province"
        case ukCountry = "uk_country"
        case russianFederalSubject = "russian_federal_subject"
        case argentineProvince = "argentine_province"

        var displayName: String {
            switch self {
            case .country: return "Country"
            case .usState: return "US State"
            case .canadianProvince: return "Canadian Province"
            case .australianState: return "Australian State"
            case .mexicanState: return "Mexican State"
            case .brazilianState: return "Brazilian State"
            case .germanState: return "German State"
            case .frenchRegion: return "French Region"
            case .spanishCommunity: return "Spanish Community"
            case .italianRegion: return "Italian Region"
            case .dutchProvince: return "Dutch Province"
            case .belgianProvince: return "Belgian Province"
            case .ukCountry: return "UK Country"
            case .russianFederalSubject: return "Russian Federal Subject"
            case .argentineProvince: return "Argentine Province"
            }
        }
    }

    enum PlaceStatus: String, Codable, CaseIterable {
        case visited = "visited"
        case bucketList = "bucket_list"

        var displayName: String {
            switch self {
            case .visited: return "Visited"
            case .bucketList: return "Bucket List"
            }
        }

        var icon: String {
            switch self {
            case .visited: return "checkmark.circle.fill"
            case .bucketList: return "star.circle.fill"
            }
        }
    }

    enum VisitType: String, Codable, CaseIterable {
        case visited = "visited"
        case transit = "transit"

        var displayName: String {
            switch self {
            case .visited: return "Visited"
            case .transit: return "Transit/Layover"
            }
        }

        var icon: String {
            switch self {
            case .visited: return "figure.walk"
            case .transit: return "airplane"
            }
        }

        var color: String {
            switch self {
            case .visited: return "green"
            case .transit: return "orange"
            }
        }
    }

    var id: UUID
    var regionType: String
    var regionCode: String
    var regionName: String
    // Default values enable lightweight migration from older schema versions
    var status: String = "visited"
    var visitType: String = "visited"
    var visitedDate: Date?
    var departureDate: Date?
    var notes: String?
    var markedAt: Date
    var syncVersion: Int
    var lastModifiedAt: Date
    var isDeleted: Bool
    var isSynced: Bool

    init(
        id: UUID = UUID(),
        regionType: RegionType,
        regionCode: String,
        regionName: String,
        status: PlaceStatus = .visited,
        visitType: VisitType = .visited,
        visitedDate: Date? = nil,
        departureDate: Date? = nil,
        notes: String? = nil,
        markedAt: Date = Date(),
        syncVersion: Int = 1,
        lastModifiedAt: Date = Date(),
        isDeleted: Bool = false,
        isSynced: Bool = false
    ) {
        self.id = id
        self.regionType = regionType.rawValue
        self.regionCode = regionCode
        self.regionName = regionName
        self.status = status.rawValue
        self.visitType = visitType.rawValue
        self.visitedDate = visitedDate
        self.departureDate = departureDate
        self.notes = notes
        self.markedAt = markedAt
        self.syncVersion = syncVersion
        self.lastModifiedAt = lastModifiedAt
        self.isDeleted = isDeleted
        self.isSynced = isSynced
    }

    var regionTypeEnum: RegionType {
        RegionType(rawValue: regionType) ?? .country
    }

    var statusEnum: PlaceStatus {
        PlaceStatus(rawValue: status) ?? .visited
    }

    var visitTypeEnum: VisitType {
        VisitType(rawValue: visitType) ?? .visited
    }

    var isVisited: Bool {
        statusEnum == .visited
    }

    var isBucketList: Bool {
        statusEnum == .bucketList
    }

    var isTransit: Bool {
        visitTypeEnum == .transit
    }

    var isFullVisit: Bool {
        visitTypeEnum == .visited
    }

    /// Duration of visit in days (if both dates are set)
    var visitDuration: Int? {
        guard let arrival = visitedDate, let departure = departureDate else { return nil }
        let days = Calendar.current.dateComponents([.day], from: arrival, to: departure).day
        return days.map { max(1, $0 + 1) }  // At least 1 day
    }
}
