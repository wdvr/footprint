import PDFKit
import XCTest

@testable import Footprint

@MainActor
final class ScratchPosterTests: XCTestCase {
    private func content(countries: Set<String>, states: Set<String> = []) -> ScratchPosterContent {
        ScratchPosterContent(title: "Test", visitedCountryCodes: countries, visitedStateCodes: states, continents: [],
                             date: Date(timeIntervalSince1970: 1_800_000_000))
    }

    // MARK: - Projection and layout

    func testRobinsonProjection() {
        XCTAssertEqual(RobinsonProjection.project(latitude: 0, longitude: 0), .zero)
        XCTAssertEqual(RobinsonProjection.project(latitude: 0, longitude: 180).x, 0.8487 * .pi, accuracy: 1e-9)
        XCTAssertEqual(RobinsonProjection.project(latitude: 90, longitude: 0).y, 1.3523, accuracy: 1e-9)
        XCTAssertEqual(RobinsonProjection.project(latitude: -45, longitude: 10).y,
                       -RobinsonProjection.project(latitude: 45, longitude: 10).y, accuracy: 1e-12)
        // Meridians converge toward the poles.
        XCTAssertLessThan(RobinsonProjection.project(latitude: 60, longitude: 90).x,
                          RobinsonProjection.project(latitude: 0, longitude: 90).x)
    }

    func testLayoutFitsTheMapOnThePage() {
        for size in ScratchPosterSize.allCases {
            let page = size.pointSize
            let layout = ScratchPosterLayout(pageSize: page)
            XCTAssertTrue(CGRect(origin: .zero, size: page).contains(layout.mapRect), size.rawValue)
            XCTAssertGreaterThan(layout.mapRect.width, page.width * 0.6, size.rawValue)
            XCTAssertLessThanOrEqual(layout.titleRect.maxY, layout.mapRect.minY, size.rawValue)
            XCTAssertLessThanOrEqual(layout.mapRect.maxY, layout.footerRect.minY, size.rawValue)
            let center = layout.point(latitude: 0, longitude: 0)
            XCTAssertEqual(center.x, layout.mapRect.midX, accuracy: 0.01)
            let corner = layout.point(latitude: 84, longitude: -180)
            XCTAssertEqual(corner.y, layout.mapRect.minY, accuracy: 0.01)
        }
    }

    func testPaperSizes() {
        XCTAssertEqual(ScratchPosterSize.a2.pointSize, CGSize(width: 1684, height: 1191))
        XCTAssertEqual(ScratchPosterSize.in24x36.pointSize, CGSize(width: 2592, height: 1728))
        let a3 = ScratchPosterSize.a3.printImage
        XCTAssertEqual(a3.dpi, 300)
        XCTAssertEqual(a3.size, CGSize(width: 4961, height: 3508))
        for size in ScratchPosterSize.allCases {
            let image = size.printImage
            XCTAssertLessThanOrEqual(image.size.width * image.size.height, ScratchPosterSize.maxPixels * 1.001, size.rawValue)
            XCTAssertGreaterThanOrEqual(image.dpi, 150, size.rawValue)
        }
    }

    func testRevealColoursAreStableAndVaried() {
        XCTAssertTrue(ScratchPosterTheme.revealColor(for: "FR") == ScratchPosterTheme.revealColor(for: "FR"))
        let colours = Set(["FR", "DE", "ES", "IT", "BE", "NL", "CH", "AT", "PL", "CZ", "PT", "GB", "IE", "DK", "SE", "NO"]
            .map { "\(ScratchPosterTheme.revealColor(for: $0))" })
        XCTAssertGreaterThanOrEqual(colours.count, 5)
    }

    // MARK: - Content

    func testContentFromPlaces() {
        let places = [
            VisitedPlace(regionType: .country, regionCode: "FR", regionName: "France"),
            VisitedPlace(regionType: .country, regionCode: "US", regionName: "United States"),
            VisitedPlace(regionType: .usState, regionCode: "CA", regionName: "California"),
            VisitedPlace(regionType: .country, regionCode: "JP", regionName: "Japan", status: .bucketList),
            VisitedPlace(regionType: .country, regionCode: "DE", regionName: "Germany", isDeleted: true),
            VisitedPlace(regionType: .usCounty, regionCode: "06075", regionName: "San Francisco County"),
        ]
        let content = ScratchPosterContent.make(title: "Ours", places: places)
        XCTAssertEqual(content.visitedCountryCodes, ["FR", "US"])
        XCTAssertEqual(content.visitedStateCodes, ["US-CA"])
        XCTAssertEqual(content.continentCount, 2)
        XCTAssertEqual(content.summary, "2 countries scratched · 1% of the world · 2 continents")
    }

