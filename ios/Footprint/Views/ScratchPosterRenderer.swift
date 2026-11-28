import ImageIO
import MapKit
import UIKit
import UniformTypeIdentifiers

/// Draws the scratch-map poster: land under metallic foil, visited places scratched off to reveal
/// colour, on a Robinson world map with a title cartouche and continent tallies. Vector PDF for
/// print, or a bitmap for previews and image export.
enum ScratchPosterRenderer {
    static func renderPDF(_ content: ScratchPosterContent, theme: ScratchPosterTheme, size: ScratchPosterSize) -> Data {
        let page = CGRect(origin: .zero, size: size.pointSize)
        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = [
            kCGPDFContextTitle as String: content.title,
            kCGPDFContextCreator as String: "Footprint",
        ]
        return UIGraphicsPDFRenderer(bounds: page, format: format).pdfData { context in
            context.beginPage()
            draw(content, theme: theme, pageSize: page.size, in: context.cgContext)
        }
    }

    /// The poster at `pixelWidth` pixels wide (height follows the paper's proportions).
    static func renderImage(_ content: ScratchPosterContent, theme: ScratchPosterTheme, size: ScratchPosterSize,
                            pixelWidth: CGFloat) -> UIImage {
        let page = size.pointSize
        let scale = pixelWidth / page.width
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let pixels = CGSize(width: pixelWidth.rounded(), height: (page.height * scale).rounded())
        return UIGraphicsImageRenderer(size: pixels, format: format).image { context in
            context.cgContext.scaleBy(x: scale, y: scale)
            draw(content, theme: theme, pageSize: page, in: context.cgContext)
        }
    }

