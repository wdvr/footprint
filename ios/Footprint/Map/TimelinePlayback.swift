import Foundation

/// One place appearing in timeline playback, in the order it was first visited.
struct TimelineStop: Identifiable, Equatable, Sendable {
    let id: String
    let date: Date
    let regionType: String
    let regionCode: String
    let regionName: String
    /// Country the place belongs to (itself for a country).
    let countryCode: String
    var coordinate: GeoPoint?

    var isCountry: Bool { regionType == VisitedPlace.RegionType.country.rawValue }

    /// Parent country of each subdivision region type.
    static let regionTypeToCountry: [String: String] = [
        VisitedPlace.RegionType.usState.rawValue: "US",
        VisitedPlace.RegionType.canadianProvince.rawValue: "CA",
        VisitedPlace.RegionType.belgianProvince.rawValue: "BE",
        VisitedPlace.RegionType.dutchProvince.rawValue: "NL",
        VisitedPlace.RegionType.frenchRegion.rawValue: "FR",
        VisitedPlace.RegionType.spanishCommunity.rawValue: "ES",
        VisitedPlace.RegionType.italianRegion.rawValue: "IT",
        VisitedPlace.RegionType.germanState.rawValue: "DE",
        VisitedPlace.RegionType.ukCountry.rawValue: "GB",
        VisitedPlace.RegionType.russianFederalSubject.rawValue: "RU",
        VisitedPlace.RegionType.argentineProvince.rawValue: "AR",
        VisitedPlace.RegionType.australianState.rawValue: "AU",
        VisitedPlace.RegionType.mexicanState.rawValue: "MX",
        VisitedPlace.RegionType.brazilianState.rawValue: "BR",
        VisitedPlace.RegionType.japanesePrefecture.rawValue: "JP",
        VisitedPlace.RegionType.southKoreanProvince.rawValue: "KR",
        VisitedPlace.RegionType.norwegianCounty.rawValue: "NO",
    ]

    /// Visited countries and subdivisions (not counties, not bucket list), oldest first; undated
    /// places use the day they were marked.
    static func stops(from places: [VisitedPlace]) -> [TimelineStop] {
        places
            .filter { !$0.isDeleted && $0.isVisited && $0.regionType != VisitedPlace.RegionType.usCounty.rawValue }
            .map { place in
                TimelineStop(
                    id: "\(place.regionType):\(place.regionCode)",
                    date: place.visitedDate ?? place.markedAt,
                    regionType: place.regionType,
                    regionCode: place.regionCode,
                    regionName: place.regionName,
                    countryCode: place.regionType == VisitedPlace.RegionType.country.rawValue
                        ? place.regionCode
                        : regionTypeToCountry[place.regionType] ?? place.regionCode
                )
            }
            .sorted { ($0.date, $0.id) < ($1.date, $1.id) }
    }
}

struct GeoPoint: Equatable, Hashable, Sendable {
    var latitude: Double
    var longitude: Double

    /// A point inside the ring: the bounding-box middle when that is inside, otherwise the middle of
    /// the widest stretch of the ring along the box's middle latitude (for Norway, Vietnam, Croatia...).
    static func interiorPoint(of ring: [GeoPoint]) -> GeoPoint? {
        guard let first = ring.first else { return nil }
        var minLat = first.latitude, maxLat = first.latitude, minLon = first.longitude, maxLon = first.longitude
        for p in ring {
            minLat = min(minLat, p.latitude); maxLat = max(maxLat, p.latitude)
            minLon = min(minLon, p.longitude); maxLon = max(maxLon, p.longitude)
        }
        let middle = GeoPoint(latitude: (minLat + maxLat) / 2, longitude: (minLon + maxLon) / 2)
        if contains(middle, in: ring) { return middle }
        let crossings = edges(of: ring).compactMap { a, b -> Double? in
            guard (a.latitude > middle.latitude) != (b.latitude > middle.latitude) else { return nil }
            return a.longitude + (middle.latitude - a.latitude) / (b.latitude - a.latitude) * (b.longitude - a.longitude)
        }.sorted()
        var best: (west: Double, east: Double)?
        for i in stride(from: 0, to: crossings.count - 1, by: 2) where crossings[i + 1] - crossings[i] > (best.map { $0.east - $0.west } ?? 0) {
            best = (crossings[i], crossings[i + 1])
        }
        guard let best else { return middle }
        return GeoPoint(latitude: middle.latitude, longitude: (best.west + best.east) / 2)
    }

    static func contains(_ point: GeoPoint, in ring: [GeoPoint]) -> Bool {
        var inside = false
        for (a, b) in edges(of: ring) where (a.latitude > point.latitude) != (b.latitude > point.latitude) {
            let longitude = a.longitude + (point.latitude - a.latitude) / (b.latitude - a.latitude) * (b.longitude - a.longitude)
            if point.longitude < longitude { inside.toggle() }
        }
        return inside
    }

    private static func edges(of ring: [GeoPoint]) -> [(GeoPoint, GeoPoint)] {
        guard ring.count > 1 else { return [] }
        return ring.indices.map { (ring[$0], ring[($0 + 1) % ring.count]) }
    }

