import Foundation

/// Medal city hits from the canonical gazetteer (§2.3). Medal coordinates (photos, stays) carry no
/// resolved country or subdivision, so matching here is by match area alone.
extension CityMatcher {
    /// The nearest gazetteer city whose match area contains the coordinate counts as a "city", so a
    /// stay in Jersey City does not also count New York. Capitals are kept as-is: neighbouring
    /// capitals (Rome and Vatican City) are different countries' capitals and both count.
    func medalCities(latitude: Double, longitude: Double) -> [(city: City, kind: String)] {
        let containing = gazetteer.cities(containing: latitude, longitude).map(\.city)
        var result: [(city: City, kind: String)] = []
        if let nearest = containing.first {
            result.append((nearest, "city"))
        }
        for city in containing {
            if city.isNationalCapital { result.append((city, "national")) }
            if city.isUSStateCapital { result.append((city, "us_state")) }
        }
        return result.sorted { ($0.kind, $0.city.id) < ($1.kind, $1.city.id) }
    }

    /// First visit to each city, from dated coordinates.
    func hits(_ coordinates: [MedalEngine.CoordinateFact]) -> [MedalEngine.CityHit] {
        var first: [String: MedalEngine.CityHit] = [:]
        for coordinate in coordinates {
            for (city, kind) in medalCities(latitude: coordinate.latitude, longitude: coordinate.longitude) {
                let key = "\(kind):\(city.id)"
                if let existing = first[key], existing.date <= coordinate.date { continue }
                first[key] = MedalEngine.CityHit(id: city.id, kind: kind, name: city.name, date: coordinate.date)
            }
        }
        return first.values.sorted { ($0.date, $0.id, $0.kind) < ($1.date, $1.id, $1.kind) }
    }
}
