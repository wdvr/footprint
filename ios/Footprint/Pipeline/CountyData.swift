import Foundation

/// One US county or county equivalent from `counties_index.json` (§2.2).
struct CountyInfo: Codable, Sendable, Equatable, Identifiable {
    let name: String
    let state: String
    /// Local term for the equivalent: "county", "parish", "borough", "city", "municipio", ...
    let term: String
    let landKm2: Double
    /// An interior point of the full-resolution county that its pack also contains.
    let lat: Double
    let lon: Double
    var fips: String = ""

    var id: String { fips }

    private enum CodingKeys: String, CodingKey {
        case name, state, term, landKm2, lat, lon
    }
}

/// FIPS-keyed registry of every county the app knows; the denominator for county coverage.
struct CountyIndex: Sendable {
    let source: String
    let counties: [String: CountyInfo]

    private struct File: Decodable {
        let source: String
        let counties: [String: CountyInfo]
    }

    init(data: Data) throws {
        let file = try JSONDecoder().decode(File.self, from: data)
        source = file.source
        var counties: [String: CountyInfo] = [:]
        for (fips, info) in file.counties {
            var info = info
            info.fips = fips
            counties[fips] = info
        }
        self.counties = counties
    }

    /// Counties of a state (short code, e.g. "CA"), sorted by name.
    func counties(inState state: String) -> [CountyInfo] {
        counties.values.filter { $0.state == state }.sorted { $0.name < $1.name }
    }

    var states: [String] { Array(Set(counties.values.map(\.state))).sorted() }

    /// Plural UI label for a state's county equivalents ("64 parishes", "29 boroughs and census areas").
    func pluralTerm(forState state: String) -> String {
        switch state {
        case "LA": return "parishes"
        case "AK": return "boroughs"
        case "PR": return "municipios"
        case "CT": return "planning regions"
        default: return "counties"
        }
    }
}

/// A county outline from a per-state pack: rings of (longitude, latitude) in degrees.
struct CountyShape: Sendable {
    let fips: String
    /// minLon, minLat, maxLon, maxLat.
    let bbox: [Double]
    /// polygons[p][0] is the outer ring; further rings are holes.
    let polygons: [[[(lon: Double, lat: Double)]]]

    func contains(latitude: Double, longitude: Double) -> Bool {
        guard longitude >= bbox[0], latitude >= bbox[1], longitude <= bbox[2], latitude <= bbox[3] else {
            return false
        }
        return polygons.contains { polygon in
            // Even-odd over all rings handles holes.
            polygon.reduce(false) { inside, ring in
                inside != Self.ringContains(ring, latitude: latitude, longitude: longitude)
            }
        }
    }

    private static func ringContains(_ ring: [(lon: Double, lat: Double)], latitude: Double, longitude: Double) -> Bool {
        var inside = false
        var j = ring.count - 1
        for i in ring.indices {
            let a = ring[i], b = ring[j]
            if (a.lat > latitude) != (b.lat > latitude),
               longitude < (b.lon - a.lon) * (latitude - a.lat) / (b.lat - a.lat) + a.lon {
                inside.toggle()
            }
            j = i
        }
        return inside
    }
}

enum CountyPack {
    private struct File: Decodable {
        struct County: Decodable {
            let fips: String
            let bbox: [Double]
            let polygons: [[[Int]]]
        }
        let scale: Double
        let counties: [County]
    }

    /// Decodes a `counties_US-<ST>.json` pack (delta-encoded integer rings, see build_us_counties.py).
    static func decode(_ data: Data) throws -> [CountyShape] {
        let file = try JSONDecoder().decode(File.self, from: data)
        return file.counties.map { county in
            CountyShape(fips: county.fips, bbox: county.bbox, polygons: county.polygons.map { polygon in
                polygon.map { flat in
                    var ring: [(lon: Double, lat: Double)] = []
                    ring.reserveCapacity(flat.count / 2)
                    var x = 0, y = 0
                    var k = 0
                    while k + 1 < flat.count {
                        x += flat[k]
                        y += flat[k + 1]
                        ring.append((Double(x) / file.scale, Double(y) / file.scale))
                        k += 2
                    }
                    return ring
                }
            })
        }
    }
}

/// Point-in-county matching with per-state lazy loading and a small LRU of parsed packs (§2.2, §5.2).
final class CountyMatcher: @unchecked Sendable {
    typealias Loader = @Sendable (_ state: String) -> Data?

    static let shared = CountyMatcher(loader: CountyMatcher.bundleLoader)

    static let bundleLoader: Loader = { state in
        guard let url = Bundle.main.url(forResource: "counties_US-\(state)", withExtension: "json") else { return nil }
        return try? Data(contentsOf: url)
    }

    private let loader: Loader
    private let capacity: Int
    private let lock = NSLock()
    private var cache: [String: [CountyShape]] = [:]
    private var recency: [String] = []

    init(loader: @escaping Loader, capacity: Int = 4) {
        self.loader = loader
        self.capacity = capacity
    }

    /// The parsed pack for a state (short code), loading it if needed.
    func shapes(forState state: String) -> [CountyShape] {
        lock.lock()
        defer { lock.unlock() }
        if let shapes = cache[state] {
            recency.removeAll { $0 == state }
            recency.append(state)
            return shapes
        }
        let shapes = loader(state).flatMap { try? CountyPack.decode($0) } ?? []
        cache[state] = shapes
        recency.append(state)
        while recency.count > capacity {
            cache[recency.removeFirst()] = nil
        }
        return shapes
    }

    var loadedStates: [String] {
        lock.lock()
        defer { lock.unlock() }
        return recency
    }

    /// FIPS of the county containing the point. The state comes from the subdivision matcher, so a
    /// fix only ever tests that state's counties, and the bbox check skips most of those.
    func county(latitude: Double, longitude: Double, state: String) -> String? {
        shapes(forState: state).first { $0.contains(latitude: latitude, longitude: longitude) }?.fips
    }
}

extension CountyIndex {
    static let shared: CountyIndex? = {
        guard let url = Bundle.main.url(forResource: "counties_index", withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return nil }
        return try? CountyIndex(data: data)
    }()
}
