import CoreGraphics
import ImageIO
import MapKit
import UIKit
import UniformTypeIdentifiers

// MARK: - Geometry

/// A country or subdivision outline as plain coordinates. Holes are kept apart from outer rings
/// so paths can be wound consistently and filled non-zero: outlines that overlap neighbours
/// (or each other) stay filled, while holes still cut out.
struct PosterShape: Sendable {
    struct Coordinate: Sendable {
        let latitude: Double
        let longitude: Double
    }

    struct Ring: Sendable {
        let coordinates: [Coordinate]
        let isHole: Bool
    }

    let code: String
    let rings: [Ring]

    init(code: String, polygons: [MKPolygon]) {
        self.code = code
        func ring(_ polygon: MKPolygon, isHole: Bool) -> Ring {
            Ring(
                coordinates: polygon.coordinates.map { Coordinate(latitude: $0.latitude, longitude: $0.longitude) },
                isHole: isHole
            )
        }
        var rings: [Ring] = []
        for polygon in polygons {
            rings.append(ring(polygon, isHole: false))
            for hole in polygon.interiorPolygons ?? [] {
                rings.append(ring(hole, isHole: true))
            }
        }
        self.rings = rings.filter { $0.coordinates.count >= 3 }
    }
}

/// Parsed boundaries for the poster, loaded once and shared by preview and export renders.
final class ScratchPosterGeometry: @unchecked Sendable {
    static let shared = ScratchPosterGeometry()

    private let lock = NSLock()
    private var countries: [PosterShape]?
    private var subdivisions: [String: [PosterShape]] = [:]

    func countryShapes() -> [PosterShape] {
        lock.lock()
        defer { lock.unlock() }
        if let countries { return countries }
        let shapes = GeoJSONParser.parseCountries()
            .filter { $0.id != "AQ" }
            .map { PosterShape(code: $0.id, polygons: $0.polygons) }
        if !shapes.isEmpty { countries = shapes }
        return shapes
    }

    func subdivisionShapes(for countryCode: String) -> [PosterShape] {
        lock.lock()
        defer { lock.unlock() }
        if let cached = subdivisions[countryCode] { return cached }
        let shapes = GeoJSONParser.parseStates(forCountry: countryCode)
            .map { PosterShape(code: $0.id, polygons: $0.polygons) }
        subdivisions[countryCode] = shapes
        return shapes
    }
}

// MARK: - Renderer

