import ImageIO
import PDFKit
import UIKit
import XCTest

@testable import Footprint

final class ScratchPosterRendererTests: XCTestCase {

    private func samplePoster() -> ScratchPosterModel {
        let places = [
            VisitedPlace(regionType: .country, regionCode: "FR", regionName: "France"),
            VisitedPlace(regionType: .country, regionCode: "US", regionName: "United States"),
            VisitedPlace(regionType: .country, regionCode: "JP", regionName: "Japan"),
            VisitedPlace(regionType: .usState, regionCode: "CA", regionName: "California"),
            VisitedPlace(regionType: .usState, regionCode: "NY", regionName: "New York"),
        ]
        return ScratchPosterModel(places: places, trackedCountries: ["US"], title: "Scratch Test")
    }

    func testPDFIsOneLandscapePageWithHeadlineStats() throws {
        try XCTSkipIf(GeoJSONParser.parseCountries().isEmpty, "Country boundaries not bundled")
        let model = samplePoster()
        let data = try XCTUnwrap(ScratchPosterRenderer.pdfData(model: model, scheme: .light, size: .a3))

        let document = try XCTUnwrap(PDFDocument(data: data))
        XCTAssertEqual(document.pageCount, 1)
        let page = try XCTUnwrap(document.page(at: 0))
        XCTAssertEqual(page.bounds(for: .mediaBox).size, PosterSize.a3.landscapeSize)

        let text = try XCTUnwrap(page.string)
        XCTAssertTrue(text.contains("Scratch Test"))
        for stat in model.headline {
            XCTAssertTrue(text.contains(stat.label), "PDF is missing headline \(stat.label)")
            XCTAssertTrue(text.contains(stat.value), "PDF is missing value \(stat.value)")
        }
        for line in model.coverage {
            XCTAssertTrue(text.contains(line.countryName), "PDF is missing coverage for \(line.countryName)")
        }
    }

    func testPNGIsPrintResolution() throws {
        try XCTSkipIf(GeoJSONParser.parseCountries().isEmpty, "Country boundaries not bundled")
        let data = try XCTUnwrap(ScratchPosterRenderer.pngData(model: samplePoster(), scheme: .dark, size: .a3))

        let source = try XCTUnwrap(CGImageSourceCreateWithData(data as CFData, nil))
        XCTAssertEqual(CGImageSourceGetType(source) as String?, "public.png")
        let properties = try XCTUnwrap(CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any])
        XCTAssertEqual(properties[kCGImagePropertyPixelWidth] as? Int, 4963)
        XCTAssertEqual(properties[kCGImagePropertyPixelHeight] as? Int, 3508)
        XCTAssertEqual((properties[kCGImagePropertyDPIWidth] as? NSNumber)?.doubleValue ?? 0, 300, accuracy: 0.5)
    }

    func testPreviewMatchesPaperAspect() throws {
        try XCTSkipIf(GeoJSONParser.parseCountries().isEmpty, "Country boundaries not bundled")
        let image = try XCTUnwrap(
            ScratchPosterRenderer.previewImage(model: samplePoster(), scheme: .classic, size: .a2, width: 800)
        )
        let page = PosterSize.a2.landscapeSize
        XCTAssertEqual(image.size.width, 800)
        XCTAssertEqual(image.size.height, (800 * page.height / page.width).rounded())
    }
}
