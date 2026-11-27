import Foundation
import SwiftData

/// Moves saved places whose codes were retired by a data change onto their replacement codes.
/// Runs at launch; idempotent because migrated records are soft-deleted (so the deletion syncs).
enum LegacyPlaceMigration {
    struct Target: Equatable {
        let regionType: VisitedPlace.RegionType
        let regionCode: String
        let regionName: String
    }

    /// Spanish autonomous communities that map onto exactly one province.
    /// Multi-province communities (e.g. Andalusia) have no faithful province equivalent.
    static let spanishCommunityToProvince: [String: String] = [
        "AS": "O", "CB": "S", "IB": "PM", "MC": "MU", "MD": "M", "NC": "NA", "RI": "LO",
    ]

    static func target(regionType: String, regionCode: String) -> Target? {
        let code = String(regionCode.split(separator: "-").last ?? Substring(regionCode))
        switch regionType {
        case VisitedPlace.RegionType.russianFederalSubject.rawValue where code == "SEV":
            return Target(regionType: .country, regionCode: "XS", regionName: "Sevastopol")
        case VisitedPlace.RegionType.spanishCommunity.rawValue:
            guard let province = spanishCommunityToProvince[code],
                  let name = GeographicData.states(for: "ES").first(where: { $0.id == province })?.name
            else { return nil }
            return Target(regionType: .spanishCommunity, regionCode: province, regionName: name)
        default:
            return nil
        }
    }

    @MainActor
    static func run(in context: ModelContext, now: Date = Date()) {
        guard let places = try? context.fetch(FetchDescriptor<VisitedPlace>(predicate: #Predicate { !$0.isDeleted })) else {
            return
        }
        var changed = false
        for place in places {
            guard let target = target(regionType: place.regionType, regionCode: place.regionCode) else { continue }
            if let existing = places.first(where: {
                !$0.isDeleted && $0.regionType == target.regionType.rawValue
                    && $0.regionCode == target.regionCode && $0.status == place.status
            }) {
                // Keep the retired record's history on the surviving one.
                if let date = place.visitedDate, existing.visitedDate.map({ date < $0 }) ?? true {
                    existing.visitedDate = date
                }
                existing.departureDate = existing.departureDate ?? place.departureDate
                existing.notes = existing.notes ?? place.notes
                existing.lastModifiedAt = now
                existing.isSynced = false
            } else {
                context.insert(VisitedPlace(
                    regionType: target.regionType,
                    regionCode: target.regionCode,
                    regionName: target.regionName,
                    status: place.statusEnum,
                    visitType: place.visitTypeEnum,
                    visitedDate: place.visitedDate,
                    departureDate: place.departureDate,
                    notes: place.notes,
                    markedAt: place.markedAt
                ))
            }
            place.isDeleted = true
            place.lastModifiedAt = now
            place.isSynced = false
            changed = true
        }
        if changed {
            try? context.save()
        }
    }
}