    /// Point `fraction` of the way along the great circle to `other`, so legs bend like flight paths
    /// and cross the antimeridian the short way.
    func interpolated(to other: GeoPoint, fraction: Double) -> GeoPoint {
        func vector(_ p: GeoPoint) -> (Double, Double, Double) {
            let lat = p.latitude * .pi / 180, lon = p.longitude * .pi / 180
            return (cos(lat) * cos(lon), cos(lat) * sin(lon), sin(lat))
        }
        let a = vector(self), b = vector(other)
        let dot = max(-1, min(1, a.0 * b.0 + a.1 * b.1 + a.2 * b.2))
        let angle = acos(dot)
        guard angle > 1e-9, abs(angle - .pi) > 1e-9 else { return fraction < 0.5 ? self : other }
        let wa = sin((1 - fraction) * angle) / sin(angle), wb = sin(fraction * angle) / sin(angle)
        let x = wa * a.0 + wb * b.0, y = wa * a.1 + wb * b.1, z = wa * a.2 + wb * b.2
        return GeoPoint(latitude: atan2(z, sqrt(x * x + y * y)) * 180 / .pi, longitude: atan2(y, x) * 180 / .pi)
    }
}

/// Playback state for the timeline: a continuous position along the stops, so every tick moves
/// the journey forward however few places there are.
struct TimelinePlayback: Equatable, Sendable {
    /// Seconds per stop at 1x, bounded so short histories still play and long ones do not drag.
    static let secondsPerStop = 1.2
    static let durationRange: ClosedRange<Double> = 8...60

    var stops: [TimelineStop]
    /// -1 before the first stop appears; `k + f` means stops 0...k are shown and the line is `f` of
    /// the way to stop k+1.
    private(set) var position: Double = -1

    init(stops: [TimelineStop]) {
        self.stops = stops
    }

    var duration: Double {
        min(max(Double(stops.count) * Self.secondsPerStop, Self.durationRange.lowerBound), Self.durationRange.upperBound)
    }

    private var endPosition: Double { Double(stops.count - 1) }

    var isAtEnd: Bool { !stops.isEmpty && position >= endPosition }

    /// 0...1, for the scrubber.
    var progress: Double {
        guard !stops.isEmpty else { return 0 }
        return (position + 1) / Double(stops.count)
    }

    var revealedCount: Int {
        guard !stops.isEmpty else { return 0 }
        return min(stops.count, Int(floor(position)) + 1)
    }

    var revealedStops: ArraySlice<TimelineStop> { stops.prefix(revealedCount) }

    var latestStop: TimelineStop? { revealedStops.last }

    mutating func advance(by seconds: Double, speed: Double = 1) {
        guard !stops.isEmpty else { return }
        position = min(endPosition, position + seconds * speed * Double(stops.count) / duration)
    }

    mutating func seek(toProgress value: Double) {
        guard !stops.isEmpty else { return }
        position = min(endPosition, max(-1, min(1, value) * Double(stops.count) - 1))
    }

    mutating func rewind() { position = -1 }

    mutating func skipToEnd() {
        guard !stops.isEmpty else { return }
        position = endPosition
    }

    /// The journey drawn so far: every shown stop with a known location, then the moving head
    /// partway (eased) to the next one.
    var journeyPath: [GeoPoint] {
        var path: [GeoPoint] = []
        for stop in revealedStops {
            if let point = stop.coordinate, path.last != point { path.append(point) }
        }
        let fraction = position - floor(position)
        if let from = path.last, fraction > 0, revealedCount < stops.count, let to = stops[revealedCount].coordinate {
            let eased = fraction * fraction * (3 - 2 * fraction)
            path.append(from.interpolated(to: to, fraction: eased))
        }
        return path
    }

    var visibleCountryCodes: Set<String> {
        Set(revealedStops.filter(\.isCountry).map(\.regionCode))
    }

    /// Map overlay codes ("US-CA"); a country tracked at country level fills all its subdivisions.
    func visibleStateCodes(tracksStates: (String) -> Bool, subdivisions: (String) -> [String]) -> Set<String> {
        var codes = Set<String>()
        for stop in revealedStops {
            if stop.regionType == VisitedPlace.RegionType.usState.rawValue
                || stop.regionType == VisitedPlace.RegionType.canadianProvince.rawValue {
                codes.insert("\(stop.countryCode)-\(stop.regionCode)")
            } else if stop.isCountry, !tracksStates(stop.regionCode) {
                for code in subdivisions(stop.regionCode) { codes.insert("\(stop.regionCode)-\(code)") }
            }
        }
        return codes
    }

