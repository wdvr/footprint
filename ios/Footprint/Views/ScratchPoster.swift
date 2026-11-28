import CoreGraphics
import Foundation

/// Paper sizes for the printable scratch-map poster, always landscape.
enum ScratchPosterSize: String, CaseIterable, Identifiable, Sendable {
    case a3, a2, a1, cm50x70, in18x24, in24x36

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .a3: "A3"
        case .a2: "A2"
        case .a1: "A1"
        case .cm50x70: "50 × 70 cm"
        case .in18x24: "18 × 24 in"
        case .in24x36: "24 × 36 in"
        }
    }

    /// Long side by short side, in millimetres.
    var millimetres: (long: Double, short: Double) {
        switch self {
        case .a3: (420, 297)
        case .a2: (594, 420)
        case .a1: (841, 594)
        case .cm50x70: (700, 500)
        case .in18x24: (609.6, 457.2)
        case .in24x36: (914.4, 609.6)
        }
    }

    /// Landscape page size in PDF points (1/72 in).
    var pointSize: CGSize {
        let mm = millimetres
        return CGSize(width: (mm.long / 25.4 * 72).rounded(), height: (mm.short / 25.4 * 72).rounded())
    }

    /// Largest PNG export, in pixels; beyond this phones run out of memory.
    static let maxPixels = 36_000_000.0

    /// Pixel size and the resolution it gives: 300 dpi when that fits under `maxPixels`.
    var printImage: (size: CGSize, dpi: Int) {
        let mm = millimetres
        let inches = (long: mm.long / 25.4, short: mm.short / 25.4)
        let dpi = min(300, (Self.maxPixels / (inches.long * inches.short)).squareRoot().rounded(.down))
        return (CGSize(width: (inches.long * dpi).rounded(), height: (inches.short * dpi).rounded()), Int(dpi))
    }
}

/// Foil and ink colours, as RGB components so the renderer can run off the main actor.
enum ScratchPosterTheme: String, CaseIterable, Identifiable, Sendable {
    case gold, silver, copper, roseGold

    typealias RGB = (r: Double, g: Double, b: Double)

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .gold: "Gold"
        case .silver: "Silver"
        case .copper: "Copper"
        case .roseGold: "Rose Gold"
        }
    }

    /// Light, mid and dark foil tones for the unscratched land.
    var foil: (light: RGB, mid: RGB, dark: RGB) {
        switch self {
        case .gold: ((0.98, 0.90, 0.62), (0.85, 0.70, 0.36), (0.62, 0.47, 0.20))
        case .silver: ((0.95, 0.96, 0.97), (0.76, 0.78, 0.80), (0.52, 0.54, 0.58))
        case .copper: ((0.97, 0.76, 0.60), (0.80, 0.50, 0.32), (0.55, 0.30, 0.17))
        case .roseGold: ((0.99, 0.85, 0.80), (0.88, 0.63, 0.58), (0.66, 0.42, 0.40))
        }
    }

    var ocean: RGB {
        switch self {
        case .gold: (0.07, 0.13, 0.25)
        case .silver: (0.10, 0.12, 0.15)
        case .copper: (0.06, 0.18, 0.17)
        case .roseGold: (0.18, 0.10, 0.20)
        }
    }

    /// Page around the map.
    var frame: RGB {
        switch self {
        case .gold: (0.04, 0.08, 0.16)
        case .silver: (0.06, 0.07, 0.09)
        case .copper: (0.03, 0.11, 0.10)
        case .roseGold: (0.11, 0.06, 0.12)
        }
    }

    /// Colours revealed under the foil: saturated, and clear of every foil tone.
    static let revealPalette: [RGB] = [
        (0.94, 0.33, 0.36), (0.10, 0.68, 0.64), (0.25, 0.45, 0.90), (0.40, 0.75, 0.30),
        (0.85, 0.30, 0.62), (0.55, 0.40, 0.85), (0.20, 0.78, 0.85), (0.75, 0.15, 0.25),
    ]

    /// Stable per-place colour, so a reprint looks the same.
    static func revealColor(for code: String) -> RGB {
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        for byte in code.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x100_0000_01b3
        }
        return revealPalette[Int(hash % UInt64(revealPalette.count))]
    }
}

/// Robinson projection, the classic wall-map look. Output is in units where the equator spans
/// `-π * 0.8487 ... π * 0.8487` and the poles sit at `±1.3523`; y grows north.
enum RobinsonProjection {
    private static let x: [Double] = [1.0000, 0.9986, 0.9954, 0.9900, 0.9822, 0.9730, 0.9600, 0.9427, 0.9216, 0.8962,
                                      0.8679, 0.8350, 0.7986, 0.7597, 0.7186, 0.6732, 0.6213, 0.5722, 0.5322]
    private static let y: [Double] = [0.0000, 0.0620, 0.1240, 0.1860, 0.2480, 0.3100, 0.3720, 0.4340, 0.4958, 0.5571,
                                      0.6176, 0.6769, 0.7346, 0.7903, 0.8435, 0.8936, 0.9394, 0.9761, 1.0000]

