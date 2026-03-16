import MapKit
import SwiftUI
import UIKit

// MARK: - Enums

enum PosterDisplayMode: String, CaseIterable, Identifiable {
    case live, highlighted, scratched, pins, passport
    var id: String { rawValue }
    var label: String {
        switch self { case .live: return "Live"; case .highlighted: return "Highlight"; case .scratched: return "Scratch"; case .pins: return "Pins"; case .passport: return "Stamps" }
    }
    var icon: String {
        switch self { case .live: return "map.fill"; case .highlighted: return "paintbrush.fill"; case .scratched: return "hand.draw.fill"; case .pins: return "mappin.and.ellipse"; case .passport: return "seal.fill" }
    }
    var isRendered: Bool { self != .live }
}

enum PosterLabelMode: String, CaseIterable, Identifiable {
    case none, onMap, list
    var id: String { rawValue }
    var label: String {
        switch self { case .none: return "None"; case .onMap: return "On Map"; case .list: return "List" }
    }
    var icon: String {
        switch self { case .none: return "text.badge.xmark"; case .onMap: return "character.textbox"; case .list: return "list.bullet" }
    }
}

enum PosterRegion: String, CaseIterable, Identifiable {
    case world, europe, northAmerica, usStates, asia, africa, southAmerica, oceania
    var id: String { rawValue }
    var label: String {
        switch self {
        case .world: return "World"; case .europe: return "Europe"; case .northAmerica: return "N. America"
        case .usStates: return "US States"; case .asia: return "Asia"; case .africa: return "Africa"
        case .southAmerica: return "S. America"; case .oceania: return "Oceania"
        }
    }
    /// Lat/lon bounds: (centerLat, centerLon, latSpan, lonSpan)
    var bounds: (Double, Double, Double, Double) {
        switch self {
        case .world: return (15, 10, 140, 360)
        case .europe: return (50, 15, 35, 55)
        case .northAmerica: return (45, -100, 50, 80)
        case .usStates: return (39, -98, 28, 62)
        case .asia: return (35, 90, 60, 110)
        case .africa: return (0, 22, 65, 70)
        case .southAmerica: return (-15, -58, 55, 50)
        case .oceania: return (-25, 145, 40, 65)
        }
    }
}

// MARK: - Poster View

struct WorldMapExportView: View {
    let visitedCountryCodes: Set<String>
    let bucketListCountryCodes: Set<String>
    let visitedStateCodes: Set<String>
    let bucketListStateCodes: Set<String>
    let visitedPlaces: [VisitedPlace]

    @Environment(\.dismiss) private var dismiss
    @State private var displayMode: PosterDisplayMode = .live
    @State private var labelMode: PosterLabelMode = .none
    @State private var colorScheme: PosterColorScheme = .dark
    @State private var region: PosterRegion = .world
    @State private var renderedImage: UIImage?
    @State private var isRendering = false
    @State private var showShareSheet = false
    @State private var showFullScreen = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    posterPreview.padding(.horizontal)
                        .onTapGesture { if displayMode.isRendered { showFullScreen = true } }

