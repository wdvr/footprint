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

// MARK: - Poster View

struct WorldMapExportView: View {
    let visitedCountryCodes: Set<String>
    let bucketListCountryCodes: Set<String>
    let visitedStateCodes: Set<String>
    let bucketListStateCodes: Set<String>
    let visitedPlaces: [VisitedPlace]

    @Environment(\.dismiss) private var dismiss
    @State private var displayMode: PosterDisplayMode = .highlighted
    @State private var colorScheme: PosterColorScheme = .dark
    @State private var renderedImage: UIImage?
    @State private var isRendering = false
    @State private var showShareSheet = false

    private var countryCount: Int { visitedCountryCodes.count }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Preview
                    posterPreview
                        .padding(.horizontal)

                    // Mode picker
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Style")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal)

                        HStack(spacing: 12) {
                            ForEach(PosterDisplayMode.allCases) { mode in
                                modeButton(mode)
                            }
                        }
                        .padding(.horizontal)
                    }

                    // Color scheme picker
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Theme")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal)

                        HStack(spacing: 12) {
                            ForEach(PosterColorScheme.allCases) { scheme in
                                schemeButton(scheme)
                            }
                        }
                        .padding(.horizontal)
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
            }
            .sheet(isPresented: $showShareSheet) {
                if let image = renderedImage {
                    ActivityViewController(activityItems: [image])
                }
            }
            .task {
                renderPreview()
            }
            .onChange(of: displayMode) {
                renderPreview()
            }
            .onChange(of: colorScheme) {
                renderPreview()
            }
        }
    }

    // MARK: - Preview

    @ViewBuilder
    private var posterPreview: some View {
        if let image = renderedImage {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .shadow(color: .black.opacity(0.2), radius: 8, y: 4)
        } else {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(colorScheme.backgroundColor))
                .aspectRatio(1.6, contentMode: .fit)
                .overlay {
                    ProgressView()
                }
        }
    }

    // MARK: - Mode Button

    private func modeButton(_ mode: PosterDisplayMode) -> some View {
        Button {
            displayMode = mode
        } label: {
            VStack(spacing: 6) {
                Image(systemName: mode.icon)
                    .font(.title2)
                Text(mode.label)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(displayMode == mode ? Color.blue.opacity(0.15) : Color(.secondarySystemGroupedBackground))
            .foregroundStyle(displayMode == mode ? .blue : .primary)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(displayMode == mode ? Color.blue : Color.clear, lineWidth: 2)
            )
        }
    }

    // MARK: - Scheme Button

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
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color(scheme.borderColor), lineWidth: 1)
                    )
                Text(scheme.displayName)
                    .font(.caption2)
                    .foregroundStyle(.primary)
            }
            .frame(maxWidth: .infinity)
            .padding(6)
            .background(self.colorScheme == scheme ? Color.blue.opacity(0.1) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(self.colorScheme == scheme ? Color.blue : Color.clear, lineWidth: 2)
            )
        }
    }

    // MARK: - Rendering

    private func renderPreview() {
        isRendering = true
        let mode = displayMode
        let scheme = colorScheme
        let visited = visitedCountryCodes
        let bucketList = bucketListCountryCodes

        Task.detached {
            let image = PosterMapRenderer.renderImage(
                width: 1200,
                visitedCountryCodes: visited,
                bucketListCountryCodes: bucketList,
                colorScheme: scheme,
                displayMode: mode
            )
            await MainActor.run {
                renderedImage = image
                isRendering = false
            }
        }
    }

    private func shareImage() {
        isRendering = true
        let mode = displayMode
        let scheme = colorScheme
        let visited = visitedCountryCodes
        let bucketList = bucketListCountryCodes

        Task.detached {
            let image = PosterMapRenderer.renderImage(
                width: 3000,
                visitedCountryCodes: visited,
                bucketListCountryCodes: bucketList,
                colorScheme: scheme,
                displayMode: mode
            )
            await MainActor.run {
                renderedImage = image
                isRendering = false
                showShareSheet = true
            }
        }
    }
}

// MARK: - Poster Map Renderer

