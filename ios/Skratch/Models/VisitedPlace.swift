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

    var id: UUID
    var regionType: String
    var regionCode: String
    var regionName: String
    var visitedDate: Date?
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
        visitedDate: Date? = nil,
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
        self.visitedDate = visitedDate
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
}