                    pickerSection("Style") {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) { ForEach(PosterDisplayMode.allCases) { modeButton($0) } }
                        }
                    }

                    pickerSection("Region") {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) { ForEach(PosterRegion.allCases) { regionButton($0) } }
                        }
                    }

                    if displayMode.isRendered {
                        pickerSection("Labels") {
                            HStack(spacing: 10) { ForEach(PosterLabelMode.allCases) { labelButton($0) } }
                        }
                        pickerSection("Theme") {
                            HStack(spacing: 10) { ForEach(PosterColorScheme.allCases) { schemeButton($0) } }
                        }
                        Button { shareImage() } label: {
                            Label("Share Poster", systemImage: "square.and.arrow.up")
                                .font(.headline).frame(maxWidth: .infinity).padding()
                                .background(.blue).foregroundStyle(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }.padding(.horizontal).disabled(isRendering)
                    }
                }
                .padding(.vertical)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Poster").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } }
                if displayMode.isRendered {
                    ToolbarItem(placement: .primaryAction) {
                        Button { showFullScreen = true } label: { Image(systemName: "arrow.up.left.and.arrow.down.right") }
                    }
                }
            }
            .sheet(isPresented: $showShareSheet) { if let image = renderedImage { ActivityViewController(activityItems: [image]) } }
            .fullScreenCover(isPresented: $showFullScreen) { PosterFullScreenView(image: renderedImage) }
            .task { if displayMode.isRendered { renderPreview() } }
            .onChange(of: displayMode) { if displayMode.isRendered { renderPreview() } }
            .onChange(of: colorScheme) { if displayMode.isRendered { renderPreview() } }
            .onChange(of: labelMode) { if displayMode.isRendered { renderPreview() } }
            .onChange(of: region) { if displayMode.isRendered { renderPreview() } }
        }
    }

    private func pickerSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.subheadline).foregroundStyle(.secondary).padding(.horizontal)
            content().padding(.horizontal)
        }
    }

    @ViewBuilder
    private var posterPreview: some View {
        if displayMode == .live {
            liveMapView
                .frame(height: 400)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .shadow(color: .black.opacity(0.15), radius: 6, y: 3)
        } else if let image = renderedImage {
            Image(uiImage: image).resizable().aspectRatio(contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .shadow(color: .black.opacity(0.15), radius: 6, y: 3)
                .overlay(alignment: .bottomTrailing) {
                    Image(systemName: "arrow.up.left.and.arrow.down.right").font(.caption)
                        .padding(6).background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 6)).padding(8)
                }
        } else {
            RoundedRectangle(cornerRadius: 12).fill(Color(colorScheme.backgroundColor))
                .aspectRatio(1.8, contentMode: .fit).overlay { ProgressView() }
        }
    }

    private var liveMapView: some View {
        CountryMapView(
            visitedCountryCodes: visitedCountryCodes,
            bucketListCountryCodes: bucketListCountryCodes,
            visitedStateCodes: visitedStateCodes,
            bucketListStateCodes: bucketListStateCodes,
            selectedCountry: .constant(nil),
            centerOnUserLocation: .constant(false)
        )
    }

    // MARK: - Buttons

    private func modeButton(_ mode: PosterDisplayMode) -> some View {
        Button { displayMode = mode } label: {
            VStack(spacing: 4) {
                Image(systemName: mode.icon).font(.title3)
                Text(mode.label).font(.caption2).fontWeight(.medium)
            }
            .frame(width: 60).padding(.vertical, 10)
            .background(displayMode == mode ? Color.blue.opacity(0.15) : Color(.secondarySystemGroupedBackground))
            .foregroundStyle(displayMode == mode ? .blue : .primary)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(displayMode == mode ? Color.blue : .clear, lineWidth: 2))
        }
    }

    private func regionButton(_ r: PosterRegion) -> some View {
        Button { region = r } label: {
            Text(r.label).font(.caption).fontWeight(.medium)
                .padding(.horizontal, 12).padding(.vertical, 8)
                .background(region == r ? Color.blue.opacity(0.15) : Color(.secondarySystemGroupedBackground))
                .foregroundStyle(region == r ? .blue : .primary)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(region == r ? Color.blue : .clear, lineWidth: 2))
        }
    }

    private func labelButton(_ mode: PosterLabelMode) -> some View {
        Button { labelMode = mode } label: {
            VStack(spacing: 4) {
                Image(systemName: mode.icon).font(.title3)
                Text(mode.label).font(.caption2).fontWeight(.medium)
            }
            .frame(maxWidth: .infinity).padding(.vertical, 10)
            .background(labelMode == mode ? Color.blue.opacity(0.15) : Color(.secondarySystemGroupedBackground))
            .foregroundStyle(labelMode == mode ? .blue : .primary)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(labelMode == mode ? Color.blue : .clear, lineWidth: 2))
        }
    }

    private func schemeButton(_ scheme: PosterColorScheme) -> some View {
        Button { colorScheme = scheme } label: {
            VStack(spacing: 4) {
                RoundedRectangle(cornerRadius: 6).fill(Color(scheme.backgroundColor)).frame(height: 28)
                    .overlay { HStack(spacing: 2) { Circle().fill(Color(scheme.landColor)).frame(width: 7); Circle().fill(Color(scheme.visitedColor)).frame(width: 7) } }
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color(scheme.borderColor), lineWidth: 1))
                Text(scheme.displayName).font(.caption2).foregroundStyle(.primary)
            }
            .frame(maxWidth: .infinity).padding(4)
            .background(self.colorScheme == scheme ? Color.blue.opacity(0.1) : .clear)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(self.colorScheme == scheme ? Color.blue : .clear, lineWidth: 2))
        }
    }

    private func renderPreview() {
        isRendering = true
        let p = RenderParams(displayMode: displayMode, labelMode: labelMode, colorScheme: colorScheme,
                             visited: visitedCountryCodes, bucketList: bucketListCountryCodes, region: region)
        Task.detached {
            let img = PosterMapRenderer.renderImage(width: 3600, params: p)
            await MainActor.run { renderedImage = img; isRendering = false }
        }
    }

    private func shareImage() {
        isRendering = true
        let p = RenderParams(displayMode: displayMode, labelMode: labelMode, colorScheme: colorScheme,
                             visited: visitedCountryCodes, bucketList: bucketListCountryCodes, region: region)
        Task.detached {
            let img = PosterMapRenderer.renderImage(width: 6000, params: p)
            await MainActor.run { renderedImage = img; isRendering = false; showShareSheet = true }
        }
    }
}

