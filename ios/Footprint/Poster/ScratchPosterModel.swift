import CoreGraphics
import Foundation

// MARK: - Poster Size

enum PosterSize: String, CaseIterable, Identifiable, Sendable {
    case a3
    case a2
    case a1

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .a3: return "A3 (297 x 420 mm)"
        case .a2: return "A2 (420 x 594 mm)"
        case .a1: return "A1 (594 x 841 mm)"
        }
    }

    /// Portrait PDF dimensions in points (72 per inch).
    var pdfSize: CGSize {
        switch self {
        case .a3: return CGSize(width: 842, height: 1191)
        case .a2: return CGSize(width: 1191, height: 1684)
        case .a1: return CGSize(width: 1684, height: 2384)
        }
    }

    /// Landscape PDF size; the poster is always landscape.
    var landscapeSize: CGSize {
        CGSize(width: pdfSize.height, height: pdfSize.width)
    }

    /// Print resolution of the PNG export.
    static let printDPI: CGFloat = 300

    /// Largest PNG the export renders, in pixels. A1 at 300 dpi would need a ~280 MB bitmap,
    /// so the larger sizes print at the highest resolution that fits this budget.
    static let maxPNGPixels: CGFloat = 40_000_000

    /// Resolution the PNG is rendered at: 300 dpi, or lower when that exceeds `maxPNGPixels`.
    var pngDPI: CGFloat {
        let inches = CGSize(width: landscapeSize.width / 72, height: landscapeSize.height / 72)
        let pixelsAtPrintDPI = inches.width * inches.height * Self.printDPI * Self.printDPI
        guard pixelsAtPrintDPI > Self.maxPNGPixels else { return Self.printDPI }
        return (Self.printDPI * (Self.maxPNGPixels / pixelsAtPrintDPI).squareRoot()).rounded(.down)
    }

    /// Landscape PNG size in pixels at `pngDPI`.
    var pngPixelSize: CGSize {
        let scale = pngDPI / 72
        return CGSize(
            width: (landscapeSize.width * scale).rounded(),
            height: (landscapeSize.height * scale).rounded()
        )
    }
}

// MARK: - Projection

/// Miller cylindrical projection cropped to the inhabited latitudes (Antarctica is left off).
enum ScratchPosterProjection {
    static let northLatitude: Double = 84
    static let southLatitude: Double = -60

    static func millerY(_ latitude: Double) -> Double {
        let lat = max(southLatitude, min(northLatitude, latitude)) * .pi / 180
        return 1.25 * log(tan(.pi / 4 + 0.4 * lat))
    }

    /// Width / height of the projected map.
    static var aspectRatio: Double {
        (2 * .pi) / (millerY(northLatitude) - millerY(southLatitude))
    }

    /// Projects a coordinate into `rect`. Longitude is not wrapped or clamped, so a ring that
    /// was unwrapped past ±180° keeps its shape; callers clip to the map rect.
    static func point(latitude: Double, longitude: Double, in rect: CGRect) -> CGPoint {
        let top = millerY(northLatitude)
        let bottom = millerY(southLatitude)
        let x = (longitude + 180) / 360
        let y = (top - millerY(latitude)) / (top - bottom)
        return CGPoint(x: rect.minX + CGFloat(x) * rect.width, y: rect.minY + CGFloat(y) * rect.height)
    }

    /// Removes ±360° jumps between consecutive longitudes so a ring crossing the antimeridian
    /// stays continuous (e.g. 179, -179 becomes 179, 181).
    static func unwrappedLongitudes(_ longitudes: [Double]) -> [Double] {
        guard var previous = longitudes.first else { return [] }
        var result = [previous]
        result.reserveCapacity(longitudes.count)
        for longitude in longitudes.dropFirst() {
            var value = longitude
            while value - previous > 180 { value -= 360 }
            while value - previous < -180 { value += 360 }
            result.append(value)
            previous = value
        }
        return result
    }
}

// MARK: - Layout

/// Where each block sits on a landscape page, in points.
struct ScratchPosterLayout: Equatable, Sendable {
    let page: CGRect
    let title: CGRect
    let map: CGRect
    let stats: CGRect
    let footer: CGRect

    init(pageSize: CGSize) {
        let page = CGRect(origin: .zero, size: pageSize)
        let margin = (min(pageSize.width, pageSize.height) * 0.05).rounded()
        let content = page.insetBy(dx: margin, dy: margin)

        let titleHeight = content.height * 0.13
        let statsHeight = content.height * 0.19
        let footerHeight = content.height * 0.035
        let gap = content.height * 0.02

        let title = CGRect(x: content.minX, y: content.minY, width: content.width, height: titleHeight)
        let footer = CGRect(
            x: content.minX, y: content.maxY - footerHeight, width: content.width, height: footerHeight
        )
        let stats = CGRect(
            x: content.minX, y: footer.minY - statsHeight, width: content.width, height: statsHeight
        )

        let mapSlot = CGRect(
            x: content.minX,
            y: title.maxY + gap,
            width: content.width,
            height: stats.minY - gap - (title.maxY + gap)
        )
        let aspect = CGFloat(ScratchPosterProjection.aspectRatio)
        var mapSize = CGSize(width: mapSlot.width, height: mapSlot.width / aspect)
        if mapSize.height > mapSlot.height {
            mapSize = CGSize(width: mapSlot.height * aspect, height: mapSlot.height)
        }
        let map = CGRect(
            x: mapSlot.midX - mapSize.width / 2,
            y: mapSlot.midY - mapSize.height / 2,
            width: mapSize.width,
            height: mapSize.height
        )

        self.page = page
        self.title = title
        self.map = map
        self.stats = stats
        self.footer = footer
    }
}