    /// Landmarks whose place has appeared: a landmark tied to a subdivision waits for that
    /// subdivision when the country's subdivisions are being revealed, otherwise the country suffices.
    func visibleLandmarks(from catalog: [Landmark] = Landmark.catalog) -> [Landmark] {
        let shown = revealedStops
        let countries = Set(shown.map(\.countryCode))
        let subdivisions = Set(shown.filter { !$0.isCountry }.map { "\($0.countryCode)-\($0.regionCode)" })
        // Judged over the whole timeline, so a landmark never vanishes as later stops appear.
        let countriesWithSubdivisions = Set(stops.filter { !$0.isCountry }.map(\.countryCode))
        return catalog.filter { landmark in
            guard countries.contains(landmark.countryCode) else { return false }
            guard let sub = landmark.subdivisionCode, countriesWithSubdivisions.contains(landmark.countryCode) else { return true }
            return subdivisions.contains("\(landmark.countryCode)-\(sub)")
        }
    }
}

/// A famous sight drawn on the playback map as a 2.5D cartoon once its place has been visited.
struct Landmark: Identifiable, Hashable, Sendable {
    enum Style: String, CaseIterable, Sendable {
        case latticeTower, clockTower, statue, pyramid, dome, pagoda, sails, arena, gate, peak, wall, bridge,
             temple, windmill, spire, atomium
    }

    let id: String
    let name: String
    let countryCode: String
    let subdivisionCode: String?
    let coordinate: GeoPoint
    let style: Style

    init(_ id: String, _ name: String, _ countryCode: String, _ subdivisionCode: String? = nil,
         _ latitude: Double, _ longitude: Double, _ style: Style) {
        self.id = id
        self.name = name
        self.countryCode = countryCode
        self.subdivisionCode = subdivisionCode
        self.coordinate = GeoPoint(latitude: latitude, longitude: longitude)
        self.style = style
    }

    static let catalog: [Landmark] = [
        Landmark("eiffel", "Eiffel Tower", "FR", nil, 48.8584, 2.2945, .latticeTower),
        Landmark("bigben", "Big Ben", "GB", nil, 51.5007, -0.1246, .clockTower),
        Landmark("liberty", "Statue of Liberty", "US", "NY", 40.6892, -74.0445, .statue),
        Landmark("goldengate", "Golden Gate Bridge", "US", "CA", 37.8080, -122.4750, .bridge),
        Landmark("gatewayarch", "Gateway Arch", "US", "MO", 38.6247, -90.1848, .gate),
        Landmark("cntower", "CN Tower", "CA", "ON", 43.6426, -79.3871, .spire),
        Landmark("chichenitza", "Chichén Itzá", "MX", "YUC", 20.6843, -88.5678, .pyramid),
        Landmark("christ", "Christ the Redeemer", "BR", "RJ", -22.9519, -43.2105, .statue),
        Landmark("machupicchu", "Machu Picchu", "PE", nil, -13.1631, -72.5450, .peak),
        Landmark("obelisco", "Obelisco", "AR", nil, -34.6037, -58.3816, .spire),
        Landmark("giza", "Pyramids of Giza", "EG", nil, 29.9792, 31.1342, .pyramid),
        Landmark("tablemountain", "Table Mountain", "ZA", nil, -33.9628, 18.4098, .peak),
        Landmark("kilimanjaro", "Kilimanjaro", "TZ", nil, -3.0674, 37.3556, .peak),
        Landmark("petra", "Petra", "JO", nil, 30.3285, 35.4444, .temple),
        Landmark("burj", "Burj Khalifa", "AE", nil, 25.1972, 55.2744, .spire),
        Landmark("tajmahal", "Taj Mahal", "IN", nil, 27.1751, 78.0421, .dome),
        Landmark("greatwall", "Great Wall", "CN", nil, 40.4319, 116.5704, .wall),
        Landmark("fuji", "Mount Fuji", "JP", nil, 35.3606, 138.7274, .peak),
        Landmark("gyeongbokgung", "Gyeongbokgung", "KR", nil, 37.5796, 126.9770, .pagoda),
        Landmark("taipei101", "Taipei 101", "TW", nil, 25.0340, 121.5645, .pagoda),
        Landmark("angkor", "Angkor Wat", "KH", nil, 13.4125, 103.8670, .pagoda),
        Landmark("borobudur", "Borobudur", "ID", nil, -7.6079, 110.2038, .pagoda),
        Landmark("petronas", "Petronas Towers", "MY", nil, 3.1579, 101.7116, .spire),
        Landmark("operahouse", "Sydney Opera House", "AU", "NSW", -33.8568, 151.2153, .sails),
        Landmark("colosseum", "Colosseum", "IT", nil, 41.8902, 12.4922, .arena),
        Landmark("parthenon", "Parthenon", "GR", nil, 37.9715, 23.7267, .temple),
        Landmark("sagrada", "Sagrada Família", "ES", nil, 41.4036, 2.1744, .spire),
        Landmark("brandenburg", "Brandenburg Gate", "DE", nil, 52.5163, 13.3777, .gate),
        Landmark("kinderdijk", "Kinderdijk Windmills", "NL", nil, 51.8838, 4.6394, .windmill),
        Landmark("atomium", "Atomium", "BE", nil, 50.8949, 4.3415, .atomium),
        Landmark("stbasil", "St Basil's Cathedral", "RU", nil, 55.7525, 37.6231, .dome),
        Landmark("hagiasophia", "Hagia Sophia", "TR", nil, 41.0086, 28.9802, .dome),
    ]
}