    static func project(latitude: Double, longitude: Double) -> CGPoint {
        let lat = min(90, max(-90, latitude))
        let position = abs(lat) / 5
        let i = min(Int(position), 17)
        let f = position - Double(i)
        let px = x[i] + (x[i + 1] - x[i]) * f
        let py = y[i] + (y[i + 1] - y[i]) * f
        let lon = min(180, max(-180, longitude)) * .pi / 180
        return CGPoint(x: 0.8487 * px * lon, y: 1.3523 * py * (lat < 0 ? -1 : 1))
    }
}

/// Where the map sits on the page and how coordinates land on it. Shared by the renderer and tests.
struct ScratchPosterLayout: Sendable {
    let pageSize: CGSize
    let latitudeRange: ClosedRange<Double>
    let mapRect: CGRect
    let titleRect: CGRect
    let footerRect: CGRect

    init(pageSize: CGSize, includeAntarctica: Bool = false) {
        self.pageSize = pageSize
        latitudeRange = (includeAntarctica ? -86 : -58)...84
        let margin = pageSize.width * 0.035
        titleRect = CGRect(x: margin, y: margin, width: pageSize.width - 2 * margin, height: pageSize.height * 0.11)
        footerRect = CGRect(x: margin, y: pageSize.height - margin - pageSize.height * 0.10,
                            width: pageSize.width - 2 * margin, height: pageSize.height * 0.10)
        let available = CGRect(x: margin, y: titleRect.maxY + margin * 0.3, width: pageSize.width - 2 * margin,
                               height: footerRect.minY - titleRect.maxY - margin * 0.6)
        let top = RobinsonProjection.project(latitude: latitudeRange.upperBound, longitude: 0).y
        let bottom = RobinsonProjection.project(latitude: latitudeRange.lowerBound, longitude: 0).y
        let worldWidth = 2 * RobinsonProjection.project(latitude: 0, longitude: 180).x
        let aspect = worldWidth / (top - bottom)
        let width = min(available.width, available.height * aspect)
        let height = width / aspect
        mapRect = CGRect(x: available.midX - width / 2, y: available.midY - height / 2, width: width, height: height)
    }

    func point(latitude: Double, longitude: Double) -> CGPoint {
        let p = RobinsonProjection.project(latitude: latitude, longitude: longitude)
        let top = RobinsonProjection.project(latitude: latitudeRange.upperBound, longitude: 0).y
        let bottom = RobinsonProjection.project(latitude: latitudeRange.lowerBound, longitude: 0).y
        let halfWidth = RobinsonProjection.project(latitude: 0, longitude: 180).x
        return CGPoint(x: mapRect.minX + (p.x + halfWidth) / (2 * halfWidth) * mapRect.width,
                       y: mapRect.minY + (top - p.y) / (top - bottom) * mapRect.height)
    }
}

/// Everything printed on the poster.
struct ScratchPosterContent: Sendable, Equatable {
    var title: String
    var visitedCountryCodes: Set<String>
    /// "US-CA" style codes; a country listed here is revealed state by state.
    var visitedStateCodes: Set<String>
    var continents: [Continent]
    var date: Date
    /// Visited countries among the 195 counted for world progress (territories such as Greenland
    /// are revealed on the map but not counted).
    var countryCount = 0

    struct Continent: Sendable, Equatable {
        let name: String
        let visited: Int
        let total: Int
    }

    static let worldCountryCount = 195
    /// In the continent lists (197 entries) but outside the 195 counted for world progress.
    static let uncountedTerritories: Set<String> = ["TW", "XS"]

    var worldPercent: Int { Int((Double(countryCount) / Double(Self.worldCountryCount) * 100).rounded()) }

    var continentCount: Int { continents.filter { $0.visited > 0 }.count }

    var summary: String {
        let countries = countryCount == 1 ? "1 country" : "\(countryCount) countries"
        let continentsText = continentCount == 1 ? "1 continent" : "\(continentCount) continents"
        return "\(countries) scratched · \(worldPercent)% of the world · \(continentsText)"
    }

    /// Visited countries and US/Canadian states (not counties or the bucket list).
    static func make(title: String, places: [VisitedPlace], date: Date = Date()) -> ScratchPosterContent {
        let visited = places.filter { !$0.isDeleted && $0.isVisited }
        let countries = Set(visited.filter { $0.regionType == VisitedPlace.RegionType.country.rawValue }.map(\.regionCode))
        var states = Set<String>()
        for place in visited {
            if place.regionType == VisitedPlace.RegionType.usState.rawValue { states.insert("US-\(place.regionCode)") }
            if place.regionType == VisitedPlace.RegionType.canadianProvince.rawValue { states.insert("CA-\(place.regionCode)") }
        }
        var continents = LocalContinentStats.calculateStats(visitedCountries: Array(countries))
            .map { Continent(name: $0.name, visited: $0.visited, total: $0.total) }
        let countryCount = countries.subtracting(uncountedTerritories)
            .filter { code in LocalContinentStats.continentData.contains { $0.codes.contains(code) } }.count
        if countries.contains("AQ") { continents.append(Continent(name: "Antarctica", visited: 1, total: 1)) }
        return ScratchPosterContent(title: title, visitedCountryCodes: countries, visitedStateCodes: states,
                                    continents: continents, date: date,
                                    countryCount: countryCount)
    }
}
