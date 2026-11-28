import Foundation

/// Radius matching of coordinates to gazetteer cities (§2.3): a coordinate visits a city when it
/// falls within the city's radius of its centroid.
struct CityMatcher: Sendable {
    struct City: Sendable, Equatable {
        let id: String
        let name: String
        /// "city", "national" (national capital) or "us_state" (US state capital).
        let kind: String
        let latitude: Double
        let longitude: Double
        let radiusMeters: Double
    }

    private let cells: [Int: [City]]
    private static let cellDegrees = 1.0

    init(cities: [City]) {
        var cells: [Int: [City]] = [:]
        for city in cities {
            cells[Self.cell(city.latitude, city.longitude), default: []].append(city)
        }
        self.cells = cells
    }

    private static func cell(_ lat: Double, _ lon: Double) -> Int {
        let row = Int(floor((lat + 90) / cellDegrees))
        let col = Int(floor((lon + 180) / cellDegrees))
        return row * 1000 + col
    }

    /// Every city whose radius contains the coordinate.
    func cities(latitude: Double, longitude: Double) -> [City] {
        var result: [City] = []
        for dLat in -1...1 {
            for dLon in -1...1 {
                let key = Self.cell(latitude + Double(dLat) * Self.cellDegrees, longitude + Double(dLon) * Self.cellDegrees)
                for city in cells[key] ?? [] where Self.meters(latitude, longitude, city.latitude, city.longitude) <= city.radiusMeters {
                    result.append(city)
                }
            }
        }
        return result
    }

    /// The nearest city of each kind whose radius contains the coordinate, so a stay in Jersey City
    /// does not also count New York.
    func nearestCities(latitude: Double, longitude: Double) -> [City] {
        var nearest: [String: (city: City, meters: Double)] = [:]
        for city in cities(latitude: latitude, longitude: longitude) {
            let meters = Self.meters(latitude, longitude, city.latitude, city.longitude)
            if let best = nearest[city.kind], best.meters <= meters { continue }
            nearest[city.kind] = (city, meters)
        }
        return nearest.values.map(\.city).sorted { ($0.kind, $0.id) < ($1.kind, $1.id) }
    }

    /// First visit to each city, from dated coordinates.
    func hits(_ coordinates: [MedalEngine.CoordinateFact]) -> [MedalEngine.CityHit] {
        var first: [String: MedalEngine.CityHit] = [:]
        for coordinate in coordinates {
            for city in nearestCities(latitude: coordinate.latitude, longitude: coordinate.longitude) {
                let key = "\(city.kind):\(city.id)"
                if let existing = first[key], existing.date <= coordinate.date { continue }
                first[key] = MedalEngine.CityHit(id: city.id, kind: city.kind, name: city.name, date: coordinate.date)
            }
        }
        return first.values.sorted { ($0.date, $0.id, $0.kind) < ($1.date, $1.id, $1.kind) }
    }

    static func meters(_ lat1: Double, _ lon1: Double, _ lat2: Double, _ lon2: Double) -> Double {
        let r = 6_371_000.0
        let p1 = lat1 * .pi / 180, p2 = lat2 * .pi / 180
        let dp = (lat2 - lat1) * .pi / 180, dl = (lon2 - lon1) * .pi / 180
        let a = sin(dp / 2) * sin(dp / 2) + cos(p1) * cos(p2) * sin(dl / 2) * sin(dl / 2)
        return 2 * r * asin(min(1, sqrt(a)))
    }
}