    /// PNG with its print resolution embedded, so print apps size it to the chosen paper.
    static func pngData(_ image: UIImage, dpi: Int) -> Data? {
        guard let cgImage = image.cgImage else { return nil }
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil) else {
            return nil
        }
        let properties = [kCGImagePropertyDPIWidth: dpi, kCGImagePropertyDPIHeight: dpi] as CFDictionary
        CGImageDestinationAddImage(destination, cgImage, properties)
        return CGImageDestinationFinalize(destination) ? data as Data : nil
    }

    // MARK: - Geometry

    struct RegionShape: Sendable {
        let code: String
        /// Each polygon's exterior ring, then its holes, as (latitude, longitude).
        let polygons: [[[SIMD2<Double>]]]
    }

    private final class GeometryCache: @unchecked Sendable {
        private let lock = NSLock()
        private var countries: [RegionShape]?
        private var states: [String: [RegionShape]] = [:]

        func countryShapes() -> [RegionShape] {
            lock.lock(); defer { lock.unlock() }
            if let countries { return countries }
            let shapes = GeoJSONParser.parseCountries().map {
                RegionShape(code: $0.id == "CN-TW" ? "TW" : $0.id, polygons: $0.polygons.map(ScratchPosterRenderer.rings))
            }
            countries = shapes
            return shapes
        }

        func stateShapes(for country: String) -> [RegionShape] {
            lock.lock(); defer { lock.unlock() }
            if let cached = states[country] { return cached }
            let shapes = GeoJSONParser.parseStates(forCountry: country).map {
                RegionShape(code: "\(country)-\(SubdivisionCode.short($0.id))", polygons: $0.polygons.map(ScratchPosterRenderer.rings))
            }
            states[country] = shapes
            return shapes
        }
    }

    private static let geometry = GeometryCache()

    private static func rings(_ polygon: MKPolygon) -> [[SIMD2<Double>]] {
        func ring(_ p: MKPolygon) -> [SIMD2<Double>] {
            UnsafeBufferPointer(start: p.points(), count: p.pointCount).map {
                let c = $0.coordinate
                return SIMD2(c.latitude, c.longitude)
            }
        }
        return [ring(polygon)] + (polygon.interiorPolygons ?? []).map(ring)
    }

    /// Foil-covered and revealed shapes: a country with visited US/Canadian states is split into
    /// its states so only those are scratched. The country itself stays in the foil underneath, so
    /// land its state boundaries leave out (e.g. the western Aleutians) still shows.
    static func partition(_ content: ScratchPosterContent) -> (foil: [RegionShape], revealed: [RegionShape]) {
        var foil: [RegionShape] = [], revealed: [RegionShape] = []
        let byState = Set(content.visitedStateCodes.compactMap { $0.split(separator: "-").first.map(String.init) })
        for country in geometry.countryShapes() {
            let states = byState.contains(country.code) ? geometry.stateShapes(for: country.code) : []
            if states.isEmpty {
                if content.visitedCountryCodes.contains(country.code) { revealed.append(country) } else { foil.append(country) }
            } else {
                foil.append(country)
                for state in states {
                    if content.visitedStateCodes.contains(state.code) { revealed.append(state) } else { foil.append(state) }
                }
            }
        }
        return (foil, revealed)
    }

    // MARK: - Drawing

    private static func color(_ rgb: ScratchPosterTheme.RGB, _ alpha: CGFloat = 1) -> CGColor {
        CGColor(red: rgb.r, green: rgb.g, blue: rgb.b, alpha: alpha)
    }

    private static func uiColor(_ rgb: ScratchPosterTheme.RGB, _ alpha: CGFloat = 1) -> UIColor {
        UIColor(red: rgb.r, green: rgb.g, blue: rgb.b, alpha: alpha)
    }

    /// Exteriors wound one way and holes the other, so a nonzero fill unions overlapping shapes
    /// (neighbours whose outlines overlap slightly) while keeping holes (enclaves) open.
    private static func path(_ shapes: [RegionShape], _ layout: ScratchPosterLayout) -> CGPath {
        let path = CGMutablePath()
        for shape in shapes {
            for polygon in shape.polygons {
                for (index, ring) in polygon.enumerated() where ring.count > 2 {
                    var points = ring.map { layout.point(latitude: $0.x, longitude: $0.y) }
                    if (signedArea(points) > 0) != (index == 0) { points.reverse() }
                    path.addLines(between: points)
                    path.closeSubpath()
                }
            }
        }
        return path
    }

    private static func signedArea(_ points: [CGPoint]) -> CGFloat {
        var area: CGFloat = 0
        for i in points.indices {
            let a = points[i], b = points[(i + 1) % points.count]
            area += a.x * b.y - b.x * a.y
        }
        return area / 2
    }

    static func draw(_ content: ScratchPosterContent, theme: ScratchPosterTheme, pageSize: CGSize, in ctx: CGContext) {
        let layout = ScratchPosterLayout(pageSize: pageSize, includeAntarctica: content.visitedCountryCodes.contains("AQ"))
        let unit = pageSize.width / 1000
        let foilTones = theme.foil

        ctx.setFillColor(color(theme.frame))
        ctx.fill(CGRect(origin: .zero, size: pageSize))
        drawFrame(ctx, pageSize: pageSize, unit: unit, theme: theme)

        // Ocean inside the Robinson outline, with a faint graticule.
        let outline = mapOutline(layout)
        ctx.saveGState()
        ctx.addPath(outline)
        ctx.clip()
        ctx.setFillColor(color(theme.ocean))
        ctx.fill(layout.mapRect)
        drawGraticule(ctx, layout: layout, unit: unit)

        let (foil, revealed) = partition(content)

        // The foil: a metallic sweep with fine brushed lines.
        let foilPath = path(foil, layout)
        ctx.saveGState()
        ctx.addPath(foilPath)
        ctx.clip()
        let sweep = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                               colors: [color(foilTones.light), color(foilTones.mid), color(foilTones.dark),
                                        color(foilTones.mid), color(foilTones.light), color(foilTones.mid)] as CFArray,
                               locations: [0, 0.22, 0.45, 0.62, 0.8, 1])!
        ctx.drawLinearGradient(sweep, start: CGPoint(x: layout.mapRect.minX, y: layout.mapRect.minY),
                               end: CGPoint(x: layout.mapRect.maxX, y: layout.mapRect.maxY), options: [])
        ctx.setStrokeColor(color(foilTones.light, 0.28))
        ctx.setLineWidth(unit * 0.35)
        let spacing = unit * 2.2
        var x = layout.mapRect.minX - layout.mapRect.height
        while x < layout.mapRect.maxX {
            ctx.move(to: CGPoint(x: x, y: layout.mapRect.maxY))
            ctx.addLine(to: CGPoint(x: x + layout.mapRect.height, y: layout.mapRect.minY))
            x += spacing
        }
        ctx.strokePath()
        ctx.restoreGState()

        ctx.addPath(foilPath)
        ctx.setStrokeColor(color(foilTones.dark, 0.7))
        ctx.setLineWidth(unit * 0.4)
        ctx.strokePath()

        // Scratched-off places on top of the foil, keeping their holes (an unvisited enclave stays foil).
        for shape in revealed {
            ctx.addPath(path([shape], layout))
            ctx.setFillColor(color(ScratchPosterTheme.revealColor(for: shape.code)))
            ctx.fillPath()
        }

        // Scratched edges: white borders with flecks of foil left along them.
        for shape in revealed {
            let shapePath = path([shape], layout)
            ctx.addPath(shapePath)
            ctx.setStrokeColor(UIColor.white.withAlphaComponent(0.75).cgColor)
            ctx.setLineWidth(unit * 0.45)
            ctx.strokePath()
            ctx.saveGState()
            ctx.addPath(shapePath)
            ctx.setStrokeColor(color(foilTones.light, 0.9))
            ctx.setLineWidth(unit * 1.1)
            ctx.setLineDash(phase: 0, lengths: [unit * 1.2, unit * 3.4])
            ctx.strokePath()
            ctx.restoreGState()
        }
        drawCompass(ctx, center: CGPoint(x: layout.mapRect.minX + layout.mapRect.width * 0.1,
                                         y: layout.mapRect.maxY - layout.mapRect.height * 0.2),
                    radius: unit * 26, theme: theme)
        ctx.restoreGState()

        ctx.addPath(outline)
        ctx.setStrokeColor(color(foilTones.mid))
        ctx.setLineWidth(unit * 1.4)
        ctx.strokePath()

        UIGraphicsPushContext(ctx)
        drawTitle(content, layout: layout, unit: unit, theme: theme)
        drawFooter(content, layout: layout, unit: unit, theme: theme)
        UIGraphicsPopContext()
    }

    private static func mapOutline(_ layout: ScratchPosterLayout) -> CGPath {
        let path = CGMutablePath()
        let top = layout.latitudeRange.upperBound, bottom = layout.latitudeRange.lowerBound
        path.move(to: layout.point(latitude: top, longitude: -180))
        for lat in stride(from: top, through: bottom, by: -2) { path.addLine(to: layout.point(latitude: lat, longitude: -180)) }
        path.addLine(to: layout.point(latitude: bottom, longitude: 180))
        for lat in stride(from: bottom, through: top, by: 2) { path.addLine(to: layout.point(latitude: lat, longitude: 180)) }
        path.closeSubpath()
        return path
    }

    private static func drawGraticule(_ ctx: CGContext, layout: ScratchPosterLayout, unit: CGFloat) {
        ctx.setStrokeColor(UIColor.white.withAlphaComponent(0.09).cgColor)
        ctx.setLineWidth(unit * 0.3)
        for lon in stride(from: -150.0, through: 150, by: 30) {
            ctx.move(to: layout.point(latitude: layout.latitudeRange.upperBound, longitude: lon))
            for lat in stride(from: layout.latitudeRange.upperBound, through: layout.latitudeRange.lowerBound, by: -2) {
                ctx.addLine(to: layout.point(latitude: lat, longitude: lon))
            }
        }
        for lat in stride(from: -40.0, through: 80, by: 20) {
            ctx.move(to: layout.point(latitude: lat, longitude: -180))
            ctx.addLine(to: layout.point(latitude: lat, longitude: 180))
        }
        ctx.strokePath()
    }

    private static func drawFrame(_ ctx: CGContext, pageSize: CGSize, unit: CGFloat, theme: ScratchPosterTheme) {
        let outer = CGRect(origin: .zero, size: pageSize).insetBy(dx: unit * 12, dy: unit * 12)
        ctx.setStrokeColor(color(theme.foil.mid))
        ctx.setLineWidth(unit * 1.6)
        ctx.stroke(outer)
        ctx.setLineWidth(unit * 0.5)
        ctx.stroke(outer.insetBy(dx: unit * 4, dy: unit * 4))
    }

    private static func drawCompass(_ ctx: CGContext, center: CGPoint, radius: CGFloat, theme: ScratchPosterTheme) {
        let tones = theme.foil
        ctx.setStrokeColor(color(tones.mid, 0.8))
        ctx.setLineWidth(radius * 0.03)
        ctx.strokeEllipse(in: CGRect(x: center.x - radius * 0.72, y: center.y - radius * 0.72,
                                     width: radius * 1.44, height: radius * 1.44))
        for i in 0..<8 {
            let angle = CGFloat(i) * .pi / 4 - .pi / 2
            let length = i.isMultiple(of: 2) ? radius : radius * 0.55
            let tip = CGPoint(x: center.x + cos(angle) * length, y: center.y + sin(angle) * length)
            let side = radius * (i.isMultiple(of: 2) ? 0.16 : 0.1)
            for (sign, tone) in [(CGFloat(1), tones.light), (-1, tones.dark)] {
                ctx.move(to: center)
                ctx.addLine(to: tip)
                ctx.addLine(to: CGPoint(x: center.x + cos(angle + sign * .pi / 2) * side,
                                        y: center.y + sin(angle + sign * .pi / 2) * side))
                ctx.closePath()
                ctx.setFillColor(color(tone))
                ctx.fillPath()
            }
        }
        let font = UIFont.systemFont(ofSize: radius * 0.32, weight: .bold)
        let north = NSAttributedString(string: "N", attributes: [.font: font, .foregroundColor: uiColor(tones.light)])
        UIGraphicsPushContext(ctx)
        north.draw(at: CGPoint(x: center.x - north.size().width / 2, y: center.y - radius - north.size().height * 1.05))
        UIGraphicsPopContext()
    }

    private static func serif(_ size: CGFloat, _ weight: UIFont.Weight) -> UIFont {
        let base = UIFont.systemFont(ofSize: size, weight: weight)
        return base.fontDescriptor.withDesign(.serif).map { UIFont(descriptor: $0, size: size) } ?? base
    }

    private static func drawCentered(_ text: String, font: UIFont, color: UIColor, kern: CGFloat = 0,
                                     centerX: CGFloat, top: CGFloat, maxWidth: CGFloat) -> CGFloat {
        let style = NSMutableParagraphStyle()
        style.alignment = .center
        style.lineBreakMode = .byTruncatingTail
        let string = NSAttributedString(string: text, attributes: [.font: font, .foregroundColor: color, .kern: kern,
                                                                   .paragraphStyle: style])
        let height = ceil(font.lineHeight)
        string.draw(in: CGRect(x: centerX - maxWidth / 2, y: top, width: maxWidth, height: height))
        return height
    }

    private static func drawTitle(_ content: ScratchPosterContent, layout: ScratchPosterLayout, unit: CGFloat,
                                  theme: ScratchPosterTheme) {
        let rect = layout.titleRect
        let titleFont = serif(rect.height * 0.46, .bold)
        let subtitleFont = UIFont.systemFont(ofSize: rect.height * 0.17, weight: .medium)
        var y = rect.minY + rect.height * 0.08
        y += drawCentered(content.title.uppercased(), font: titleFont, color: uiColor(theme.foil.light), kern: unit * 3,
                          centerX: rect.midX, top: y, maxWidth: rect.width * 0.8)
        _ = drawCentered(content.summary, font: subtitleFont, color: uiColor(theme.foil.mid), kern: unit * 0.6,
                         centerX: rect.midX, top: y + rect.height * 0.02, maxWidth: rect.width * 0.8)
    }

    private static func drawFooter(_ content: ScratchPosterContent, layout: ScratchPosterLayout, unit: CGFloat,
                                   theme: ScratchPosterTheme) {
        let rect = layout.footerRect
        let tones = theme.foil
        let columns = max(content.continents.count, 1)
        let tallyWidth = rect.width * 0.74
        let column = tallyWidth / CGFloat(columns)
        let nameFont = UIFont.systemFont(ofSize: rect.height * 0.2, weight: .semibold)
        let countFont = UIFont.monospacedDigitSystemFont(ofSize: rect.height * 0.17, weight: .regular)
        for (i, continent) in content.continents.enumerated() {
            let x = rect.minX + CGFloat(i) * column
            let inner = column * 0.86
            _ = drawCentered(continent.name.uppercased(), font: nameFont, color: uiColor(tones.light), kern: unit * 0.5,
                             centerX: x + column / 2, top: rect.minY + rect.height * 0.12, maxWidth: inner)
            let bar = CGRect(x: x + (column - inner) / 2, y: rect.minY + rect.height * 0.5, width: inner, height: rect.height * 0.09)
            let track = UIBezierPath(roundedRect: bar, cornerRadius: bar.height / 2)
            uiColor(tones.dark, 0.45).setFill()
            track.fill()
            let share = continent.total > 0 ? CGFloat(continent.visited) / CGFloat(continent.total) : 0
            if share > 0 {
                let filled = CGRect(x: bar.minX, y: bar.minY, width: max(bar.height, bar.width * share), height: bar.height)
                uiColor(tones.light).setFill()
                UIBezierPath(roundedRect: filled, cornerRadius: bar.height / 2).fill()
            }
            _ = drawCentered("\(continent.visited) / \(continent.total)", font: countFont, color: uiColor(tones.mid),
                             centerX: x + column / 2, top: bar.maxY + rect.height * 0.08, maxWidth: inner)
        }

        let brandX = rect.minX + tallyWidth + (rect.width - tallyWidth) / 2
        let brandWidth = rect.width - tallyWidth
        _ = drawCentered("FOOTPRINT", font: serif(rect.height * 0.26, .bold), color: uiColor(tones.light), kern: unit * 2,
                         centerX: brandX, top: rect.minY + rect.height * 0.18, maxWidth: brandWidth)
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("MMMM yyyy")
        _ = drawCentered("Scratched as of \(formatter.string(from: content.date))",
                         font: UIFont.systemFont(ofSize: rect.height * 0.16, weight: .regular), color: uiColor(tones.mid),
                         centerX: brandX, top: rect.minY + rect.height * 0.56, maxWidth: brandWidth)
    }
}