enum PosterMapRenderer {
    static func renderImage(
        width: CGFloat,
        visitedCountryCodes: Set<String>,
        bucketListCountryCodes: Set<String>,
        colorScheme: PosterColorScheme,
        displayMode: PosterDisplayMode
    ) -> UIImage {
        let aspectRatio: CGFloat = 1.6
        let size = CGSize(width: width, height: width / aspectRatio)

        let boundaries = GeoJSONParser.parseCountries()
        guard !boundaries.isEmpty else {
            return UIImage()
        }

        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            let context = ctx.cgContext

            // Background
            context.setFillColor(colorScheme.backgroundColor.cgColor)
            context.fill(CGRect(origin: .zero, size: size))

            // Map area with margins
            let titleHeight: CGFloat = size.height * 0.08
            let footerHeight: CGFloat = size.height * 0.06
            let sideMargin: CGFloat = size.width * 0.04
            let mapRect = CGRect(
                x: sideMargin,
                y: titleHeight,
                width: size.width - sideMargin * 2,
                height: size.height - titleHeight - footerHeight
            )

            switch displayMode {
            case .highlighted:
                drawHighlightedMap(
                    in: context, rect: mapRect, boundaries: boundaries,
                    visited: visitedCountryCodes, bucketList: bucketListCountryCodes,
                    scheme: colorScheme
                )
            case .scratched:
                drawScratchedMap(
                    in: context, rect: mapRect, boundaries: boundaries,
                    visited: visitedCountryCodes, scheme: colorScheme
                )
            case .pins:
                drawPinsMap(
                    in: context, rect: mapRect, boundaries: boundaries,
                    visited: visitedCountryCodes, bucketList: bucketListCountryCodes,
                    scheme: colorScheme
                )
            }

            // Title
            drawTitle(in: context, size: size, titleHeight: titleHeight,
                      scheme: colorScheme, title: "My Footprint")

            // Footer
            let count = visitedCountryCodes.count
            let subtitle = "\(count) countries visited"
            drawFooter(in: context, size: size, footerHeight: footerHeight,
                       scheme: colorScheme, subtitle: subtitle)
        }
    }

    // MARK: - Highlighted Mode (standard colored fill)

    private static func drawHighlightedMap(
        in context: CGContext, rect: CGRect,
        boundaries: [GeoJSONParser.CountryBoundary],
        visited: Set<String>, bucketList: Set<String>,
        scheme: PosterColorScheme
    ) {
        for boundary in boundaries {
            let isVisited = visited.contains(boundary.id)
            let isBucketList = bucketList.contains(boundary.id)
            let fillColor: UIColor
            if isVisited {
                fillColor = scheme.visitedColor
            } else if isBucketList {
                fillColor = UIColor.systemOrange
            } else {
                fillColor = scheme.landColor
            }

            drawCountry(in: context, rect: rect, boundary: boundary,
                        fillColor: fillColor, strokeColor: scheme.borderColor)
        }
    }

    // MARK: - Scratched Mode (visited revealed, unvisited hidden)

    private static func drawScratchedMap(
        in context: CGContext, rect: CGRect,
        boundaries: [GeoJSONParser.CountryBoundary],
        visited: Set<String>, scheme: PosterColorScheme
    ) {
        // Draw a subtle outline for ALL countries first
        for boundary in boundaries {
            let outlineColor = scheme.borderColor.withAlphaComponent(0.15)
            drawCountry(in: context, rect: rect, boundary: boundary,
                        fillColor: scheme.landColor.withAlphaComponent(0.08),
                        strokeColor: outlineColor, lineWidth: 0.2)
        }

        // Then draw visited countries fully revealed with vibrant color
        for boundary in boundaries {
            guard visited.contains(boundary.id) else { continue }
            drawCountry(in: context, rect: rect, boundary: boundary,
                        fillColor: scheme.visitedColor,
                        strokeColor: scheme.visitedColor.withAlphaComponent(0.8),
                        lineWidth: 0.5)
        }
    }

    // MARK: - Pins Mode (all countries drawn, pins on visited)

    private static func drawPinsMap(
        in context: CGContext, rect: CGRect,
        boundaries: [GeoJSONParser.CountryBoundary],
        visited: Set<String>, bucketList: Set<String>,
        scheme: PosterColorScheme
    ) {
        // Draw all countries with land color
        for boundary in boundaries {
            drawCountry(in: context, rect: rect, boundary: boundary,
                        fillColor: scheme.landColor, strokeColor: scheme.borderColor)
        }

        // Draw pins on visited countries
        for boundary in boundaries {
            guard visited.contains(boundary.id) else { continue }
            let center = centroid(of: boundary, in: rect)
            drawPin(in: context, at: center, color: scheme.visitedColor)
        }

        // Draw smaller pins on bucket list
        for boundary in boundaries {
            guard bucketList.contains(boundary.id) else { continue }
            let center = centroid(of: boundary, in: rect)
            drawPin(in: context, at: center, color: .systemOrange, small: true)
        }
    }

    // MARK: - Drawing Helpers

    private static func drawCountry(
        in context: CGContext, rect: CGRect,
        boundary: GeoJSONParser.CountryBoundary,
        fillColor: UIColor, strokeColor: UIColor,
        lineWidth: CGFloat = 0.3
    ) {
        for polygon in boundary.polygons {
            let coords = polygon.coordinates
            guard coords.count >= 3 else { continue }

            context.beginPath()
            let first = project(lat: coords[0].latitude, lon: coords[0].longitude, rect: rect)
            context.move(to: first)

            for i in 1..<coords.count {
                let pt = project(lat: coords[i].latitude, lon: coords[i].longitude, rect: rect)
                let prev = project(lat: coords[i-1].latitude, lon: coords[i-1].longitude, rect: rect)
                if abs(pt.x - prev.x) > rect.width * 0.5 {
                    context.move(to: pt)
                } else {
                    context.addLine(to: pt)
                }
            }

            context.closePath()
            context.setFillColor(fillColor.cgColor)
            context.setStrokeColor(strokeColor.cgColor)
            context.setLineWidth(lineWidth)
            context.drawPath(using: .fillStroke)
        }
    }

    private static func drawPin(in context: CGContext, at point: CGPoint, color: UIColor, small: Bool = false) {
        let pinRadius: CGFloat = small ? 3 : 5
        let pinRect = CGRect(x: point.x - pinRadius, y: point.y - pinRadius,
                             width: pinRadius * 2, height: pinRadius * 2)

        // Drop shadow
        context.saveGState()
        context.setShadow(offset: CGSize(width: 0, height: 1), blur: 2, color: UIColor.black.withAlphaComponent(0.3).cgColor)
        context.setFillColor(color.cgColor)
        context.fillEllipse(in: pinRect)
        context.restoreGState()

        // White border
        context.setStrokeColor(UIColor.white.cgColor)
        context.setLineWidth(small ? 1 : 1.5)
        context.strokeEllipse(in: pinRect)
    }

    private static func centroid(of boundary: GeoJSONParser.CountryBoundary, in rect: CGRect) -> CGPoint {
        // Use the largest polygon's centroid
        var bestPolygon = boundary.polygons.first!
        var bestCount = 0
        for p in boundary.polygons {
            if p.coordinates.count > bestCount {
                bestCount = p.coordinates.count
                bestPolygon = p
            }
        }

        let coords = bestPolygon.coordinates
        var sumLat = 0.0, sumLon = 0.0
        for c in coords {
            sumLat += c.latitude
            sumLon += c.longitude
        }
        let avgLat = sumLat / Double(coords.count)
        let avgLon = sumLon / Double(coords.count)
        return project(lat: avgLat, lon: avgLon, rect: rect)
    }

    // MARK: - Miller Cylindrical Projection

    private static func project(lat: Double, lon: Double, rect: CGRect) -> CGPoint {
        let x = (lon + 180.0) / 360.0
        let latRad = lat * .pi / 180.0
        let millerY = 1.25 * log(tan(.pi / 4.0 + 0.4 * latRad))
        let yNorm = (1.0 - millerY / 2.3) / 2.0
        let clampedX = max(0, min(1, x))
        let clampedY = max(0, min(1, yNorm))
        return CGPoint(
            x: rect.origin.x + clampedX * rect.width,
            y: rect.origin.y + clampedY * rect.height
        )
    }

    // MARK: - Title & Footer

    private static func drawTitle(in context: CGContext, size: CGSize, titleHeight: CGFloat,
                                  scheme: PosterColorScheme, title: String) {
        let font = UIFont.systemFont(ofSize: titleHeight * 0.38, weight: .bold)
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: scheme.textColor]
        let str = NSAttributedString(string: title, attributes: attrs)
        let strSize = str.size()
        let origin = CGPoint(x: (size.width - strSize.width) / 2, y: (titleHeight - strSize.height) / 2)
        UIGraphicsPushContext(context)
        str.draw(at: origin)
        UIGraphicsPopContext()
    }

    private static func drawFooter(in context: CGContext, size: CGSize, footerHeight: CGFloat,
                                   scheme: PosterColorScheme, subtitle: String) {
        let footerY = size.height - footerHeight
        let font = UIFont.systemFont(ofSize: footerHeight * 0.28, weight: .medium)
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: scheme.subtitleColor]
        let str = NSAttributedString(string: subtitle, attributes: attrs)
        let strSize = str.size()
        let origin = CGPoint(x: (size.width - strSize.width) / 2, y: footerY + (footerHeight - strSize.height) / 2)
        UIGraphicsPushContext(context)
        str.draw(at: origin)
        UIGraphicsPopContext()

        // Branding
        let brandFont = UIFont.systemFont(ofSize: footerHeight * 0.18, weight: .regular)
        let brandAttrs: [NSAttributedString.Key: Any] = [
            .font: brandFont, .foregroundColor: scheme.subtitleColor.withAlphaComponent(0.5)
        ]
        let brand = NSAttributedString(string: "Footprint", attributes: brandAttrs)
        let brandSize = brand.size()
        let brandOrigin = CGPoint(x: size.width - brandSize.width - size.width * 0.04,
                                  y: footerY + (footerHeight - brandSize.height) / 2)
        brand.draw(at: brandOrigin)
        UIGraphicsPopContext()
    }
}
