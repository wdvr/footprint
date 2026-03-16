import MapKit
import SwiftUI
import UIKit

// MARK: - Display Mode

enum PosterDisplayMode: String, CaseIterable, Identifiable {
    case highlighted
    case scratched
    case pins

    var id: String { rawValue }

    var label: String {
        switch self {
        case .highlighted: return "Highlighted"
        case .scratched: return "Scratched"
        case .pins: return "Pins"
        }
    }

    var icon: String {
        switch self {
        case .highlighted: return "paintbrush.fill"
        case .scratched: return "hand.draw.fill"
        case .pins: return "mappin.and.ellipse"
        }
    }
}

enum PosterLabelMode: String, CaseIterable, Identifiable {
    case none
    case onMap
    case list

    var id: String { rawValue }

    var label: String {
        switch self {
        case .none: return "None"
        case .onMap: return "On Map"
        case .list: return "List"
        }
    }

    var icon: String {
        switch self {
        case .none: return "text.badge.xmark"
        case .onMap: return "character.textbox"
        case .list: return "list.bullet"
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
    @State private var displayMode: PosterDisplayMode = .highlighted
    @State private var labelMode: PosterLabelMode = .none
    @State private var colorScheme: PosterColorScheme = .dark
    @State private var renderedImage: UIImage?
    @State private var isRendering = false
    @State private var showShareSheet = false
    @State private var showFullScreen = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Zoomable preview
                    posterPreview
                        .padding(.horizontal)
                        .onTapGesture {
                            showFullScreen = true
                        }

                    // Mode picker
                    pickerSection("Style") {
                        HStack(spacing: 12) {
                            ForEach(PosterDisplayMode.allCases) { mode in
                                modeButton(mode)
                            }
                        }
                    }

                    // Labels picker
                    pickerSection("Labels") {
                        HStack(spacing: 12) {
                            ForEach(PosterLabelMode.allCases) { mode in
                                labelButton(mode)
                            }
                        }
                    }

                    // Color scheme picker
                    pickerSection("Theme") {
                        HStack(spacing: 12) {
                            ForEach(PosterColorScheme.allCases) { scheme in
                                schemeButton(scheme)
                            }
                        }
                    }

                    // Share button
                    Button {
                        shareImage()
                    } label: {
                        Label("Share Poster", systemImage: "square.and.arrow.up")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(.blue)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .padding(.horizontal)
                    .disabled(isRendering)
                }
                .padding(.vertical)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Poster")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showFullScreen = true
                    } label: {
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                    }
                }
            }
            .sheet(isPresented: $showShareSheet) {
                if let image = renderedImage {
                    ActivityViewController(activityItems: [image])
                }
            }
            .fullScreenCover(isPresented: $showFullScreen) {
                PosterFullScreenView(image: renderedImage)
            }
            .task {
                renderPreview()
            }
            .onChange(of: displayMode) { renderPreview() }
            .onChange(of: colorScheme) { renderPreview() }
            .onChange(of: labelMode) { renderPreview() }
        }
    }

    // MARK: - Subviews

    private func pickerSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
            content()
                .padding(.horizontal)
        }
    }

    @ViewBuilder
    private var posterPreview: some View {
        if let image = renderedImage {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .shadow(color: .black.opacity(0.2), radius: 8, y: 4)
                .overlay(alignment: .bottomTrailing) {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(.caption)
                        .padding(6)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .padding(8)
                }
        } else {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(colorScheme.backgroundColor))
                .aspectRatio(1.6, contentMode: .fit)
                .overlay { ProgressView() }
        }
    }

    private func modeButton(_ mode: PosterDisplayMode) -> some View {
        Button {
            displayMode = mode
        } label: {
            VStack(spacing: 6) {
                Image(systemName: mode.icon).font(.title2)
                Text(mode.label).font(.caption).fontWeight(.medium)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(displayMode == mode ? Color.blue.opacity(0.15) : Color(.secondarySystemGroupedBackground))
            .foregroundStyle(displayMode == mode ? .blue : .primary)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(displayMode == mode ? Color.blue : .clear, lineWidth: 2))
        }
    }

    private func labelButton(_ mode: PosterLabelMode) -> some View {
        Button {
            labelMode = mode
        } label: {
            VStack(spacing: 6) {
                Image(systemName: mode.icon).font(.title2)
                Text(mode.label).font(.caption).fontWeight(.medium)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(labelMode == mode ? Color.blue.opacity(0.15) : Color(.secondarySystemGroupedBackground))
            .foregroundStyle(labelMode == mode ? .blue : .primary)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(labelMode == mode ? Color.blue : .clear, lineWidth: 2))
        }
    }

    private func schemeButton(_ scheme: PosterColorScheme) -> some View {
        Button {
            colorScheme = scheme
        } label: {
            VStack(spacing: 4) {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(scheme.backgroundColor))
                    .frame(height: 32)
                    .overlay {
                        HStack(spacing: 2) {
                            Circle().fill(Color(scheme.landColor)).frame(width: 8)
                            Circle().fill(Color(scheme.visitedColor)).frame(width: 8)
                        }
                    }
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color(scheme.borderColor), lineWidth: 1))
                Text(scheme.displayName).font(.caption2).foregroundStyle(.primary)
            }
            .frame(maxWidth: .infinity)
            .padding(6)
            .background(self.colorScheme == scheme ? Color.blue.opacity(0.1) : .clear)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(self.colorScheme == scheme ? Color.blue : .clear, lineWidth: 2))
        }
    }

    // MARK: - Rendering

    private func renderPreview() {
        isRendering = true
        let params = RenderParams(displayMode: displayMode, labelMode: labelMode,
                                  colorScheme: colorScheme, visited: visitedCountryCodes,
                                  bucketList: bucketListCountryCodes)
        Task.detached {
            let image = PosterMapRenderer.renderImage(width: 1200, params: params)
            await MainActor.run { renderedImage = image; isRendering = false }
        }
    }

    private func shareImage() {
        isRendering = true
        let params = RenderParams(displayMode: displayMode, labelMode: labelMode,
                                  colorScheme: colorScheme, visited: visitedCountryCodes,
                                  bucketList: bucketListCountryCodes)
        Task.detached {
            let image = PosterMapRenderer.renderImage(width: 3000, params: params)
            await MainActor.run { renderedImage = image; isRendering = false; showShareSheet = true }
        }
    }
}

