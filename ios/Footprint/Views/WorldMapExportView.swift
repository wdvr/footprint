import MapKit
import SwiftUI
import UIKit

// MARK: - Display Mode

enum PosterDisplayMode: String, CaseIterable, Identifiable {
    case live
    case highlighted
    case scratched
    case pins
    case passport

    var id: String { rawValue }

    var label: String {
        switch self {
        case .live: return "Live"
        case .highlighted: return "Highlight"
        case .scratched: return "Scratch"
        case .pins: return "Pins"
        case .passport: return "Stamps"
        }
    }

    var icon: String {
        switch self {
        case .live: return "map.fill"
        case .highlighted: return "paintbrush.fill"
        case .scratched: return "hand.draw.fill"
        case .pins: return "mappin.and.ellipse"
        case .passport: return "seal.fill"
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
                    posterPreview
                        .padding(.horizontal)
                        .onTapGesture { showFullScreen = true }

                    pickerSection("Style") {
                        HStack(spacing: 8) {
                            ForEach(PosterDisplayMode.allCases) { mode in
                                modeButton(mode)
                            }
                        }
                    }

                    pickerSection("Labels") {
                        HStack(spacing: 12) {
                            ForEach(PosterLabelMode.allCases) { mode in
                                labelButton(mode)
                            }
                        }
                    }

                    pickerSection("Theme") {
                        HStack(spacing: 12) {
                            ForEach(PosterColorScheme.allCases) { scheme in
                                schemeButton(scheme)
                            }
                        }
                    }

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
                ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } }
                ToolbarItem(placement: .primaryAction) {
                    Button { showFullScreen = true } label: {
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                    }
                }
            }
            .sheet(isPresented: $showShareSheet) {
                if let image = renderedImage { ActivityViewController(activityItems: [image]) }
            }
            .fullScreenCover(isPresented: $showFullScreen) {
                PosterFullScreenView(image: renderedImage)
            }
            .task { renderPreview() }
            .onChange(of: displayMode) { renderPreview() }
            .onChange(of: colorScheme) { renderPreview() }
            .onChange(of: labelMode) { renderPreview() }
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
            // Interactive MapKit view
            CountryMapView(
                visitedCountryCodes: visitedCountryCodes,
                bucketListCountryCodes: bucketListCountryCodes,
                visitedStateCodes: visitedStateCodes,
                bucketListStateCodes: bucketListStateCodes,
                selectedCountry: .constant(nil),
                centerOnUserLocation: .constant(false)
            )
            .frame(height: 300)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.2), radius: 8, y: 4)
        } else if let image = renderedImage {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .shadow(color: .black.opacity(0.2), radius: 8, y: 4)
                .overlay(alignment: .bottomTrailing) {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(.caption).padding(6)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .padding(8)
                }
        } else {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(colorScheme.backgroundColor))
                .aspectRatio(2.0, contentMode: .fit)
                .overlay { ProgressView() }
        }
    }

    private func modeButton(_ mode: PosterDisplayMode) -> some View {
        Button { displayMode = mode } label: {
            VStack(spacing: 4) {
                Image(systemName: mode.icon).font(.title3)
                Text(mode.label).font(.caption2).fontWeight(.medium)
            }
            .frame(maxWidth: .infinity).padding(.vertical, 10)
            .background(displayMode == mode ? Color.blue.opacity(0.15) : Color(.secondarySystemGroupedBackground))
            .foregroundStyle(displayMode == mode ? .blue : .primary)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(displayMode == mode ? Color.blue : .clear, lineWidth: 2))
        }
    }

    private func labelButton(_ mode: PosterLabelMode) -> some View {
        Button { labelMode = mode } label: {
            VStack(spacing: 6) {
                Image(systemName: mode.icon).font(.title2)
                Text(mode.label).font(.caption).fontWeight(.medium)
            }
            .frame(maxWidth: .infinity).padding(.vertical, 12)
            .background(labelMode == mode ? Color.blue.opacity(0.15) : Color(.secondarySystemGroupedBackground))
            .foregroundStyle(labelMode == mode ? .blue : .primary)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(labelMode == mode ? Color.blue : .clear, lineWidth: 2))
        }
    }

    private func schemeButton(_ scheme: PosterColorScheme) -> some View {
        Button { colorScheme = scheme } label: {
            VStack(spacing: 4) {
                RoundedRectangle(cornerRadius: 6).fill(Color(scheme.backgroundColor)).frame(height: 32)
                    .overlay { HStack(spacing: 2) { Circle().fill(Color(scheme.landColor)).frame(width: 8); Circle().fill(Color(scheme.visitedColor)).frame(width: 8) } }
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color(scheme.borderColor), lineWidth: 1))
                Text(scheme.displayName).font(.caption2).foregroundStyle(.primary)
            }
            .frame(maxWidth: .infinity).padding(6)
            .background(self.colorScheme == scheme ? Color.blue.opacity(0.1) : .clear)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(self.colorScheme == scheme ? Color.blue : .clear, lineWidth: 2))
        }
    }

    private func renderPreview() {
        isRendering = true
        let p = RenderParams(displayMode: displayMode, labelMode: labelMode, colorScheme: colorScheme,
                             visited: visitedCountryCodes, bucketList: bucketListCountryCodes)
        Task.detached {
            let img = PosterMapRenderer.renderImage(width: 2400, params: p)
            await MainActor.run { renderedImage = img; isRendering = false }
        }
    }

    private func shareImage() {
        isRendering = true
        let p = RenderParams(displayMode: displayMode, labelMode: labelMode, colorScheme: colorScheme,
                             visited: visitedCountryCodes, bucketList: bucketListCountryCodes)
        Task.detached {
            let img = PosterMapRenderer.renderImage(width: 4000, params: p)
            await MainActor.run { renderedImage = img; isRendering = false; showShareSheet = true }
        }
    }
}