// MARK: - Poster Model

/// Everything the scratch-map poster prints, derived from the user's places with the same
/// rules the app uses for its map and Stats tab.
struct ScratchPosterModel: Equatable, Sendable {
    struct HeadlineStat: Equatable, Sendable {
        let value: String
        let label: String
    }

    struct CoverageLine: Equatable, Sendable {
        let countryCode: String
        let countryName: String
        let visitedCount: Int
        let totalCount: Int
        let subdivisionLabel: String
        let percentage: Double

        /// "23/51 states"
        var countText: String { "\(visitedCount)/\(totalCount) \(subdivisionLabel)" }
        /// "45%", formatted like the country popup's "% explored".
        var percentText: String { String(format: "%.0f%%", percentage) }
    }

    /// Countries whose subdivisions have bundled boundaries and can be drawn on the poster.
    static let subdivisionBoundaryCountries: Set<String> = [
        "US", "CA", "AR", "BE", "ES", "FR", "GB", "IT", "JP", "KR", "NL", "NO", "RU",
    ]

    /// Coverage lines that fit in the stats band.
    static let maxCoverageLines = 8

    let title: String
    let statistics: TravelStatistics
    let headline: [HeadlineStat]
    let coverage: [CoverageLine]
    let visitedCountryCodes: Set<String>
    /// Countries drawn subdivision by subdivision (tracked at state level, with boundaries).
    let subdivisionCountries: Set<String>
    /// Visited subdivision codes per country, short form ("MAN", not "GB-MAN").
    let visitedSubdivisions: [String: Set<String>]

    var subtitle: String {
        let countries = statistics.countriesVisited == 1 ? "country" : "countries"
        let continents = statistics.continentsVisited == 1 ? "continent" : "continents"
        return "\(statistics.countriesVisited) \(countries) across "
            + "\(statistics.continentsVisited) \(continents) · "
            + "\(Self.percentText(statistics.countriesPercentage)) of the world"
    }

    /// - Parameter trackedCountries: countries the user tracks at subdivision level
    ///   (`AppSettings.shouldTrackStates(for:)`).
    init(places: [VisitedPlace], trackedCountries: Set<String>, title: String) {
        let live = places.filter { !$0.isDeleted }
        let statistics = TravelStatistics(places: live)

        self.title = title
        self.statistics = statistics

        var headline = [
            HeadlineStat(value: "\(statistics.countriesVisited)", label: "of \(statistics.countriesTotal) countries"),
            HeadlineStat(value: Self.percentText(statistics.countriesPercentage), label: "of the world"),
            HeadlineStat(value: "\(statistics.continentsVisited)/\(statistics.continentsTotal)", label: "continents"),
        ]
        if trackedCountries.contains("US") {
            headline.append(HeadlineStat(
                value: "\(statistics.usStatesVisited)/\(statistics.usStatesTotal)", label: "US states"
            ))
        }
        if trackedCountries.contains("CA") {
            headline.append(HeadlineStat(
                value: "\(statistics.canadianProvincesVisited)/\(statistics.canadianProvincesTotal)",
                label: "Canadian provinces"
            ))
        }
        headline.append(HeadlineStat(value: "\(statistics.totalRegionsVisited)", label: "regions visited"))
        self.headline = headline

        coverage = TravelStatistics.subdivisionCoverage(places: live, trackedCountries: trackedCountries)
            .prefix(Self.maxCoverageLines)
            .map {
                CoverageLine(
                    countryCode: $0.countryCode,
                    countryName: $0.countryName,
                    visitedCount: $0.visitedCount,
                    totalCount: $0.totalCount,
                    subdivisionLabel: $0.subdivisionLabel,
                    percentage: $0.percentage
                )
            }

        visitedCountryCodes = Set(
            live.filter { $0.regionType == VisitedPlace.RegionType.country.rawValue && $0.isVisited }
                .map(\.regionCode)
        )

        let subdivisionCountries = Self.subdivisionBoundaryCountries.intersection(trackedCountries)
        self.subdivisionCountries = subdivisionCountries

        var visitedSubdivisions: [String: Set<String>] = [:]
        for countryCode in subdivisionCountries {
            guard let regionType = GeographicData.regionType(for: countryCode) else { continue }
            let codes = live
                .filter { $0.regionType == regionType.rawValue && $0.isVisited }
                .map { Self.shortSubdivisionCode($0.regionCode, countryCode: countryCode) }
            if !codes.isEmpty { visitedSubdivisions[countryCode] = Set(codes) }
        }
        self.visitedSubdivisions = visitedSubdivisions
    }

    /// Whether a subdivision boundary (`state_code` from the bundled GeoJSON, "GB-MAN" or "CA")
    /// is visited. Saved codes may be short ("MAN") or prefixed ("GB-MAN"); both match.
    func isSubdivisionVisited(countryCode: String, boundaryCode: String) -> Bool {
        guard let visited = visitedSubdivisions[countryCode] else { return false }
        return visited.contains(Self.shortSubdivisionCode(boundaryCode, countryCode: countryCode))
    }

    static func shortSubdivisionCode(_ code: String, countryCode: String) -> String {
        let prefix = "\(countryCode)-"
        return code.hasPrefix(prefix) ? String(code.dropFirst(prefix.count)) : code
    }

    /// "6.2%", formatted like the Stats tab's percentage.
    static func percentText(_ percentage: Double) -> String {
        String(format: "%.1f%%", percentage)
    }
}