// MARK: - Full Screen Zoomable View

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
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .scaleEffect(scale)
                    .offset(offset)
                    .gesture(
                        MagnifyGesture()
                            .onChanged { value in
                                scale = lastScale * value.magnification
                            }
                            .onEnded { value in
                                lastScale = max(1, scale)
                                scale = lastScale
                                if lastScale == 1 { offset = .zero; lastOffset = .zero }
                            }
                            .simultaneously(with:
                                DragGesture()
                                    .onChanged { value in
                                        guard scale > 1 else { return }
                                        offset = CGSize(
                                            width: lastOffset.width + value.translation.width,
                                            height: lastOffset.height + value.translation.height
                                        )
                                    }
                                    .onEnded { _ in
                                        lastOffset = offset
                                    }
                            )
                    )
                    .onTapGesture(count: 2) {
                        withAnimation(.spring) {
                            if scale > 1 {
                                scale = 1; lastScale = 1; offset = .zero; lastOffset = .zero
                            } else {
                                scale = 3; lastScale = 3
                            }
                        }
                    }
            }

            // Close button
            VStack {
                HStack {
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title)
                            .foregroundStyle(.white.opacity(0.8))
                            .padding()
                    }
                }
                Spacer()
            }
        }
        .statusBarHidden()
    }
}

// MARK: - Render Params

struct RenderParams {
    let displayMode: PosterDisplayMode
    let labelMode: PosterLabelMode
    let colorScheme: PosterColorScheme
    let visited: Set<String>
    let bucketList: Set<String>
}

// MARK: - Poster Map Renderer