// MARK: - Full Screen Zoomable

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
            VStack { HStack { Spacer(); Button { dismiss() } label: { Image(systemName: "xmark.circle.fill").font(.title).foregroundStyle(.white.opacity(0.8)).padding() } }; Spacer() }
        }
        .statusBarHidden()
    }
}

// MARK: - Render Params

struct RenderParams: Sendable {
    let displayMode: PosterDisplayMode
    let labelMode: PosterLabelMode
    let colorScheme: PosterColorScheme
    let visited: Set<String>
    let bucketList: Set<String>
}

// MARK: - Renderer

enum PosterMapRenderer {
    static func renderImage(width: CGFloat, params: RenderParams) -> UIImage {
        let hasListBelow = params.labelMode == .list
        let listH: CGFloat = hasListBelow ? width * 0.2 : 0
        let mapH = width / 2.0
        let size = CGSize(width: width, height: mapH + listH)
        let boundaries = GeoJSONParser.parseCountries()
        guard !boundaries.isEmpty else { return UIImage() }

        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            let c = ctx.cgContext
            let s = params.colorScheme
            c.setFillColor(s.backgroundColor.cgColor)
            c.fill(CGRect(origin: .zero, size: size))

            let titleH: CGFloat = mapH * 0.07
            let footerH: CGFloat = mapH * 0.05
            let sideM: CGFloat = width * 0.03
            let mapRect = CGRect(x: sideM, y: titleH, width: width - sideM * 2, height: mapH - titleH - footerH)

            switch params.displayMode {
            case .live: drawHighlighted(c, mapRect, boundaries, params) // fallback for share
            case .highlighted: drawHighlighted(c, mapRect, boundaries, params)
            case .scratched: drawScratched(c, mapRect, boundaries, params)
            case .pins: drawPins(c, mapRect, boundaries, params)
            case .passport: drawPassport(c, mapRect, boundaries, params)
            }

            if params.labelMode == .onMap { drawLabelsOnMap(c, mapRect, boundaries, params) }

            drawTitle(c, width, titleH, s)
            drawFooter(c, width, mapH, footerH, s, params.visited.count)

            if hasListBelow { drawCountryList(c, boundaries, params, mapH, width, listH) }
        }
    }

    // MARK: - Highlighted

    private static func drawHighlighted(_ c: CGContext, _ r: CGRect,
                                        _ bs: [GeoJSONParser.CountryBoundary], _ p: RenderParams) {
        for b in bs {
            let fill: UIColor = p.visited.contains(b.id) ? p.colorScheme.visitedColor
                : p.bucketList.contains(b.id) ? .systemOrange : p.colorScheme.landColor
            drawCountry(c, r, b, fill, p.colorScheme.borderColor)
        }
    }

    // MARK: - Scratched (realistic scratch card)

    private static func drawScratched(_ c: CGContext, _ r: CGRect,
                                      _ bs: [GeoJSONParser.CountryBoundary], _ p: RenderParams) {
        let scheme = p.colorScheme
        let isSilver = (scheme == .dark || scheme == .ocean)
        let metalBase: UIColor = isSilver
            ? UIColor(red: 0.75, green: 0.76, blue: 0.78, alpha: 1.0)
            : UIColor(red: 0.82, green: 0.74, blue: 0.48, alpha: 1.0)
        let metalDark: UIColor = isSilver
            ? UIColor(red: 0.60, green: 0.61, blue: 0.63, alpha: 1.0)
            : UIColor(red: 0.68, green: 0.60, blue: 0.36, alpha: 1.0)

        // Layer 1: Colorful map underneath everything
        for b in bs {
            let hue = countryHue(b.id)
            let color = UIColor(hue: hue, saturation: 0.6, brightness: 0.88, alpha: 1.0)
            drawCountry(c, r, b, color, color.withAlphaComponent(0.5), 0.3)
        }

        // Layer 2: Full metallic overlay on ALL countries
        for b in bs {
            drawCountry(c, r, b, metalBase, metalDark.withAlphaComponent(0.3), 0.3)
        }

        // Layer 3: Metallic texture (subtle noise-like pattern)
        c.saveGState()
        let hash0: UInt64 = 42
        for i in 0..<Int(r.width / 3) {
            let x = r.minX + CGFloat(i) * 3
            let yOff = CGFloat((hash0 &* UInt64(i * 7 + 3)) % 5) - 2
            c.setStrokeColor(UIColor.white.withAlphaComponent(0.04).cgColor)
            c.setLineWidth(0.5)
            c.move(to: CGPoint(x: x, y: r.minY + yOff))
            c.addLine(to: CGPoint(x: x + 2, y: r.maxY + yOff))
            c.strokePath()
        }
        c.restoreGState()

        // Layer 4: "Scratch off" visited countries — remove metal, reveal color
        // Use clip-to-country + clear to punch through the metallic layer
        for b in bs {
            guard p.visited.contains(b.id) else { continue }

            // Redraw the colorful country on top (punching through metal)
            let hue = countryHue(b.id)
            let revealColor = UIColor(hue: hue, saturation: 0.6, brightness: 0.88, alpha: 1.0)
            drawCountry(c, r, b, revealColor, revealColor.withAlphaComponent(0.7), 0.3)

            // Draw organic scratch residue patches (unscratched metallic bits remaining)
            for polygon in b.polygons {
                let coords = polygon.coordinates
                guard coords.count >= 3 else { continue }

                let path = countryPath(coords, r)
                c.saveGState()
                c.addPath(path)
                c.clip()

                let bounds = path.boundingBox
                let h = countryHash(b.id)

                // Draw 2-4 organic residue patches (curved blobs, not lines)
                let patchCount = 2 + Int(h % 3)
                for pi in 0..<patchCount {
                    let ph = h &* UInt64(pi + 1) &+ UInt64(pi * 37)
                    let cx = bounds.minX + CGFloat(ph % UInt64(max(1, bounds.width)))
                    let cy = bounds.minY + CGFloat((ph >> 8) % UInt64(max(1, bounds.height)))
                    let sw = bounds.width * (0.15 + CGFloat((ph >> 4) % 20) / 100.0)
                    let sh = bounds.height * (0.1 + CGFloat((ph >> 12) % 15) / 100.0)

                    let blob = CGMutablePath()
                    blob.addEllipse(in: CGRect(x: cx - sw/2, y: cy - sh/2, width: sw, height: sh))

                    c.addPath(blob)
                    c.setFillColor(metalBase.withAlphaComponent(0.45).cgColor)
                    c.fillPath()

                    // Slightly darker edge on residue
                    c.addPath(blob)
                    c.setStrokeColor(metalDark.withAlphaComponent(0.2).cgColor)
                    c.setLineWidth(0.8)
                    c.strokePath()
                }

                c.restoreGState()
            }
        }
    }

    // MARK: - Pins

    private static func drawPins(_ c: CGContext, _ r: CGRect,
                                 _ bs: [GeoJSONParser.CountryBoundary], _ p: RenderParams) {
        for b in bs { drawCountry(c, r, b, p.colorScheme.landColor, p.colorScheme.borderColor) }
        for b in bs where p.visited.contains(b.id) { drawPin(c, centroid(b, r), p.colorScheme.visitedColor, r.width) }
        for b in bs where p.bucketList.contains(b.id) { drawPin(c, centroid(b, r), .systemOrange, r.width, true) }
    }

    // MARK: - Passport Stamps

    private static func drawPassport(_ c: CGContext, _ r: CGRect,
                                     _ bs: [GeoJSONParser.CountryBoundary], _ p: RenderParams) {
        // Draw all countries in subtle land color
        for b in bs { drawCountry(c, r, b, p.colorScheme.landColor, p.colorScheme.borderColor) }

        // Draw passport-style stamps on visited countries
        let stampColors: [UIColor] = [
            UIColor(red: 0.8, green: 0.15, blue: 0.15, alpha: 0.7),   // red
            UIColor(red: 0.1, green: 0.3, blue: 0.7, alpha: 0.7),     // blue
            UIColor(red: 0.15, green: 0.55, blue: 0.15, alpha: 0.7),   // green
            UIColor(red: 0.5, green: 0.1, blue: 0.5, alpha: 0.7),     // purple
        ]

        UIGraphicsPushContext(c)
        let stampSize = max(16, r.width * 0.028)

        for b in bs {
            guard p.visited.contains(b.id) else { continue }
            let center = centroid(b, r)
            let h = countryHash(b.id)
            let colorIdx = Int(h % UInt64(stampColors.count))
            let color = stampColors[colorIdx]
            let rotation = CGFloat(Int(h >> 4) % 30 - 15) * .pi / 180.0

            c.saveGState()
            c.translateBy(x: center.x, y: center.y)
            c.rotate(by: rotation)

            // Stamp circle border
            let stampRect = CGRect(x: -stampSize/2, y: -stampSize/2, width: stampSize, height: stampSize)
            c.setStrokeColor(color.cgColor)
            c.setLineWidth(max(1.5, stampSize * 0.08))
            c.strokeEllipse(in: stampRect)

            // Inner circle
            let innerRect = stampRect.insetBy(dx: stampSize * 0.12, dy: stampSize * 0.12)
            c.setLineWidth(max(0.5, stampSize * 0.03))
            c.strokeEllipse(in: innerRect)

            // Country code text
            let fontSize = max(5, stampSize * 0.3)
            let font = UIFont.systemFont(ofSize: fontSize, weight: .heavy)
            let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
            let code = NSAttributedString(string: b.id, attributes: attrs)
            let codeSize = code.size()
            code.draw(at: CGPoint(x: -codeSize.width / 2, y: -codeSize.height / 2))

            c.restoreGState()
        }
        UIGraphicsPopContext()
    }

    // MARK: - Labels on Map (with collision avoidance)

    private static func drawLabelsOnMap(_ c: CGContext, _ r: CGRect,
                                        _ bs: [GeoJSONParser.CountryBoundary], _ p: RenderParams) {
        UIGraphicsPushContext(c)
        let fontSize = max(8, r.width * 0.007)
        let font = UIFont.systemFont(ofSize: fontSize, weight: .semibold)
        var placedRects: [CGRect] = []

        // Sort by polygon area (largest first) so big countries get labeled first
        let sorted = bs.filter { p.visited.contains($0.id) }
            .sorted { countryArea($0, r) > countryArea($1, r) }

        for b in sorted {
            let center = centroid(b, r)
            let attrs: [NSAttributedString.Key: Any] = [
                .font: font, .foregroundColor: p.colorScheme.textColor.withAlphaComponent(0.9)
            ]
            let str = NSAttributedString(string: b.name, attributes: attrs)
            let strSize = str.size()

            let labelRect = CGRect(x: center.x - strSize.width / 2 - 4,
                                   y: center.y - strSize.height / 2 - 2,
                                   width: strSize.width + 8, height: strSize.height + 4)

            // Skip if overlaps with any placed label
            if placedRects.contains(where: { $0.intersects(labelRect.insetBy(dx: -2, dy: -1)) }) { continue }
            // Skip if outside map bounds
            guard r.contains(labelRect) else { continue }

            placedRects.append(labelRect)

            // Background pill
            c.setFillColor(p.colorScheme.backgroundColor.withAlphaComponent(0.75).cgColor)
            c.addPath(UIBezierPath(roundedRect: labelRect, cornerRadius: 3).cgPath)
            c.fillPath()

            str.draw(at: CGPoint(x: center.x - strSize.width / 2, y: center.y - strSize.height / 2))
        }
        UIGraphicsPopContext()
    }

    private static func countryArea(_ b: GeoJSONParser.CountryBoundary, _ r: CGRect) -> CGFloat {
        guard let biggest = b.polygons.max(by: { $0.coordinates.count < $1.coordinates.count }) else { return 0 }
        let path = countryPath(biggest.coordinates, r)
        return path.boundingBox.width * path.boundingBox.height
    }

    // MARK: - Country List

    private static func drawCountryList(_ c: CGContext, _ bs: [GeoJSONParser.CountryBoundary],
                                        _ p: RenderParams, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) {
        let names = bs.filter { p.visited.contains($0.id) }.map { $0.name }.sorted()
        guard !names.isEmpty else { return }
        UIGraphicsPushContext(c)

        c.setStrokeColor(p.colorScheme.borderColor.withAlphaComponent(0.3).cgColor)
        c.setLineWidth(0.5)
        c.move(to: CGPoint(x: w * 0.03, y: y + 4))
        c.addLine(to: CGPoint(x: w * 0.97, y: y + 4))
        c.strokePath()

        let fs: CGFloat = max(8, w * 0.009)
        let bold = UIFont.systemFont(ofSize: fs * 1.1, weight: .semibold)
        let reg = UIFont.systemFont(ofSize: fs, weight: .regular)

        NSAttributedString(string: "Countries Visited", attributes: [.font: bold, .foregroundColor: p.colorScheme.textColor])
            .draw(at: CGPoint(x: w * 0.03, y: y + 10))

        let startY = y + 10 + fs * 1.8
        let colW = w * 0.23
        let lineH = fs * 1.4
        let margin = w * 0.03
        let maxPerCol = Int((h - 24) / lineH)

        for (i, name) in names.enumerated() {
            let col = i / maxPerCol; let row = i % maxPerCol
            if col >= 4 { break }
            NSAttributedString(string: name, attributes: [.font: reg, .foregroundColor: p.colorScheme.subtitleColor])
                .draw(at: CGPoint(x: margin + CGFloat(col) * colW, y: startY + CGFloat(row) * lineH))
        }
        UIGraphicsPopContext()
    }

    // MARK: - Drawing Helpers

    private static func drawCountry(_ c: CGContext, _ r: CGRect, _ b: GeoJSONParser.CountryBoundary,
                                    _ fill: UIColor, _ stroke: UIColor, _ lw: CGFloat = 0.3) {
        for polygon in b.polygons {
            let coords = polygon.coordinates
            guard coords.count >= 3 else { continue }
            let path = countryPath(coords, r)
            c.addPath(path)
            c.setFillColor(fill.cgColor)
            c.setStrokeColor(stroke.cgColor)
            c.setLineWidth(lw)
            c.drawPath(using: .fillStroke)
        }
    }

    private static func countryPath(_ coords: [CLLocationCoordinate2D], _ r: CGRect) -> CGPath {
        let path = CGMutablePath()
        let first = project(coords[0].latitude, coords[0].longitude, r)
        path.move(to: first)
        for i in 1..<coords.count {
            let pt = project(coords[i].latitude, coords[i].longitude, r)
            let prev = project(coords[i-1].latitude, coords[i-1].longitude, r)
            if abs(pt.x - prev.x) > r.width * 0.5 { path.move(to: pt) } else { path.addLine(to: pt) }
        }
        path.closeSubpath()
        return path
    }

    private static func drawPin(_ c: CGContext, _ pt: CGPoint, _ color: UIColor, _ mapWidth: CGFloat, _ small: Bool = false) {
        let r = small ? max(3, mapWidth * 0.004) : max(5, mapWidth * 0.006)
        let rect = CGRect(x: pt.x - r, y: pt.y - r, width: r * 2, height: r * 2)
        c.saveGState()
        c.setShadow(offset: CGSize(width: 0, height: 1), blur: 2, color: UIColor.black.withAlphaComponent(0.3).cgColor)
        c.setFillColor(color.cgColor); c.fillEllipse(in: rect)
        c.restoreGState()
        c.setStrokeColor(UIColor.white.cgColor); c.setLineWidth(small ? 1 : 1.5); c.strokeEllipse(in: rect)
    }

    private static func centroid(_ b: GeoJSONParser.CountryBoundary, _ r: CGRect) -> CGPoint {
        var best = b.polygons[0]
        for p in b.polygons { if p.coordinates.count > best.coordinates.count { best = p } }
        let coords = best.coordinates
        let lat = coords.reduce(0.0) { $0 + $1.latitude } / Double(coords.count)
        let lon = coords.reduce(0.0) { $0 + $1.longitude } / Double(coords.count)
        return project(lat, lon, r)
    }

    private static func countryHue(_ code: String) -> CGFloat { CGFloat(countryHash(code) % 360) / 360.0 }

    private static func countryHash(_ code: String) -> UInt64 {
        var h: UInt64 = 5381
        for ch in code.utf8 { h = ((h << 5) &+ h) &+ UInt64(ch) }
        return h
    }

    // MARK: - Miller Projection

    private static func project(_ lat: Double, _ lon: Double, _ r: CGRect) -> CGPoint {
        let x = (lon + 180.0) / 360.0
        let latRad = lat * .pi / 180.0
        let millerY = 1.25 * log(tan(.pi / 4.0 + 0.4 * latRad))
        let yN = (1.0 - millerY / 2.3) / 2.0
        return CGPoint(x: r.origin.x + max(0, min(1, x)) * r.width, y: r.origin.y + max(0, min(1, yN)) * r.height)
    }

    // MARK: - Title & Footer

    private static func drawTitle(_ c: CGContext, _ w: CGFloat, _ h: CGFloat, _ s: PosterColorScheme) {
        let f = UIFont.systemFont(ofSize: h * 0.4, weight: .bold)
        let str = NSAttributedString(string: "My Footprint", attributes: [.font: f, .foregroundColor: s.textColor])
        let sz = str.size()
        UIGraphicsPushContext(c); str.draw(at: CGPoint(x: (w - sz.width) / 2, y: (h - sz.height) / 2)); UIGraphicsPopContext()
    }

    private static func drawFooter(_ c: CGContext, _ w: CGFloat, _ mh: CGFloat, _ fh: CGFloat, _ s: PosterColorScheme, _ count: Int) {
        let y = mh - fh
        UIGraphicsPushContext(c)
        let str = NSAttributedString(string: "\(count) countries visited",
                                     attributes: [.font: UIFont.systemFont(ofSize: fh * 0.3, weight: .medium), .foregroundColor: s.subtitleColor])
        let sz = str.size()
        str.draw(at: CGPoint(x: (w - sz.width) / 2, y: y + (fh - sz.height) / 2))
        let brand = NSAttributedString(string: "Footprint",
                                       attributes: [.font: UIFont.systemFont(ofSize: fh * 0.2, weight: .regular), .foregroundColor: s.subtitleColor.withAlphaComponent(0.5)])
        let bs = brand.size()
        brand.draw(at: CGPoint(x: w - bs.width - w * 0.03, y: y + (fh - bs.height) / 2))
        UIGraphicsPopContext()
    }
}

// MKPolygon.coordinates extension is in PosterGeneratorView.swift
