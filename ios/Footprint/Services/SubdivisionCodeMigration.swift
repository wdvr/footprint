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
/// inserted, or merged into an existing short-code row. If the user removed the short-code row after
/// the prefixed copy was last changed, the prefixed copy is only removed.
@MainActor
enum SubdivisionCodeMigration {
    @discardableResult
    static func run(in context: ModelContext, now: Date = Date()) -> Int {
        guard let all = try? context.fetch(FetchDescriptor<VisitedPlace>()) else { return 0 }
        let places = all.filter { !$0.isDeleted }
        var live: [String: VisitedPlace] = [:]
        for place in places {
            live["\(place.regionType):\(place.regionCode)"] = place
        }
        var removedAt: [String: Date] = [:]
        for place in all where place.isDeleted {
            let key = "\(place.regionType):\(place.regionCode)"
            removedAt[key] = max(removedAt[key] ?? .distantPast, place.lastModifiedAt)
        }
        var migrated = 0
        for place in places where place.regionType != VisitedPlace.RegionType.country.rawValue {
            let parts = place.regionCode.split(separator: "-", maxSplits: 1).map(String.init)
            // Codes missing from the region list (e.g. Spanish provinces) are migrated too, so a
            // later import of the short code does not duplicate them.
            guard parts.count == 2,
                  GeographicData.regionType(for: parts[0])?.rawValue == place.regionType
            else { continue }
            let code = parts[1]
            let name = GeographicData.states(for: parts[0]).first { $0.id == code }?.name ?? place.regionName

            let key = "\(place.regionType):\(code)"
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
            } else if (removedAt[key] ?? .distantPast) < place.lastModifiedAt {
                let replacement = VisitedPlace(
                    regionType: place.regionTypeEnum,
                    regionCode: code,
                    regionName: name,
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