enum PosterMapRenderer {
    static func renderImage(width: CGFloat, params: RenderParams) -> UIImage {
        let hasListBelow = params.labelMode == .list
        let listHeight: CGFloat = hasListBelow ? width * 0.25 : 0
        let mapAspect: CGFloat = 1.6
        let mapHeight = width / mapAspect
        let totalHeight = mapHeight + listHeight
        let size = CGSize(width: width, height: totalHeight)

        let boundaries = GeoJSONParser.parseCountries()
        guard !boundaries.isEmpty else { return UIImage() }

        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            let context = ctx.cgContext
            let scheme = params.colorScheme

            // Background
            context.setFillColor(scheme.backgroundColor.cgColor)
            context.fill(CGRect(origin: .zero, size: size))

            // Map area
            let titleH: CGFloat = mapHeight * 0.08
            let footerH: CGFloat = mapHeight * 0.06
            let sideM: CGFloat = width * 0.04
            let mapRect = CGRect(x: sideM, y: titleH, width: width - sideM * 2, height: mapHeight - titleH - footerH)

            switch params.displayMode {
            case .highlighted:
                drawHighlightedMap(in: context, rect: mapRect, boundaries: boundaries, params: params)
            case .scratched:
                drawScratchedMap(in: context, rect: mapRect, boundaries: boundaries, params: params)
            case .pins:
                drawPinsMap(in: context, rect: mapRect, boundaries: boundaries, params: params)
            }

            // Labels on map
            if params.labelMode == .onMap {
                drawLabelsOnMap(in: context, rect: mapRect, boundaries: boundaries, params: params)
            }

            // Title
            drawTitle(in: context, width: width, titleH: titleH, scheme: scheme, title: "My Footprint")

            // Footer
            let count = params.visited.count
            drawFooter(in: context, width: width, mapHeight: mapHeight, footerH: footerH,
                       scheme: scheme, subtitle: "\(count) countries visited")

            // Country list below map
            if hasListBelow {
                drawCountryList(in: context, boundaries: boundaries, params: params,
                                y: mapHeight, width: width, height: listHeight)
            }
        }
    }

    // MARK: - Highlighted

    private static func drawHighlightedMap(in context: CGContext, rect: CGRect,
                                           boundaries: [GeoJSONParser.CountryBoundary], params: RenderParams) {
        for b in boundaries {
            let fill: UIColor
            if params.visited.contains(b.id) { fill = params.colorScheme.visitedColor }
            else if params.bucketList.contains(b.id) { fill = .systemOrange }
            else { fill = params.colorScheme.landColor }
            drawCountry(in: context, rect: rect, boundary: b, fillColor: fill, strokeColor: params.colorScheme.borderColor)
        }
    }

    // MARK: - Scratched (lottery scratch-card)

    private static func drawScratchedMap(in context: CGContext, rect: CGRect,
                                         boundaries: [GeoJSONParser.CountryBoundary], params: RenderParams) {
        let scheme = params.colorScheme

        // Layer 1: Draw ALL countries with vibrant unique colors (the prize underneath)
        for b in boundaries {
            let hue = countryHue(b.id)
            let color = UIColor(hue: hue, saturation: 0.55, brightness: 0.85, alpha: 1.0)
            drawCountry(in: context, rect: rect, boundary: b,
                        fillColor: color, strokeColor: color.withAlphaComponent(0.6), lineWidth: 0.3)
        }

        // Layer 2: Metallic scratch layer on unvisited countries
        let scratchBase: UIColor = (scheme == .dark || scheme == .ocean)
            ? UIColor(red: 0.72, green: 0.73, blue: 0.74, alpha: 1.0)  // silver
            : UIColor(red: 0.80, green: 0.72, blue: 0.46, alpha: 1.0)  // gold

        for b in boundaries {
            guard !params.visited.contains(b.id) else { continue }
            drawCountry(in: context, rect: rect, boundary: b,
                        fillColor: scratchBase, strokeColor: scratchBase.withAlphaComponent(0.4), lineWidth: 0.3)
        }

        // Layer 3: Messy scratch residue on VISITED countries (lazy scratching effect)
        for b in boundaries {
            guard params.visited.contains(b.id) else { continue }

            // Draw partial scratch residue — random-ish streaks of metallic color remaining
            let center = centroid(of: b, in: rect)
            context.saveGState()

            // Create scratch residue paths using the country boundary as a clip
            for polygon in b.polygons {
                let coords = polygon.coordinates
                guard coords.count >= 3 else { continue }

                let path = CGMutablePath()
                let first = project(lat: coords[0].latitude, lon: coords[0].longitude, rect: rect)
                path.move(to: first)
                for i in 1..<coords.count {
                    let pt = project(lat: coords[i].latitude, lon: coords[i].longitude, rect: rect)
                    let prev = project(lat: coords[i-1].latitude, lon: coords[i-1].longitude, rect: rect)
                    if abs(pt.x - prev.x) > rect.width * 0.5 { path.move(to: pt) }
                    else { path.addLine(to: pt) }
                }
                path.closeSubpath()

                // Clip to country and draw scratch residue streaks
                context.saveGState()
                context.addPath(path)
                context.clip()

                // Draw angled streaks of metallic residue
                let scratchResidueColor = scratchBase.withAlphaComponent(0.25)
                context.setStrokeColor(scratchResidueColor.cgColor)

                // Use country code hash to determine streak pattern
                let hash = countryHash(b.id)
                let streakAngle = CGFloat(hash % 40) / 40.0 * .pi - .pi / 2
                let streakCount = 3 + Int(hash % 5)
                let bounds = path.boundingBox

                for s in 0..<streakCount {
                    let progress = CGFloat(s) / CGFloat(streakCount)
                    let lineWidth = 2.0 + CGFloat(hash >> (s * 3) % 4)
                    context.setLineWidth(lineWidth)

                    let startX = bounds.minX + progress * bounds.width
                    let startY = bounds.minY + CGFloat(hash >> (s * 2) % 30) / 30.0 * bounds.height * 0.3
                    let length = bounds.width * (0.3 + CGFloat(hash >> (s + 7) % 40) / 40.0 * 0.5)

                    context.move(to: CGPoint(x: startX, y: startY))
                    context.addLine(to: CGPoint(
                        x: startX + cos(streakAngle) * length,
                        y: startY + sin(streakAngle) * length
                    ))
                    context.strokePath()
                }

                // Add some small residue flecks
                let fleckColor = scratchBase.withAlphaComponent(0.15)
                context.setFillColor(fleckColor.cgColor)
                for f in 0..<(4 + Int(hash % 6)) {
                    let fx = bounds.minX + CGFloat(hash >> (f * 5 + 1) % UInt64(max(1, bounds.width)))
                    let fy = bounds.minY + CGFloat(hash >> (f * 3 + 2) % UInt64(max(1, bounds.height)))
                    let fSize = 1.0 + CGFloat(hash >> (f + 10) % 3)
                    context.fillEllipse(in: CGRect(x: fx, y: fy, width: fSize, height: fSize))
                }

                context.restoreGState()
            }

            context.restoreGState()

            // Scratch edge highlight — white border where scratched meets unscratched
            drawCountry(in: context, rect: rect, boundary: b,
                        fillColor: .clear, strokeColor: UIColor.white.withAlphaComponent(0.5), lineWidth: 0.8)
        }

        // Layer 4: Subtle diagonal texture lines across the entire metallic surface
        context.saveGState()
        context.setStrokeColor(UIColor.white.withAlphaComponent(0.05).cgColor)
        context.setLineWidth(0.5)
        var y = rect.minY
        while y < rect.maxY {
            context.move(to: CGPoint(x: rect.minX, y: y))
            context.addLine(to: CGPoint(x: rect.maxX, y: y + 3))
            y += 5
        }
        context.strokePath()
        context.restoreGState()
    }

    private static func countryHue(_ code: String) -> CGFloat {
        CGFloat(countryHash(code) % 360) / 360.0
    }

    private static func countryHash(_ code: String) -> UInt64 {
        var hash: UInt64 = 5381
        for char in code.utf8 { hash = ((hash << 5) &+ hash) &+ UInt64(char) }
        return hash
    }

    // MARK: - Pins

    private static func drawPinsMap(in context: CGContext, rect: CGRect,
                                    boundaries: [GeoJSONParser.CountryBoundary], params: RenderParams) {
        for b in boundaries {
            drawCountry(in: context, rect: rect, boundary: b,
                        fillColor: params.colorScheme.landColor, strokeColor: params.colorScheme.borderColor)
        }
        for b in boundaries where params.visited.contains(b.id) {
            drawPin(in: context, at: centroid(of: b, in: rect), color: params.colorScheme.visitedColor)
        }
        for b in boundaries where params.bucketList.contains(b.id) {
            drawPin(in: context, at: centroid(of: b, in: rect), color: .systemOrange, small: true)
        }
    }

    // MARK: - Labels on Map

    private static func drawLabelsOnMap(in context: CGContext, rect: CGRect,
                                        boundaries: [GeoJSONParser.CountryBoundary], params: RenderParams) {
        UIGraphicsPushContext(context)
        let fontSize: CGFloat = max(6, rect.width * 0.008)
        let font = UIFont.systemFont(ofSize: fontSize, weight: .semibold)

        for b in boundaries {
            guard params.visited.contains(b.id) else { continue }
            let center = centroid(of: b, in: rect)
            let attrs: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: params.colorScheme.textColor.withAlphaComponent(0.9),
            ]
            let str = NSAttributedString(string: b.name, attributes: attrs)
            let strSize = str.size()

            // Background pill for readability
            let pillRect = CGRect(x: center.x - strSize.width / 2 - 3,
                                  y: center.y - strSize.height / 2 - 1,
                                  width: strSize.width + 6, height: strSize.height + 2)
            context.setFillColor(params.colorScheme.backgroundColor.withAlphaComponent(0.7).cgColor)
            let pillPath = UIBezierPath(roundedRect: pillRect, cornerRadius: 3)
            context.addPath(pillPath.cgPath)
            context.fillPath()

            str.draw(at: CGPoint(x: center.x - strSize.width / 2, y: center.y - strSize.height / 2))
        }
        UIGraphicsPopContext()
    }

    // MARK: - Country List Below Map

    private static func drawCountryList(in context: CGContext, boundaries: [GeoJSONParser.CountryBoundary],
                                        params: RenderParams, y: CGFloat, width: CGFloat, height: CGFloat) {
        let scheme = params.colorScheme
        let visitedNames = boundaries.filter { params.visited.contains($0.id) }
            .map { $0.name }.sorted()
        guard !visitedNames.isEmpty else { return }

        UIGraphicsPushContext(context)

        // Separator line
        context.setStrokeColor(scheme.borderColor.withAlphaComponent(0.3).cgColor)
        context.setLineWidth(0.5)
        context.move(to: CGPoint(x: width * 0.04, y: y + 4))
        context.addLine(to: CGPoint(x: width * 0.96, y: y + 4))
        context.strokePath()

        let fontSize: CGFloat = max(8, width * 0.01)
        let font = UIFont.systemFont(ofSize: fontSize, weight: .regular)
        let boldFont = UIFont.systemFont(ofSize: fontSize * 1.1, weight: .semibold)

        // Header
        let header = NSAttributedString(string: "Countries Visited", attributes: [
            .font: boldFont, .foregroundColor: scheme.textColor
        ])
        header.draw(at: CGPoint(x: width * 0.04, y: y + 12))

        // Country names in columns
        let startY = y + 12 + fontSize * 1.8
        let colWidth = width * 0.3
        let lineHeight = fontSize * 1.5
        let margin = width * 0.04
        let maxPerCol = Int((height - 30) / lineHeight)

        for (i, name) in visitedNames.enumerated() {
            let col = i / maxPerCol
            let row = i % maxPerCol
            if col >= 3 { break } // max 3 columns
            let str = NSAttributedString(string: "  \(name)", attributes: [
                .font: font, .foregroundColor: scheme.subtitleColor
            ])
            str.draw(at: CGPoint(x: margin + CGFloat(col) * colWidth, y: startY + CGFloat(row) * lineHeight))
        }

        UIGraphicsPopContext()
    }

    // MARK: - Drawing Helpers

    private static func drawCountry(in context: CGContext, rect: CGRect,
                                    boundary: GeoJSONParser.CountryBoundary,
                                    fillColor: UIColor, strokeColor: UIColor, lineWidth: CGFloat = 0.3) {
        for polygon in boundary.polygons {
            let coords = polygon.coordinates
            guard coords.count >= 3 else { continue }
            context.beginPath()
            let first = project(lat: coords[0].latitude, lon: coords[0].longitude, rect: rect)
            context.move(to: first)
            for i in 1..<coords.count {
                let pt = project(lat: coords[i].latitude, lon: coords[i].longitude, rect: rect)
                let prev = project(lat: coords[i-1].latitude, lon: coords[i-1].longitude, rect: rect)
                if abs(pt.x - prev.x) > rect.width * 0.5 { context.move(to: pt) }
                else { context.addLine(to: pt) }
            }
            context.closePath()
            context.setFillColor(fillColor.cgColor)
            context.setStrokeColor(strokeColor.cgColor)
            context.setLineWidth(lineWidth)
            context.drawPath(using: .fillStroke)
        }
    }

    private static func drawPin(in context: CGContext, at point: CGPoint, color: UIColor, small: Bool = false) {
        let r: CGFloat = small ? 3 : 5
        let rect = CGRect(x: point.x - r, y: point.y - r, width: r * 2, height: r * 2)
        context.saveGState()
        context.setShadow(offset: CGSize(width: 0, height: 1), blur: 2, color: UIColor.black.withAlphaComponent(0.3).cgColor)
        context.setFillColor(color.cgColor)
        context.fillEllipse(in: rect)
        context.restoreGState()
        context.setStrokeColor(UIColor.white.cgColor)
        context.setLineWidth(small ? 1 : 1.5)
        context.strokeEllipse(in: rect)
    }

    private static func centroid(of boundary: GeoJSONParser.CountryBoundary, in rect: CGRect) -> CGPoint {
        var best = boundary.polygons[0]
        for p in boundary.polygons { if p.coordinates.count > best.coordinates.count { best = p } }
        let coords = best.coordinates
        let avgLat = coords.reduce(0.0) { $0 + $1.latitude } / Double(coords.count)
        let avgLon = coords.reduce(0.0) { $0 + $1.longitude } / Double(coords.count)
        return project(lat: avgLat, lon: avgLon, rect: rect)
    }

    // MARK: - Miller Projection

    private static func project(lat: Double, lon: Double, rect: CGRect) -> CGPoint {
        let x = (lon + 180.0) / 360.0
        let latRad = lat * .pi / 180.0
        let millerY = 1.25 * log(tan(.pi / 4.0 + 0.4 * latRad))
        let yNorm = (1.0 - millerY / 2.3) / 2.0
        return CGPoint(
            x: rect.origin.x + max(0, min(1, x)) * rect.width,
            y: rect.origin.y + max(0, min(1, yNorm)) * rect.height
        )
    }

    // MARK: - Title & Footer

    private static func drawTitle(in context: CGContext, width: CGFloat, titleH: CGFloat,
                                  scheme: PosterColorScheme, title: String) {
        let font = UIFont.systemFont(ofSize: titleH * 0.38, weight: .bold)
        let str = NSAttributedString(string: title, attributes: [.font: font, .foregroundColor: scheme.textColor])
        let s = str.size()
        UIGraphicsPushContext(context)
        str.draw(at: CGPoint(x: (width - s.width) / 2, y: (titleH - s.height) / 2))
        UIGraphicsPopContext()
    }

    private static func drawFooter(in context: CGContext, width: CGFloat, mapHeight: CGFloat,
                                   footerH: CGFloat, scheme: PosterColorScheme, subtitle: String) {
        let y = mapHeight - footerH
        let font = UIFont.systemFont(ofSize: footerH * 0.28, weight: .medium)
        let str = NSAttributedString(string: subtitle, attributes: [.font: font, .foregroundColor: scheme.subtitleColor])
        let s = str.size()
        UIGraphicsPushContext(context)
        str.draw(at: CGPoint(x: (width - s.width) / 2, y: y + (footerH - s.height) / 2))

        let brand = NSAttributedString(string: "Footprint", attributes: [
            .font: UIFont.systemFont(ofSize: footerH * 0.18, weight: .regular),
            .foregroundColor: scheme.subtitleColor.withAlphaComponent(0.5)
        ])
        let bs = brand.size()
        brand.draw(at: CGPoint(x: width - bs.width - width * 0.04, y: y + (footerH - bs.height) / 2))
        UIGraphicsPopContext()
    }
}
