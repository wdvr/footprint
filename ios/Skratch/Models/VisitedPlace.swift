import Foundation
import SwiftData

@Model
final class VisitedPlace {
    var userID: String
    var regionType: String
    var regionCode: String
    var regionName: String
    var visitedDate: Date?
    var notes: String?

    // Tracking metadata
    var markedAt: Date
    var markedFromDevice: String?

    // Sync metadata
    var syncVersion: Int
    var lastModifiedAt: Date
    var isDeleted: Bool

    // Computed property for composite key
    var compositeKey: String {
        "\(userID)_\(regionType)_\(regionCode)"
    }

    init(
        userID: String,
        regionType: String,
        regionCode: String,
        regionName: String,
        visitedDate: Date? = nil,
        notes: String? = nil
    ) {
        self.userID = userID
        self.regionType = regionType
        self.regionCode = regionCode
        self.regionName = regionName
        self.visitedDate = visitedDate
        self.notes = notes
        self.markedAt = Date()
        self.markedFromDevice = "iOS Device"
        self.syncVersion = 1
        self.lastModifiedAt = Date()
        self.isDeleted = false
    }
}

// MARK: - Region Type Constants
extension VisitedPlace {
    enum RegionType: String, CaseIterable {
        case country = "country"
        case usState = "us_state"
        case canadianProvince = "canadian_province"

        var displayName: String {
            switch self {
            case .country:
                return "Country"
            case .usState:
                return "US State"
            case .canadianProvince:
                return "Canadian Province"
            }
        }
    }
}