/// Draws the scratch-map poster: visited places filled in the app's green, everything else
/// under a gold or silver scratch-off foil, with the headline stats below the map.
enum ScratchPosterRenderer {
    /// Vector PDF at the paper size (points).
    static func pdfData(
        model: ScratchPosterModel,
        scheme: PosterColorScheme,
        size: PosterSize,
        date: Date = Date()
    ) -> Data? {
        let pageSize = size.landscapeSize
        let geometry = ScratchPosterGeometry.shared
        guard !geometry.countryShapes().isEmpty else { return nil }

        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = [
            kCGPDFContextTitle as String: model.title,
            kCGPDFContextCreator as String: "Footprint Travel Tracker",
        ]
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(origin: .zero, size: pageSize), format: format)
        return renderer.pdfData { context in
            context.beginPage()
            draw(model: model, scheme: scheme, pageSize: pageSize, date: date, geometry: geometry, in: context.cgContext)
        }
    }

    /// PNG at `size.pngPixelSize` with the print resolution recorded in its metadata.
    static func pngData(
        model: ScratchPosterModel,
        scheme: PosterColorScheme,
        size: PosterSize,
        date: Date = Date()
    ) -> Data? {
        guard let image = image(
            model: model, scheme: scheme, size: size, pixelSize: size.pngPixelSize, date: date
        ), let cgImage = image.cgImage else { return nil }

        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            data, UTType.png.identifier as CFString, 1, nil
        ) else { return nil }
        let properties: [CFString: Any] = [
            kCGImagePropertyDPIWidth: size.pngDPI,
            kCGImagePropertyDPIHeight: size.pngDPI,
        ]
        CGImageDestinationAddImage(destination, cgImage, properties as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return data as Data
    }

    /// On-screen preview, `width` pixels wide.
    static func previewImage(
        model: ScratchPosterModel,
        scheme: PosterColorScheme,
        size: PosterSize,
        width: CGFloat
    ) -> UIImage? {
        let page = size.landscapeSize
        let pixelSize = CGSize(width: width, height: (width * page.height / page.width).rounded())
        return image(model: model, scheme: scheme, size: size, pixelSize: pixelSize, date: Date())
    }

    private static func image(
        model: ScratchPosterModel,
        scheme: PosterColorScheme,
        size: PosterSize,
        pixelSize: CGSize,
        date: Date
    ) -> UIImage? {
        let geometry = ScratchPosterGeometry.shared
        guard !geometry.countryShapes().isEmpty else { return nil }

        let pageSize = size.landscapeSize
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: pixelSize, format: format)
        return renderer.image { context in
            let cgContext = context.cgContext
            cgContext.scaleBy(x: pixelSize.width / pageSize.width, y: pixelSize.height / pageSize.height)
            draw(model: model, scheme: scheme, pageSize: pageSize, date: date, geometry: geometry, in: cgContext)
        }
    }

    // MARK: - Page

    private static func draw(
        model: ScratchPosterModel,
        scheme: PosterColorScheme,
        pageSize: CGSize,
        date: Date,
        geometry: ScratchPosterGeometry,
        in context: CGContext
    ) {
        let layout = ScratchPosterLayout(pageSize: pageSize)
        let foil = Foil(scheme: scheme)

        context.setFillColor(scheme.backgroundColor.cgColor)
        context.fill(layout.page)

        drawGraticule(in: context, map: layout.map, scheme: scheme)
        drawMap(model: model, geometry: geometry, foil: foil, map: layout.map, in: context)

        UIGraphicsPushContext(context)
        drawTitle(model: model, scheme: scheme, rect: layout.title)
        drawStats(model: model, scheme: scheme, rect: layout.stats, in: context)
        drawFooter(scheme: scheme, rect: layout.footer, date: date)
        UIGraphicsPopContext()
    }

    // MARK: - Map

    /// The app's map colors (`systemGreen`), fixed so renders off the main thread don't
    /// depend on the current trait collection.
    private static var visitedFill: UIColor { UIColor(red: 0.45, green: 0.82, blue: 0.53, alpha: 1) }
    private static var visitedStroke: UIColor { UIColor(red: 0.12, green: 0.55, blue: 0.24, alpha: 1) }
    private static var visitedSubdivisionFill: UIColor { UIColor(red: 0.20, green: 0.78, blue: 0.35, alpha: 1) }

    private static func drawMap(
        model: ScratchPosterModel,
        geometry: ScratchPosterGeometry,
        foil: Foil,
        map: CGRect,
        in context: CGContext
    ) {
        let lineWidth = map.width / 4000
        let countries = geometry.countryShapes()

        context.saveGState()
        context.clip(to: map)

        let unvisited = countries.filter { !model.visitedCountryCodes.contains($0.code) }
        let visited = countries.filter { model.visitedCountryCodes.contains($0.code) }

        drawFoil(foil, over: path(for: unvisited, in: map), map: map, alpha: 1, textured: true, in: context)
        stroke(path(for: unvisited, in: map), color: foil.edge, width: lineWidth, in: context)

        let visitedPath = path(for: visited, in: map)
        fill(visitedPath, color: visitedFill, in: context)
        stroke(visitedPath, color: visitedStroke, width: lineWidth * 1.4, in: context)

        for countryCode in model.subdivisionCountries.sorted() {
            let shapes = geometry.subdivisionShapes(for: countryCode)
            let countryVisited = model.visitedCountryCodes.contains(countryCode)
            let (scratched, covered) = partition(shapes) {
                model.isSubdivisionVisited(countryCode: countryCode, boundaryCode: $0.code)
            }
            if countryVisited {
                // Inside a visited country the subdivisions still to explore keep a thin foil.
                let coveredPath = path(for: covered, in: map)
                drawFoil(foil, over: coveredPath, map: map, alpha: 0.55, textured: false, in: context)
                stroke(coveredPath, color: foil.edge.withAlphaComponent(0.8), width: lineWidth * 0.7, in: context)
            }
            let scratchedPath = path(for: scratched, in: map)
            fill(scratchedPath, color: visitedSubdivisionFill, in: context)
            stroke(scratchedPath, color: UIColor.white.withAlphaComponent(0.75), width: lineWidth * 0.7, in: context)
        }

        context.restoreGState()
    }

    private static func partition(
        _ shapes: [PosterShape], by isScratched: (PosterShape) -> Bool
    ) -> ([PosterShape], [PosterShape]) {
        var scratched: [PosterShape] = []
        var covered: [PosterShape] = []
        for shape in shapes {
            if isScratched(shape) { scratched.append(shape) } else { covered.append(shape) }
        }
        return (scratched, covered)
    }

    /// Outer rings are wound one way and holes the other, so the path fills correctly with
    /// the non-zero rule even where neighbouring outlines overlap.
    private static func path(for shapes: [PosterShape], in map: CGRect) -> CGPath {
        let path = CGMutablePath()
        for shape in shapes {
            for ring in shape.rings {
                let longitudes = ScratchPosterProjection.unwrappedLongitudes(ring.coordinates.map(\.longitude))
                guard let minLon = longitudes.min(), let maxLon = longitudes.max() else { continue }
                var offsets: [Double] = [0]
                if maxLon > 180 { offsets.append(-360) }
                if minLon < -180 { offsets.append(360) }
                for offset in offsets {
                    var points = ring.coordinates.indices.map { index in
                        ScratchPosterProjection.point(
                            latitude: ring.coordinates[index].latitude, longitude: longitudes[index] + offset, in: map
                        )
                    }
                    if (signedArea(points) < 0) != ring.isHole { points.reverse() }
                    path.addLines(between: points)
                    path.closeSubpath()
                }
            }
        }
        return path
    }

    private static func signedArea(_ points: [CGPoint]) -> CGFloat {
        guard var previous = points.last else { return 0 }
        var area: CGFloat = 0
        for point in points {
            area += previous.x * point.y - point.x * previous.y
            previous = point
        }
        return area / 2
    }

    private static func fill(_ path: CGPath, color: UIColor, in context: CGContext) {
        guard !path.isEmpty else { return }
        context.addPath(path)
        context.setFillColor(color.cgColor)
        context.fillPath(using: .winding)
    }

    private static func stroke(_ path: CGPath, color: UIColor, width: CGFloat, in context: CGContext) {
        guard !path.isEmpty else { return }
        context.addPath(path)
        context.setStrokeColor(color.cgColor)
        context.setLineWidth(width)
        context.setLineJoin(.round)
        context.strokePath()
    }

    // MARK: - Scratch-off foil

    private struct Foil {
        let shadow: UIColor
        let base: UIColor
        let highlight: UIColor
        let edge: UIColor

        init(scheme: PosterColorScheme) {
            switch scheme {
            case .dark, .ocean:
                shadow = UIColor(red: 0.50, green: 0.52, blue: 0.56, alpha: 1)
                base = UIColor(red: 0.71, green: 0.72, blue: 0.75, alpha: 1)
                highlight = UIColor(red: 0.91, green: 0.92, blue: 0.94, alpha: 1)
                edge = UIColor(red: 0.42, green: 0.44, blue: 0.48, alpha: 1)
            case .light, .classic:
                shadow = UIColor(red: 0.62, green: 0.49, blue: 0.24, alpha: 1)
                base = UIColor(red: 0.80, green: 0.68, blue: 0.39, alpha: 1)
                highlight = UIColor(red: 0.95, green: 0.88, blue: 0.64, alpha: 1)
                edge = UIColor(red: 0.55, green: 0.43, blue: 0.20, alpha: 1)
            }
        }
    }

    private static func drawFoil(
        _ foil: Foil, over path: CGPath, map: CGRect, alpha: CGFloat, textured: Bool, in context: CGContext
    ) {
        guard !path.isEmpty else { return }
        context.saveGState()
        context.addPath(path)
        context.clip(using: .winding)
        context.setAlpha(alpha)

        let colors = [foil.shadow, foil.highlight, foil.base, foil.highlight, foil.base, foil.shadow]
            .map(\.cgColor) as CFArray
        let locations: [CGFloat] = [0, 0.22, 0.42, 0.6, 0.8, 1]
        if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: locations) {
            context.drawLinearGradient(
                gradient,
                start: CGPoint(x: map.minX, y: map.minY),
                end: CGPoint(x: map.maxX, y: map.maxY),
                options: [.drawsBeforeStartLocation, .drawsAfterEndLocation]
            )
        }

        if textured { drawScratchTexture(in: context, map: map) }
        context.restoreGState()
    }

    /// Short diagonal strokes like a brushed scratch-card coating. Seeded, so every export of
    /// the same poster looks identical.
    private static func drawScratchTexture(in context: CGContext, map: CGRect) {
        var seed: UInt64 = 0x9E37_79B9_7F4A_7C15
        func random() -> CGFloat {
            seed = seed &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
            return CGFloat(seed >> 11) / CGFloat(1 << 53)
        }

        let light = CGMutablePath()
        let dark = CGMutablePath()
        let length = map.width * 0.008
        for index in 0..<2400 {
            let start = CGPoint(x: map.minX + random() * map.width, y: map.minY + random() * map.height)
            let angle = -0.55 + (random() - 0.5) * 0.5
            let strokeLength = length * (0.5 + random())
            let end = CGPoint(x: start.x + cos(angle) * strokeLength, y: start.y + sin(angle) * strokeLength)
            let target = index.isMultiple(of: 3) ? dark : light
            target.move(to: start)
            target.addLine(to: end)
        }
        context.setLineCap(.round)
        context.setLineWidth(map.width / 5000)
        context.addPath(light)
        context.setStrokeColor(UIColor.white.withAlphaComponent(0.35).cgColor)
        context.strokePath()
        context.addPath(dark)
        context.setStrokeColor(UIColor.black.withAlphaComponent(0.10).cgColor)
        context.strokePath()
    }

    private static func drawGraticule(in context: CGContext, map: CGRect, scheme: PosterColorScheme) {
        let path = CGMutablePath()
        for longitude in stride(from: -180.0, through: 180.0, by: 30.0) {
            path.move(to: ScratchPosterProjection.point(latitude: ScratchPosterProjection.northLatitude, longitude: longitude, in: map))
            path.addLine(to: ScratchPosterProjection.point(latitude: ScratchPosterProjection.southLatitude, longitude: longitude, in: map))
        }
        for latitude in stride(from: -60.0, through: 80.0, by: 20.0) {
            path.move(to: ScratchPosterProjection.point(latitude: latitude, longitude: -180, in: map))
            path.addLine(to: ScratchPosterProjection.point(latitude: latitude, longitude: 180, in: map))
        }
        stroke(path, color: scheme.subtitleColor.withAlphaComponent(0.18), width: map.width / 6000, in: context)
    }

    // MARK: - Text

    private static func drawTitle(model: ScratchPosterModel, scheme: PosterColorScheme, rect: CGRect) {
        let titleRect = CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: rect.height * 0.66)
        let subtitleRect = CGRect(x: rect.minX, y: titleRect.maxY, width: rect.width, height: rect.height * 0.34)
        drawText(
            model.title, font: .systemFont(ofSize: rect.height * 0.5, weight: .heavy),
            color: scheme.textColor, in: titleRect
        )
        drawText(
            model.subtitle, font: .systemFont(ofSize: rect.height * 0.2, weight: .medium),
            color: scheme.subtitleColor, in: subtitleRect
        )
    }

    private static func drawStats(model: ScratchPosterModel, scheme: PosterColorScheme, rect: CGRect, in context: CGContext) {
        context.setStrokeColor(scheme.subtitleColor.withAlphaComponent(0.35).cgColor)
        context.setLineWidth(rect.height / 200)
        context.move(to: CGPoint(x: rect.minX, y: rect.minY))
        context.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        context.strokePath()

        let headlineHeight = model.coverage.isEmpty ? rect.height : rect.height * 0.62
        let columnWidth = rect.width / CGFloat(max(1, model.headline.count))
        for (index, stat) in model.headline.enumerated() {
            let column = CGRect(
                x: rect.minX + CGFloat(index) * columnWidth, y: rect.minY,
                width: columnWidth, height: headlineHeight
            )
            drawText(
                stat.value, font: .systemFont(ofSize: rect.height * 0.27, weight: .bold),
                color: scheme.textColor,
                in: CGRect(x: column.minX, y: column.minY + column.height * 0.08, width: column.width, height: column.height * 0.6)
            )
            drawText(
                stat.label, font: .systemFont(ofSize: rect.height * 0.09, weight: .medium),
                color: scheme.subtitleColor,
                in: CGRect(x: column.minX, y: column.minY + column.height * 0.66, width: column.width, height: column.height * 0.3)
            )
        }

        guard !model.coverage.isEmpty else { return }
        let columns = 4
        let rows = Int((Double(model.coverage.count) / Double(columns)).rounded(.up))
        let area = CGRect(x: rect.minX, y: rect.minY + headlineHeight, width: rect.width, height: rect.height - headlineHeight)
        let cellWidth = area.width / CGFloat(columns)
        let cellHeight = area.height / CGFloat(max(rows, 2))
        let nameFont = UIFont.systemFont(ofSize: rect.height * 0.075, weight: .semibold)
        let detailFont = UIFont.systemFont(ofSize: rect.height * 0.075, weight: .regular)
        for (index, line) in model.coverage.enumerated() {
            let cell = CGRect(
                x: area.minX + CGFloat(index % columns) * cellWidth,
                y: area.minY + CGFloat(index / columns) * cellHeight,
                width: cellWidth, height: cellHeight
            )
            let text = NSMutableAttributedString(
                string: line.countryName,
                attributes: [.font: nameFont, .foregroundColor: scheme.textColor]
            )
            text.append(NSAttributedString(
                string: "  \(line.countText) · \(line.percentText)",
                attributes: [.font: detailFont, .foregroundColor: scheme.subtitleColor]
            ))
            drawAttributed(text, in: cell)
        }
    }

    private static func drawFooter(scheme: PosterColorScheme, rect: CGRect, date: Date) {
        let font = UIFont.systemFont(ofSize: rect.height * 0.5, weight: .regular)
        let color = scheme.subtitleColor.withAlphaComponent(0.7)
        drawText("Footprint · footprintmaps.com", font: font, color: color, in: rect, alignment: .left)
        drawText(date.formatted(.dateTime.month(.wide).year()), font: font, color: color, in: rect, alignment: .right)
    }

    private static func drawText(
        _ string: String, font: UIFont, color: UIColor, in rect: CGRect, alignment: NSTextAlignment = .center
    ) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = alignment
        paragraph.lineBreakMode = .byTruncatingTail
        drawAttributed(
            NSAttributedString(
                string: string,
                attributes: [.font: font, .foregroundColor: color, .paragraphStyle: paragraph]
            ),
            in: rect
        )
    }

    /// Draws one line vertically centered in `rect`.
    private static func drawAttributed(_ text: NSAttributedString, in rect: CGRect) {
        let mutable = NSMutableAttributedString(attributedString: text)
        if mutable.length > 0, mutable.attribute(.paragraphStyle, at: 0, effectiveRange: nil) == nil {
            let paragraph = NSMutableParagraphStyle()
            paragraph.alignment = .center
            paragraph.lineBreakMode = .byTruncatingTail
            mutable.addAttribute(.paragraphStyle, value: paragraph, range: NSRange(location: 0, length: mutable.length))
        }
        let height = ceil(mutable.size().height)
        let lineRect = CGRect(x: rect.minX, y: rect.midY - height / 2, width: rect.width, height: height)
        mutable.draw(with: lineRect, options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine], context: nil)
    }
}
