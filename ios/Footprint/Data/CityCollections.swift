import Foundation

/// A set of gazetteer cities shown with a visited count against its denominator.
enum CityCollection: String, CaseIterable, Identifiable, Sendable {
    case allCities = "all_cities"
    case nationalCapitals = "national_capitals"
    case usStateCapitals = "us_state_capitals"

    var id: String { rawValue }

    static let capitals: [CityCollection] = [.nationalCapitals, .usStateCapitals]

    var title: String {
        switch self {
        case .allCities: return "Cities"
        case .nationalCapitals: return "National Capitals"
        case .usStateCapitals: return "US State Capitals"
        }
    }

    /// Noun used in "38 of 195 national capitals".
    var unit: String {
        switch self {
        case .allCities: return "cities"
        case .nationalCapitals: return "national capitals"
        case .usStateCapitals: return "US state capitals"
        }
    }

    var icon: String {
        switch self {
        case .allCities: return "building.2.fill"
        case .nationalCapitals: return "star.fill"
        case .usStateCapitals: return "star.circle.fill"
        }
    }

    func contains(_ city: GazetteerCity) -> Bool {
        switch self {
        case .allCities: return true
        case .nationalCapitals: return city.isNationalCapital
        case .usStateCapitals: return city.isUSStateCapital
        }
    }
}

/// The fields of a `VisitedPlace` row that city counting needs, so counting is
/// independent of SwiftData.
struct CityVisitRecord: Hashable, Sendable {
    let regionType: String
    let regionCode: String
    let isVisited: Bool
    let isTransit: Bool
    let isDeleted: Bool
    var visitedDate: Date?
}

struct CityCollectionProgress: Identifiable, Equatable, Sendable {
    let collection: CityCollection
    let visited: Int
    let total: Int

    var id: String { collection.id }

    var fraction: Double {
        total > 0 ? Double(visited) / Double(total) : 0
    }

    /// "38 of 195 national capitals"
    var summary: String {
        "\(visited) of \(total) \(collection.unit)"
    }
}

enum CityVisitStatus: Sendable {
    case visited
    case transit
    case notYet
}

enum CityCounting {
    /// `VisitedPlace.regionType` of city rows (`VisitedPlace.RegionType.city`).
    static let regionType = "city"

    private static func liveCityRecords(_ records: [CityVisitRecord]) -> [CityVisitRecord] {
        records.filter { $0.regionType == regionType && !$0.isDeleted && $0.isVisited }
    }

    /// Cities with at least one full visit. Transit and bucket-list rows do not count
    /// toward coverage (spec §2.5).
    static func visitedCityIDs(from records: [CityVisitRecord]) -> Set<String> {
        Set(liveCityRecords(records).filter { !$0.isTransit }.map(\.regionCode))
    }

    /// Cities only passed through: a transit row and no full visit.
    static func transitCityIDs(from records: [CityVisitRecord]) -> Set<String> {
        let transit = Set(liveCityRecords(records).filter(\.isTransit).map(\.regionCode))
        return transit.subtracting(visitedCityIDs(from: records))
    }

    /// Earliest visit date per city, for list rows.
    static func firstVisitDates(from records: [CityVisitRecord]) -> [String: Date] {
        var dates: [String: Date] = [:]
        for record in liveCityRecords(records) {
            guard let date = record.visitedDate else { continue }
            dates[record.regionCode] = min(dates[record.regionCode] ?? date, date)
        }
        return dates
    }

    /// Visited count against the collection's denominator. Keys missing from the
    /// gazetteer are ignored so the count can never exceed the total.
    static func progress(
        for collection: CityCollection,
        in gazetteer: CityGazetteer,
        visitedIDs: Set<String>
    ) -> CityCollectionProgress {
        let members = gazetteer.cities(in: collection)
        let visited = members.filter { visitedIDs.contains($0.id) }.count
        return CityCollectionProgress(collection: collection, visited: visited, total: members.count)
    }

    static func progress(
        for collections: [CityCollection] = CityCollection.allCases,
        in gazetteer: CityGazetteer,
        records: [CityVisitRecord]
    ) -> [CityCollectionProgress] {
        let visitedIDs = visitedCityIDs(from: records)
        return collections.map { progress(for: $0, in: gazetteer, visitedIDs: visitedIDs) }
    }

    static func status(of cityID: String, visitedIDs: Set<String>, transitIDs: Set<String>) -> CityVisitStatus {
        if visitedIDs.contains(cityID) { return .visited }
        if transitIDs.contains(cityID) { return .transit }
        return .notYet
    }
}