    func testTerritoriesAreRevealedButNotCountedAsCountries() {
        let content = ScratchPosterContent.make(title: "Ice", places: [
            VisitedPlace(regionType: .country, regionCode: "GL", regionName: "Greenland"),
        ])
        XCTAssertEqual(content.visitedCountryCodes, ["GL"])
        XCTAssertEqual(content.countryCount, 0)
        XCTAssertEqual(content.worldPercent, 0)
    }

    // MARK: - Rendering

    func testPDFIsOnePageAtPaperSize() throws {
        let data = ScratchPosterRenderer.renderPDF(content(countries: ["FR"]), theme: .gold, size: .a2)
        let document = try XCTUnwrap(PDFDocument(data: data))
        XCTAssertEqual(document.pageCount, 1)
        let bounds = try XCTUnwrap(document.page(at: 0)).bounds(for: .mediaBox)
        XCTAssertEqual(bounds.size, ScratchPosterSize.a2.pointSize)
    }

    func testVisitedCountryIsScratchedOff() throws {
        let france = (latitude: 46.6, longitude: 2.4)
        let revealed = ScratchPosterTheme.revealColor(for: "FR")
        let visited = try pixel(content(countries: ["FR"]), at: france)
        let unvisited = try pixel(content(countries: []), at: france)
        XCTAssertLessThan(distance(visited, revealed), 0.06)
        XCTAssertGreaterThan(distance(unvisited, revealed), 0.2)
    }

    func testOnlyVisitedStatesAreScratchedOff() throws {
        let poster = content(countries: ["US"], states: ["US-CA"])
        let california = try pixel(poster, at: (36.8, -119.4))
        let texas = try pixel(poster, at: (31.0, -99.0))
        XCTAssertLessThan(distance(california, ScratchPosterTheme.revealColor(for: "US-CA")), 0.06)
        XCTAssertGreaterThan(distance(texas, ScratchPosterTheme.revealColor(for: "US-TX")), 0.2)
        XCTAssertGreaterThan(distance(texas, ScratchPosterTheme.revealColor(for: "US")), 0.2)
    }

    func testStatePostersKeepTheWholeCountryUnderTheFoil() {
        let parts = ScratchPosterRenderer.partition(content(countries: ["US"], states: ["US-CA"]))
        XCTAssertTrue(parts.foil.contains { $0.code == "US" })
        XCTAssertTrue(parts.foil.contains { $0.code == "US-TX" })
        XCTAssertEqual(parts.revealed.filter { $0.code.hasPrefix("US") }.map(\.code), ["US-CA"])
    }

    // MARK: - Helpers

    private func pixel(_ content: ScratchPosterContent, at coordinate: (Double, Double)) throws -> ScratchPosterTheme.RGB {
        let size = ScratchPosterSize.a3
        let width: CGFloat = 1600
        let image = try XCTUnwrap(ScratchPosterRenderer.renderImage(content, theme: .gold, size: size, pixelWidth: width).cgImage)
        let layout = ScratchPosterLayout(pageSize: size.pointSize)
        let scale = CGFloat(image.width) / size.pointSize.width
        let point = layout.point(latitude: coordinate.0, longitude: coordinate.1)
        let x = Int(point.x * scale), y = Int(point.y * scale)
        var bytes = [UInt8](repeating: 0, count: 4)
        let context = try XCTUnwrap(CGContext(data: &bytes, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
                                              space: CGColorSpaceCreateDeviceRGB(),
                                              bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.draw(image, in: CGRect(x: -x, y: y - image.height + 1, width: image.width, height: image.height))
        return (Double(bytes[0]) / 255, Double(bytes[1]) / 255, Double(bytes[2]) / 255)
    }

    private func distance(_ a: ScratchPosterTheme.RGB, _ b: ScratchPosterTheme.RGB) -> Double {
        max(abs(a.r - b.r), abs(a.g - b.g), abs(a.b - b.b))
    }
}