// MARK: - Full Screen

struct PosterFullScreenView: View {
    let image: UIImage?
    @Environment(\.dismiss) private var dismiss
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if let image {
                Image(uiImage: image).resizable().aspectRatio(contentMode: .fit)
                    .scaleEffect(scale).offset(offset)
                    .gesture(
                        MagnifyGesture()
                            .onChanged { scale = lastScale * $0.magnification }
                            .onEnded { _ in lastScale = max(1, scale); scale = lastScale; if lastScale == 1 { offset = .zero; lastOffset = .zero } }
                            .simultaneously(with: DragGesture()
                                .onChanged { guard scale > 1 else { return }; offset = CGSize(width: lastOffset.width + $0.translation.width, height: lastOffset.height + $0.translation.height) }
                                .onEnded { _ in lastOffset = offset })
                    )
                    .onTapGesture(count: 2) {
                        withAnimation(.spring) {
                            if scale > 1 { scale = 1; lastScale = 1; offset = .zero; lastOffset = .zero }
                            else { scale = 3; lastScale = 3 }
                        }
                    }
            }
            VStack { HStack { Spacer(); Button { dismiss() } label: { Image(systemName: "xmark.circle.fill").font(.title).symbolRenderingMode(.hierarchical).foregroundStyle(.white).padding() } }; Spacer() }
        }.statusBarHidden()
    }
}

// MARK: - Render Params

struct RenderParams: Sendable {
    let displayMode: PosterDisplayMode
    let labelMode: PosterLabelMode
    let colorScheme: PosterColorScheme
    let visited: Set<String>
    let bucketList: Set<String>
    let region: PosterRegion
}

// MARK: - Renderer

