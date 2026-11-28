import Foundation

/// The headline numbers shown on the Stats tab, computed in one place so every surface
/// that prints them (Stats tab, poster export) shows the same values.
struct TravelStatistics: Equatable, Sendable {
    let countriesVisited: Int
    let countriesTotal: Int
    let usStatesVisited: Int
    let usStatesTotal: Int
    let canadianProvincesVisited: Int
    let canadianProvincesTotal: Int
    let continentsVisited: Int
    let continentsTotal: Int

    let countriesBucketList: Int
    let usStatesBucketList: Int
    let canadianProvincesBucketList: Int

    /// Countries + US states + Canadian provinces, as the Stats tab's "Total Regions Visited".
    var totalRegionsVisited: Int {
        countriesVisited + usStatesVisited + canadianProvincesVisited
    }

    var totalBucketList: Int {
        countriesBucketList + usStatesBucketList + canadianProvincesBucketList
    }

    /// Share of `GeographicData.countries` visited, 0–100 (the "Countries Visited" card).
    var countriesPercentage: Double {
        Self.percentage(countriesVisited, of: countriesTotal)
    }

    var usStatesPercentage: Double {
        Self.percentage(usStatesVisited, of: usStatesTotal)
    }

    var canadianProvincesPercentage: Double {
        Self.percentage(canadianProvincesVisited, of: canadianProvincesTotal)
    }

    init(places: [VisitedPlace]) {
        let live = places.filter { !$0.isDeleted }

        func count(_ type: VisitedPlace.RegionType, _ include: (VisitedPlace) -> Bool) -> Int {
            live.filter { $0.regionType == type.rawValue && include($0) }.count
        }

        countriesVisited = count(.country) { $0.isVisited }
        usStatesVisited = count(.usState) { $0.isVisited }
        canadianProvincesVisited = count(.canadianProvince) { $0.isVisited }
        countriesBucketList = count(.country) { $0.isBucketList }
        usStatesBucketList = count(.usState) { $0.isBucketList }
        canadianProvincesBucketList = count(.canadianProvince) { $0.isBucketList }

        countriesTotal = GeographicData.countries.count
        usStatesTotal = GeographicData.usStates.count
        canadianProvincesTotal = GeographicData.canadianProvinces.count

        let visitedCountryCodes = live
            .filter { $0.regionType == VisitedPlace.RegionType.country.rawValue && $0.isVisited }
            .map(\.regionCode)
        let continents = LocalContinentStats.calculateStats(visitedCountries: visitedCountryCodes)
        continentsVisited = continents.filter { $0.visited > 0 }.count
        continentsTotal = LocalContinentStats.continentData.count
    }

    /// Subdivision coverage for every country tracked at subdivision level, as shown on the
    /// map's country popups (`CountryCoverage`). Only countries with at least one visited
    /// subdivision are returned, most explored first.
    static func subdivisionCoverage(
        places: [VisitedPlace],
        trackedCountries: Set<String>
    ) -> [CountryCoverage] {
        let live = places.filter { !$0.isDeleted }
        return GeographicData.countries
            .filter { $0.hasStates && trackedCountries.contains($0.id) }
            .compactMap { CountryCoverage.coverage(for: $0.id, visitedPlaces: live) }
            .filter { $0.visitedCount > 0 }
            .sorted {
                if $0.percentage != $1.percentage { return $0.percentage > $1.percentage }
                if $0.visitedCount != $1.visitedCount { return $0.visitedCount > $1.visitedCount }
                return $0.countryName < $1.countryName
            }
    }

    private static func percentage(_ count: Int, of total: Int) -> Double {
        guard total > 0 else { return 0 }
        return Double(count) / Double(total) * 100
    }
}
