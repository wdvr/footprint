import Foundation
import SwiftData

enum SubdivisionCode {
    /// Boundary files use ISO 3166-2 codes ("GB-WRL"); `VisitedPlace` and `GeographicData`
    /// store the part after the country ("WRL").
    static func short(_ code: String) -> String {
        guard let dash = code.firstIndex(of: "-") else { return code }
        return String(code[code.index(after: dash)...])
    }
}

/// Photo import used to save boundary-file codes ("GB-WRL") for countries other than the US and
/// Canada, so those places never showed as visited and could be saved twice. Rewrites them to the
/// short code. The old row is soft-deleted (so sync removes it on the server) and a new row is
/// inserted, or merged into an existing short-code row.
@MainActor
enum SubdivisionCodeMigration {
    @discardableResult
    static func run(in context: ModelContext, now: Date = Date()) -> Int {
        guard let places = try? context.fetch(FetchDescriptor<VisitedPlace>(predicate: #Predicate { !$0.isDeleted })) else {
            return 0
        }
        var live: [String: VisitedPlace] = [:]
        for place in places {
            live["\(place.regionType):\(place.regionCode)"] = place
        }
        var migrated = 0
        for place in places where place.regionType != VisitedPlace.RegionType.country.rawValue {
            let parts = place.regionCode.split(separator: "-", maxSplits: 1).map(String.init)
            guard parts.count == 2,
                  GeographicData.regionType(for: parts[0])?.rawValue == place.regionType,
                  let state = GeographicData.states(for: parts[0]).first(where: { $0.id == parts[1] })
            else { continue }

            let key = "\(place.regionType):\(state.id)"
            if let existing = live[key] {
                existing.visitedDate = [existing.visitedDate, place.visitedDate].compactMap { $0 }.min()
                existing.departureDate = existing.departureDate ?? place.departureDate
                existing.notes = existing.notes ?? place.notes
                if place.isVisited && !existing.isVisited {
                    existing.status = place.status
                    existing.visitType = place.visitType
                }
                existing.lastModifiedAt = now
                existing.isSynced = false
            } else {
                let replacement = VisitedPlace(
                    regionType: place.regionTypeEnum,
                    regionCode: state.id,
                    regionName: state.name,
                    status: place.statusEnum,
                    visitType: place.visitTypeEnum,
                    visitedDate: place.visitedDate,
                    departureDate: place.departureDate,
                    notes: place.notes,
                    markedAt: place.markedAt,
                    lastModifiedAt: now
                )
                context.insert(replacement)
                live[key] = replacement
            }
            place.isDeleted = true
            place.lastModifiedAt = now
            place.isSynced = false
            migrated += 1
        }
        if migrated > 0 {
            try? context.save()
        }
        return migrated
    }
}