enum PosterMapRenderer {
    static func renderImage(width: CGFloat, params: RenderParams) -> UIImage {
        // Use the region's natural aspect ratio
        let b = params.region.bounds
        let lonSpan = b.3
        let latSpan = b.2
        // Miller projection vertical scaling
        let aspect = lonSpan / (latSpan * 0.85)
        let mapH = width / CGFloat(max(1.2, min(2.2, aspect)))

        let hasListBelow = params.labelMode == .list
        let listH: CGFloat = hasListBelow ? min(width * 0.2, 300) : 0
        let size = CGSize(width: width, height: mapH + listH)
        let boundaries = GeoJSONParser.parseCountries()
        guard !boundaries.isEmpty else { return UIImage() }

        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            let c = ctx.cgContext; let s = params.colorScheme
            c.setFillColor(s.backgroundColor.cgColor)
            c.fill(CGRect(origin: .zero, size: size))

            let titleH: CGFloat = mapH * 0.06
            let footerH: CGFloat = mapH * 0.04
            let sideM: CGFloat = width * 0.025
            let mapRect = CGRect(x: sideM, y: titleH, width: width - sideM * 2, height: mapH - titleH - footerH)

            // Filter boundaries to region
            let regionBounds = params.region.bounds
            let filtered = filterBoundaries(boundaries, region: params.region)

            switch params.displayMode {
            case .live, .highlighted: drawHighlighted(c, mapRect, filtered, params, regionBounds)
            case .scratched: drawScratched(c, mapRect, filtered, params, regionBounds)
            case .pins: drawPins(c, mapRect, filtered, params, regionBounds)
            case .passport: drawPassport(c, mapRect, filtered, params, regionBounds)
            }

            if params.labelMode == .onMap { drawLabelsOnMap(c, mapRect, filtered, params, regionBounds) }
            drawTitle(c, width, titleH, s, params.visited.count, params.region)
            drawFooter(c, width, mapH, footerH, s)
            if hasListBelow { drawCountryList(c, filtered, params, mapH, width, listH) }
        }
    }

    private static func filterBoundaries(_ bs: [GeoJSONParser.CountryBoundary], region: PosterRegion) -> [GeoJSONParser.CountryBoundary] {
        guard region != .world else { return bs }
        let b = region.bounds
        let latRange = (b.0 - b.2/2)...(b.0 + b.2/2)
        let lonRange = (b.1 - b.3/2)...(b.1 + b.3/2)

        return bs.filter { boundary in
            guard let biggest = boundary.polygons.max(by: { $0.coordinates.count < $1.coordinates.count }) else { return false }
            let coords = biggest.coordinates
            let avgLat = coords.reduce(0.0) { $0 + $1.latitude } / Double(coords.count)
            let avgLon = coords.reduce(0.0) { $0 + $1.longitude } / Double(coords.count)
            return latRange.contains(avgLat) && lonRange.contains(avgLon)
        }
    }

    // MARK: - Projection for region

    private static func projectRegion(_ lat: Double, _ lon: Double, _ r: CGRect, _ b: (Double, Double, Double, Double)) -> CGPoint {
        let centerLat = b.0, centerLon = b.1, latSpan = b.2, lonSpan = b.3
        let x = (lon - (centerLon - lonSpan/2)) / lonSpan
        let latRad = lat * .pi / 180.0
        let millerY = 1.25 * log(tan(.pi / 4.0 + 0.4 * latRad))
        let centerLatRad = centerLat * .pi / 180.0
        let centerMillerY = 1.25 * log(tan(.pi / 4.0 + 0.4 * centerLatRad))
        let topLatRad = (centerLat + latSpan/2) * .pi / 180.0
        let topMillerY = 1.25 * log(tan(.pi / 4.0 + 0.4 * topLatRad))
        let botLatRad = (centerLat - latSpan/2) * .pi / 180.0
        let botMillerY = 1.25 * log(tan(.pi / 4.0 + 0.4 * botLatRad))
        let millerSpan = topMillerY - botMillerY
        let yN = 1.0 - (millerY - botMillerY) / millerSpan

        return CGPoint(x: r.origin.x + max(0, min(1, CGFloat(x))) * r.width,
                       y: r.origin.y + max(0, min(1, CGFloat(yN))) * r.height)
    }

    // MARK: - Highlighted

    private static func drawHighlighted(_ c: CGContext, _ r: CGRect, _ bs: [GeoJSONParser.CountryBoundary],
                                        _ p: RenderParams, _ b: (Double, Double, Double, Double)) {
        for country in bs {
            let fill: UIColor = p.visited.contains(country.id) ? p.colorScheme.visitedColor
                : p.bucketList.contains(country.id) ? .systemOrange : p.colorScheme.landColor
            drawCountry(c, r, country, fill, p.colorScheme.borderColor, 0.5, b)
        }
    }

    // MARK: - Scratched (clean scratch-off, no ugly residue)

    private static func drawScratched(_ c: CGContext, _ r: CGRect, _ bs: [GeoJSONParser.CountryBoundary],
                                      _ p: RenderParams, _ b: (Double, Double, Double, Double)) {
        let scheme = p.colorScheme
        let isSilver = (scheme == .dark || scheme == .ocean)
        let metalBase: UIColor = isSilver
            ? UIColor(red: 0.78, green: 0.79, blue: 0.81, alpha: 1.0)
            : UIColor(red: 0.84, green: 0.76, blue: 0.50, alpha: 1.0)

        // Colorful map underneath
        for country in bs {
            let hue = countryHue(country.id)
            let color = UIColor(hue: hue, saturation: 0.6, brightness: 0.88, alpha: 1.0)
            drawCountry(c, r, country, color, color.withAlphaComponent(0.4), 0.3, b)
        }

        // Metallic overlay on unvisited
        for country in bs where !p.visited.contains(country.id) {
            drawCountry(c, r, country, metalBase, metalBase.withAlphaComponent(0.3), 0.2, b)
        }

        // White edge glow on scratched-off countries
        for country in bs where p.visited.contains(country.id) {
            drawCountry(c, r, country, .clear, UIColor.white.withAlphaComponent(0.5), 1.0, b)
        }
    }

    // MARK: - Pins

    private static func drawPins(_ c: CGContext, _ r: CGRect, _ bs: [GeoJSONParser.CountryBoundary],
                                 _ p: RenderParams, _ b: (Double, Double, Double, Double)) {
        for country in bs { drawCountry(c, r, country, p.colorScheme.landColor, p.colorScheme.borderColor, 0.5, b) }
        let pinR = max(4, r.width * 0.005)
        for country in bs where p.visited.contains(country.id) { drawPin(c, centroid(country, r, b), p.colorScheme.visitedColor, pinR) }
        for country in bs where p.bucketList.contains(country.id) { drawPin(c, centroid(country, r, b), .systemOrange, pinR * 0.7) }
    }

    // MARK: - Passport Stamps (ALL countries, leader lines for small ones)

    private static func drawPassport(_ c: CGContext, _ r: CGRect, _ bs: [GeoJSONParser.CountryBoundary],
                                     _ p: RenderParams, _ b: (Double, Double, Double, Double)) {
        for country in bs { drawCountry(c, r, country, p.colorScheme.landColor, p.colorScheme.borderColor, 0.5, b) }

        let stampColors: [UIColor] = [
            UIColor(red: 0.75, green: 0.12, blue: 0.12, alpha: 0.75),
            UIColor(red: 0.10, green: 0.28, blue: 0.68, alpha: 0.75),
            UIColor(red: 0.12, green: 0.50, blue: 0.12, alpha: 0.75),
            UIColor(red: 0.45, green: 0.10, blue: 0.50, alpha: 0.75),
            UIColor(red: 0.70, green: 0.45, blue: 0.05, alpha: 0.75),
        ]

        UIGraphicsPushContext(c)
        let baseSize = max(12, r.width * 0.02)
        var placedRects: [CGRect] = []

        let sorted = bs.filter { p.visited.contains($0.id) }
            .sorted { countryArea($0, r, b) > countryArea($1, r, b) }

        for country in sorted {
            let center = centroid(country, r, b)
            let h = countryHash(country.id)
            let area = countryArea(country, r, b)
            let sizeScale = min(2.0, max(0.5, sqrt(area) / (r.width * 0.03)))
            let stampSize = baseSize * sizeScale
            let rotation = CGFloat(Int(h >> 4) % 25 - 12) * .pi / 180.0
            let color = stampColors[Int(h % UInt64(stampColors.count))]

            // Try placing at centroid first
            var stampCenter = center
            var stampRect = CGRect(x: stampCenter.x - stampSize, y: stampCenter.y - stampSize,
                                   width: stampSize * 2, height: stampSize * 2)

            // If overlap, try offset positions with leader line
            var needsLeader = false
            if placedRects.contains(where: { $0.intersects(stampRect.insetBy(dx: -1, dy: -1)) }) {
                // Try 8 directions for offset
                let offsets: [(CGFloat, CGFloat)] = [(1.5,0), (-1.5,0), (0,1.5), (0,-1.5), (1.2,1.2), (-1.2,1.2), (1.2,-1.2), (-1.2,-1.2)]
                var placed = false
                for (dx, dy) in offsets {
                    let offset = CGPoint(x: center.x + dx * stampSize, y: center.y + dy * stampSize)
                    let testRect = CGRect(x: offset.x - stampSize, y: offset.y - stampSize,
                                          width: stampSize * 2, height: stampSize * 2)
                    if !placedRects.contains(where: { $0.intersects(testRect.insetBy(dx: -1, dy: -1)) }) && r.contains(offset) {
                        stampCenter = offset
                        stampRect = testRect
                        needsLeader = true
                        placed = true
                        break
                    }
                }
                if !placed { continue } // truly no room
            }

            guard r.contains(stampCenter) else { continue }
            placedRects.append(stampRect)

            // Leader line from country to stamp
            if needsLeader {
                c.setStrokeColor(color.withAlphaComponent(0.4).cgColor)
                c.setLineWidth(max(0.5, stampSize * 0.03))
                c.move(to: center)
                c.addLine(to: stampCenter)
                c.strokePath()
                // Small dot at country
                c.setFillColor(color.cgColor)
                c.fillEllipse(in: CGRect(x: center.x - 2, y: center.y - 2, width: 4, height: 4))
            }

            c.saveGState()
            c.translateBy(x: stampCenter.x, y: stampCenter.y)
            c.rotate(by: rotation)

            let outerRect = CGRect(x: -stampSize, y: -stampSize, width: stampSize * 2, height: stampSize * 2)
            let borderW = max(1.2, stampSize * 0.06)
            c.setStrokeColor(color.cgColor); c.setLineWidth(borderW); c.strokeEllipse(in: outerRect)
            let innerRect = outerRect.insetBy(dx: stampSize * 0.15, dy: stampSize * 0.15)
            c.setLineWidth(borderW * 0.4); c.strokeEllipse(in: innerRect)

            let fontSize = max(4, stampSize * 0.4)
            let font = UIFont.systemFont(ofSize: fontSize, weight: .heavy)
            let code = NSAttributedString(string: country.id, attributes: [.font: font, .foregroundColor: color])
            let codeSize = code.size()
            code.draw(at: CGPoint(x: -codeSize.width / 2, y: -fontSize * 0.2 - codeSize.height / 2))

            let nameFont = UIFont.systemFont(ofSize: max(3, fontSize * 0.35), weight: .medium)
            let name = NSAttributedString(string: country.name.uppercased(), attributes: [.font: nameFont, .foregroundColor: color])
            let nameSize = name.size()
            if nameSize.width < stampSize * 1.6 { name.draw(at: CGPoint(x: -nameSize.width / 2, y: fontSize * 0.25)) }

            c.restoreGState()
        }
        UIGraphicsPopContext()
    }

    // MARK: - Labels (collision avoidance, sized by area)

    private static func drawLabelsOnMap(_ c: CGContext, _ r: CGRect, _ bs: [GeoJSONParser.CountryBoundary],
                                        _ p: RenderParams, _ b: (Double, Double, Double, Double)) {
        UIGraphicsPushContext(c)
        let baseFontSize = max(7, r.width * 0.006)
        var placedRects: [CGRect] = []

        let sorted = bs.filter { p.visited.contains($0.id) }
            .sorted { countryArea($0, r, b) > countryArea($1, r, b) }

        for country in sorted {
            let center = centroid(country, r, b)
            let area = countryArea(country, r, b)
            let sizeScale = min(1.6, max(0.7, sqrt(area) / (r.width * 0.025)))
            let fontSize = baseFontSize * sizeScale
            let font = UIFont.systemFont(ofSize: fontSize, weight: .semibold)
            let str = NSAttributedString(string: country.name, attributes: [.font: font, .foregroundColor: p.colorScheme.textColor.withAlphaComponent(0.9)])
            let strSize = str.size()
            let labelRect = CGRect(x: center.x - strSize.width / 2 - 3, y: center.y - strSize.height / 2 - 2, width: strSize.width + 6, height: strSize.height + 4)
            if placedRects.contains(where: { $0.intersects(labelRect.insetBy(dx: -1, dy: -1)) }) { continue }
            guard r.contains(labelRect) else { continue }
            placedRects.append(labelRect)

            c.setFillColor(p.colorScheme.backgroundColor.withAlphaComponent(0.8).cgColor)
            c.addPath(UIBezierPath(roundedRect: labelRect, cornerRadius: fontSize * 0.3).cgPath); c.fillPath()
            c.setStrokeColor(p.colorScheme.borderColor.withAlphaComponent(0.2).cgColor); c.setLineWidth(0.5)
            c.addPath(UIBezierPath(roundedRect: labelRect, cornerRadius: fontSize * 0.3).cgPath); c.strokePath()
            str.draw(at: CGPoint(x: center.x - strSize.width / 2, y: center.y - strSize.height / 2))
        }
        UIGraphicsPopContext()
    }

    // MARK: - Country List

    private static func drawCountryList(_ c: CGContext, _ bs: [GeoJSONParser.CountryBoundary],
                                        _ p: RenderParams, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) {
        let names = bs.filter { p.visited.contains($0.id) }.map { $0.name }.sorted()
        guard !names.isEmpty else { return }
        UIGraphicsPushContext(c)
        c.setStrokeColor(p.colorScheme.borderColor.withAlphaComponent(0.2).cgColor); c.setLineWidth(0.5)
        c.move(to: CGPoint(x: w * 0.025, y: y + 2)); c.addLine(to: CGPoint(x: w * 0.975, y: y + 2)); c.strokePath()
        let fs: CGFloat = max(7, w * 0.007)
        let lineH = fs * 1.35; let margin = w * 0.025
        let maxPerCol = max(1, Int((h - 8) / lineH))
        let cols = min(5, (names.count + maxPerCol - 1) / maxPerCol)
        let colW = (w - margin * 2) / CGFloat(cols)
        for (i, name) in names.enumerated() {
            let col = i / maxPerCol; let row = i % maxPerCol; if col >= cols { break }
            NSAttributedString(string: name, attributes: [.font: UIFont.systemFont(ofSize: fs), .foregroundColor: p.colorScheme.subtitleColor])
                .draw(at: CGPoint(x: margin + CGFloat(col) * colW, y: y + 6 + CGFloat(row) * lineH))
        }
        UIGraphicsPopContext()
    }

    // MARK: - Drawing Helpers

    private static func drawCountry(_ c: CGContext, _ r: CGRect, _ b: GeoJSONParser.CountryBoundary,
                                    _ fill: UIColor, _ stroke: UIColor, _ lw: CGFloat, _ bounds: (Double, Double, Double, Double)) {
        for polygon in b.polygons {
            let path = countryPath(polygon.coordinates, r, bounds)
            c.addPath(path); c.setFillColor(fill.cgColor); c.setStrokeColor(stroke.cgColor)
            c.setLineWidth(lw); c.drawPath(using: .fillStroke)
        }
    }

    private static func countryPath(_ coords: [CLLocationCoordinate2D], _ r: CGRect, _ b: (Double, Double, Double, Double)) -> CGPath {
        let path = CGMutablePath(); guard coords.count >= 3 else { return path }
        let first = projectRegion(coords[0].latitude, coords[0].longitude, r, b); path.move(to: first)
        for i in 1..<coords.count {
            let pt = projectRegion(coords[i].latitude, coords[i].longitude, r, b)
            let prev = projectRegion(coords[i-1].latitude, coords[i-1].longitude, r, b)
            if abs(pt.x - prev.x) > r.width * 0.4 { path.move(to: pt) } else { path.addLine(to: pt) }
        }
        path.closeSubpath(); return path
    }

    private static func drawPin(_ c: CGContext, _ pt: CGPoint, _ color: UIColor, _ radius: CGFloat) {
        let rect = CGRect(x: pt.x - radius, y: pt.y - radius, width: radius * 2, height: radius * 2)
        c.saveGState()
        c.setShadow(offset: CGSize(width: 0, height: 1), blur: 2, color: UIColor.black.withAlphaComponent(0.3).cgColor)
        c.setFillColor(color.cgColor); c.fillEllipse(in: rect); c.restoreGState()
        c.setStrokeColor(UIColor.white.cgColor); c.setLineWidth(max(1, radius * 0.3)); c.strokeEllipse(in: rect)
    }

    private static func centroid(_ b: GeoJSONParser.CountryBoundary, _ r: CGRect, _ bounds: (Double, Double, Double, Double)) -> CGPoint {
        var best = b.polygons[0]
        for p in b.polygons { if p.coordinates.count > best.coordinates.count { best = p } }
        let coords = best.coordinates
        let lat = coords.reduce(0.0) { $0 + $1.latitude } / Double(coords.count)
        let lon = coords.reduce(0.0) { $0 + $1.longitude } / Double(coords.count)
        return projectRegion(lat, lon, r, bounds)
    }

    private static func countryArea(_ b: GeoJSONParser.CountryBoundary, _ r: CGRect, _ bounds: (Double, Double, Double, Double)) -> CGFloat {
        guard let biggest = b.polygons.max(by: { $0.coordinates.count < $1.coordinates.count }) else { return 0 }
        let box = countryPath(biggest.coordinates, r, bounds).boundingBox
        return box.width * box.height
    }

    private static func countryHue(_ code: String) -> CGFloat { CGFloat(countryHash(code) % 360) / 360.0 }
    private static func countryHash(_ code: String) -> UInt64 {
        var h: UInt64 = 5381; for ch in code.utf8 { h = ((h << 5) &+ h) &+ UInt64(ch) }; return h
    }

    // MARK: - Title & Footer

    private static func drawTitle(_ c: CGContext, _ w: CGFloat, _ h: CGFloat, _ s: PosterColorScheme, _ count: Int, _ region: PosterRegion) {
        UIGraphicsPushContext(c)
        let titleFont = UIFont.systemFont(ofSize: h * 0.45, weight: .bold)
        let title = NSAttributedString(string: "My Footprint", attributes: [.font: titleFont, .foregroundColor: s.textColor])
        title.draw(at: CGPoint(x: w * 0.025, y: (h - title.size().height) / 2))

        let detail = region == .world ? "\(count) countries" : "\(region.label) · \(count) countries"
        let detailFont = UIFont.systemFont(ofSize: h * 0.3, weight: .medium)
        let detailStr = NSAttributedString(string: detail, attributes: [.font: detailFont, .foregroundColor: s.subtitleColor])
        let ds = detailStr.size()
        detailStr.draw(at: CGPoint(x: w - ds.width - w * 0.025, y: (h - ds.height) / 2))
        UIGraphicsPopContext()
    }

    private static func drawFooter(_ c: CGContext, _ w: CGFloat, _ mh: CGFloat, _ fh: CGFloat, _ s: PosterColorScheme) {
        UIGraphicsPushContext(c)
        let brand = NSAttributedString(string: "Made with Footprint",
                                       attributes: [.font: UIFont.systemFont(ofSize: fh * 0.4), .foregroundColor: s.subtitleColor.withAlphaComponent(0.4)])
        let bs = brand.size()
        brand.draw(at: CGPoint(x: (w - bs.width) / 2, y: mh - fh + (fh - bs.height) / 2))
        UIGraphicsPopContext()
    }
}

// MKPolygon.coordinates extension is in PosterGeneratorView.swift
