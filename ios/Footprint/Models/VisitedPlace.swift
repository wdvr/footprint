import Foundation
import SwiftData

@Model
final class VisitedPlace {
    enum RegionType: String, Codable, CaseIterable {
        case country = "country"
        case usState = "us_state"
        case canadianProvince = "canadian_province"

        var displayName: String {
            switch self {
            case .country: return "Country"
            case .usState: return "US State"
            case .canadianProvince: return "Canadian Province"
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
