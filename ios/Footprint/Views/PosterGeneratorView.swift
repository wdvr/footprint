import CoreGraphics
import MapKit
import SwiftUI
import UIKit

// MARK: - Poster Color Scheme

enum PosterColorScheme: String, CaseIterable, Identifiable {
    case light
    case dark
    case classic
    case ocean

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .light: return "Light"
        case .dark: return "Dark"
        case .classic: return "Classic"
        case .ocean: return "Ocean"
        }
    }

    var backgroundColor: UIColor {
        switch self {
        case .light: return UIColor(white: 0.97, alpha: 1)
        case .dark: return UIColor(red: 0.08, green: 0.08, blue: 0.12, alpha: 1)
        case .classic: return UIColor(red: 0.95, green: 0.93, blue: 0.88, alpha: 1)
        case .ocean: return UIColor(red: 0.06, green: 0.10, blue: 0.18, alpha: 1)
        }
    }

    var landColor: UIColor {
        switch self {
        case .light: return UIColor(white: 0.85, alpha: 1)
        case .dark: return UIColor(white: 0.20, alpha: 1)
        case .classic: return UIColor(red: 0.82, green: 0.78, blue: 0.70, alpha: 1)
        case .ocean: return UIColor(red: 0.15, green: 0.22, blue: 0.32, alpha: 1)
        }
    }

    var visitedColor: UIColor {
        switch self {
        case .light: return UIColor(red: 0.20, green: 0.55, blue: 0.85, alpha: 1)
        case .dark: return UIColor(red: 0.30, green: 0.70, blue: 0.95, alpha: 1)
        case .classic: return UIColor(red: 0.70, green: 0.25, blue: 0.20, alpha: 1)
        case .ocean: return UIColor(red: 0.20, green: 0.75, blue: 0.65, alpha: 1)
        }
    }

    var borderColor: UIColor {
        switch self {
        case .light: return UIColor(white: 0.70, alpha: 1)
        case .dark: return UIColor(white: 0.30, alpha: 1)
        case .classic: return UIColor(red: 0.65, green: 0.60, blue: 0.52, alpha: 1)
        case .ocean: return UIColor(red: 0.10, green: 0.18, blue: 0.28, alpha: 1)
        }
    }

    var textColor: UIColor {
        switch self {
        case .light: return UIColor(white: 0.15, alpha: 1)
        case .dark: return UIColor(white: 0.90, alpha: 1)
        case .classic: return UIColor(red: 0.25, green: 0.22, blue: 0.18, alpha: 1)
        case .ocean: return UIColor(white: 0.90, alpha: 1)
        }
    }

    var subtitleColor: UIColor {
        switch self {
        case .light: return UIColor(white: 0.45, alpha: 1)
        case .dark: return UIColor(white: 0.55, alpha: 1)
        case .classic: return UIColor(red: 0.50, green: 0.45, blue: 0.38, alpha: 1)
        case .ocean: return UIColor(white: 0.55, alpha: 1)
        }
    }

    var swiftUIBackground: Color {
        Color(backgroundColor)
    }

    var swiftUIVisited: Color {
        Color(visitedColor)
    }

    var swiftUILand: Color {
        Color(landColor)
    }

    var swiftUIText: Color {
        Color(textColor)
    }

    var swiftUISubtitle: Color {
        Color(subtitleColor)
    }
}

// MARK: - Poster Size

enum PosterSize: String, CaseIterable, Identifiable {
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

    /// PDF dimensions in points (72 dpi)
    var pdfSize: CGSize {
        switch self {
        case .a3: return CGSize(width: 842, height: 1191)   // landscape: 1191 x 842
        case .a2: return CGSize(width: 1191, height: 1684)
        case .a1: return CGSize(width: 1684, height: 2384)
        }
    }

    /// Landscape PDF size
    var landscapeSize: CGSize {
        CGSize(width: pdfSize.height, height: pdfSize.width)
    }
}

// MARK: - Poster Renderer

/// Renders a high-resolution world map poster as PDF with visited countries highlighted.
/// Uses a Miller cylindrical projection for a visually balanced flat map.
final class PosterRenderer {
    let visitedCountryCodes: Set<String>
    let colorScheme: PosterColorScheme
    let posterSize: PosterSize
    let title: String
    let subtitle: String
    let countriesVisited: Int
    let continentsVisited: Int

    private var boundaries: [GeoJSONParser.CountryBoundary] = []

    init(
        visitedCountryCodes: Set<String>,
        colorScheme: PosterColorScheme,
        posterSize: PosterSize,
        title: String,
        subtitle: String,
        countriesVisited: Int,
        continentsVisited: Int
    ) {
        self.visitedCountryCodes = visitedCountryCodes
        self.colorScheme = colorScheme
        self.posterSize = posterSize
        self.title = title
        self.subtitle = subtitle
        self.countriesVisited = countriesVisited
        self.continentsVisited = continentsVisited
    }

    /// Generate a PDF Data object containing the poster
    func renderPDF() -> Data? {
        boundaries = GeoJSONParser.parseCountries()
        guard !boundaries.isEmpty else { return nil }

        let pageSize = posterSize.landscapeSize
        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = [
            kCGPDFContextTitle as String: title,
            kCGPDFContextCreator as String: "Footprint Travel Tracker",
        ]

        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(origin: .zero, size: pageSize), format: format)

        let data = renderer.pdfData { context in
            context.beginPage()
            let cgContext = context.cgContext

            // Background
            cgContext.setFillColor(colorScheme.backgroundColor.cgColor)
            cgContext.fill(CGRect(origin: .zero, size: pageSize))

            // Map area: leave margins for title and footer
            let titleHeight: CGFloat = pageSize.height * 0.08
            let footerHeight: CGFloat = pageSize.height * 0.06
            let sideMargin: CGFloat = pageSize.width * 0.04
            let mapRect = CGRect(
                x: sideMargin,
                y: titleHeight,
                width: pageSize.width - sideMargin * 2,
                height: pageSize.height - titleHeight - footerHeight
            )

            // Draw the map
            drawMap(in: cgContext, rect: mapRect)

            // Draw title
            drawTitle(in: cgContext, pageSize: pageSize, titleHeight: titleHeight)

            // Draw footer
            drawFooter(in: cgContext, pageSize: pageSize, footerHeight: footerHeight)
        }

        return data
    }

    /// Render a preview UIImage at moderate resolution
    func renderPreviewImage(width: CGFloat = 800) -> UIImage? {
        boundaries = GeoJSONParser.parseCountries()
        guard !boundaries.isEmpty else { return nil }

        let pageSize = posterSize.landscapeSize
        let scale = width / pageSize.width
        let imageSize = CGSize(width: width, height: pageSize.height * scale)

        let renderer = UIGraphicsImageRenderer(size: imageSize)
        return renderer.image { context in
            let cgContext = context.cgContext

            cgContext.scaleBy(x: scale, y: scale)

            // Background
            cgContext.setFillColor(colorScheme.backgroundColor.cgColor)
            cgContext.fill(CGRect(origin: .zero, size: pageSize))

            let titleHeight: CGFloat = pageSize.height * 0.08
            let footerHeight: CGFloat = pageSize.height * 0.06
            let sideMargin: CGFloat = pageSize.width * 0.04
            let mapRect = CGRect(
                x: sideMargin,
                y: titleHeight,
                width: pageSize.width - sideMargin * 2,
                height: pageSize.height - titleHeight - footerHeight
            )

            drawMap(in: cgContext, rect: mapRect)
            drawTitle(in: cgContext, pageSize: pageSize, titleHeight: titleHeight)
            drawFooter(in: cgContext, pageSize: pageSize, footerHeight: footerHeight)
        }
    }

    // MARK: - Map Drawing

    private func drawMap(in context: CGContext, rect: CGRect) {
        // Clip to map area
        context.saveGState()

        for boundary in boundaries {
            let isVisited = visitedCountryCodes.contains(boundary.id)
            let fillColor = isVisited ? colorScheme.visitedColor : colorScheme.landColor
            let strokeColor = colorScheme.borderColor

            for polygon in boundary.polygons {
                let coords = polygon.coordinates
                guard coords.count >= 3 else { continue }

                context.beginPath()
                let firstPoint = projectToRect(lat: coords[0].latitude, lon: coords[0].longitude, rect: rect)
                context.move(to: firstPoint)

                for i in 1..<coords.count {
                    let point = projectToRect(lat: coords[i].latitude, lon: coords[i].longitude, rect: rect)
                    // Skip points that jump across the map (antimeridian crossing)
                    let prevPoint = projectToRect(lat: coords[i - 1].latitude, lon: coords[i - 1].longitude, rect: rect)
                    if abs(point.x - prevPoint.x) > rect.width * 0.5 {
                        context.move(to: point)
                    } else {
                        context.addLine(to: point)
                    }
                }

                context.closePath()
                context.setFillColor(fillColor.cgColor)
                context.setStrokeColor(strokeColor.cgColor)
                context.setLineWidth(0.3)
                context.drawPath(using: .fillStroke)
            }
        }

        context.restoreGState()
    }

    /// Miller cylindrical projection: maps lat/lon to x/y within the given rect
    private func projectToRect(lat: Double, lon: Double, rect: CGRect) -> CGPoint {
        // Miller cylindrical projection
        let x = (lon + 180.0) / 360.0
        let latRad = lat * .pi / 180.0
        let millerY = 1.25 * log(tan(.pi / 4.0 + 0.4 * latRad))
        // Normalize to 0..1 range (Miller y spans roughly -2.3 to 2.3)
        let yNorm = (1.0 - millerY / 2.3) / 2.0

        // Clamp to map bounds
        let clampedX = max(0, min(1, x))
        let clampedY = max(0, min(1, yNorm))

        return CGPoint(
            x: rect.origin.x + clampedX * rect.width,
            y: rect.origin.y + clampedY * rect.height
        )
    }

    // MARK: - Title Drawing

    private func drawTitle(in context: CGContext, pageSize: CGSize, titleHeight: CGFloat) {
        let titleFont = UIFont.systemFont(ofSize: titleHeight * 0.38, weight: .bold)
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: titleFont,
            .foregroundColor: colorScheme.textColor,
        ]
        let titleString = NSAttributedString(string: title, attributes: titleAttributes)
        let titleSize = titleString.size()
        let titleOrigin = CGPoint(
            x: (pageSize.width - titleSize.width) / 2,
            y: (titleHeight - titleSize.height) / 2
        )

        // Push/pop UIKit graphics for attributed string drawing
        UIGraphicsPushContext(context)
        titleString.draw(at: titleOrigin)
        UIGraphicsPopContext()
    }

    // MARK: - Footer Drawing

    private func drawFooter(in context: CGContext, pageSize: CGSize, footerHeight: CGFloat) {
        let footerY = pageSize.height - footerHeight

        let statsFont = UIFont.systemFont(ofSize: footerHeight * 0.28, weight: .medium)
        let statsAttributes: [NSAttributedString.Key: Any] = [
            .font: statsFont,
            .foregroundColor: colorScheme.subtitleColor,
        ]
        let statsText = subtitle
        let statsString = NSAttributedString(string: statsText, attributes: statsAttributes)
        let statsSize = statsString.size()
        let statsOrigin = CGPoint(
            x: (pageSize.width - statsSize.width) / 2,
            y: footerY + (footerHeight - statsSize.height) / 2
        )

        UIGraphicsPushContext(context)
        statsString.draw(at: statsOrigin)
        UIGraphicsPopContext()

        // Branding in bottom-right corner
        let brandFont = UIFont.systemFont(ofSize: footerHeight * 0.18, weight: .regular)
        let brandAttributes: [NSAttributedString.Key: Any] = [
            .font: brandFont,
            .foregroundColor: colorScheme.subtitleColor.withAlphaComponent(0.5),
        ]
        let brandString = NSAttributedString(string: "Footprint", attributes: brandAttributes)
        let brandSize = brandString.size()
        let brandOrigin = CGPoint(
            x: pageSize.width - brandSize.width - pageSize.width * 0.04,
            y: footerY + (footerHeight - brandSize.height) / 2
        )

        UIGraphicsPushContext(context)
        brandString.draw(at: brandOrigin)
        UIGraphicsPopContext()
    }
}

// MARK: - MKPolygon coordinate access extension

extension MKPolygon {
    /// Extract coordinates from the polygon
    var coordinates: [CLLocationCoordinate2D] {
        var coords = [CLLocationCoordinate2D](repeating: kCLLocationCoordinate2DInvalid, count: pointCount)
        getCoordinates(&coords, range: NSRange(location: 0, length: pointCount))
        return coords
    }
}

// MARK: - Poster Preview (SwiftUI)

/// A SwiftUI view rendering a small preview of the poster
struct PosterPreviewView: View {
    let visitedCountryCodes: Set<String>
    let colorScheme: PosterColorScheme
    let posterSize: PosterSize
    let title: String
    let subtitle: String
    let countriesVisited: Int
    let continentsVisited: Int

    @State private var previewImage: UIImage?

    var body: some View {
        Group {
            if let image = previewImage {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .shadow(color: .black.opacity(0.2), radius: 8, y: 4)
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(colorScheme.swiftUIBackground)
                    .aspectRatio(posterSize.landscapeSize.width / posterSize.landscapeSize.height, contentMode: .fit)
                    .overlay {
                        ProgressView()
                    }
            }
        }
        .task(id: "\(colorScheme.rawValue)-\(posterSize.rawValue)-\(visitedCountryCodes.count)-\(title)") {
            await generatePreview()
        }
    }

    @MainActor
    private func generatePreview() async {
        // Run rendering off main actor
        let renderer = PosterRenderer(
            visitedCountryCodes: visitedCountryCodes,
            colorScheme: colorScheme,
            posterSize: posterSize,
            title: title,
            subtitle: subtitle,
            countriesVisited: countriesVisited,
            continentsVisited: continentsVisited
        )
        previewImage = renderer.renderPreviewImage(width: 800)
    }
}

// MARK: - Poster Generator View

/// Main view for configuring and exporting a printable travel map poster
struct PosterGeneratorView: View {
    let visitedPlaces: [VisitedPlace]
    @Environment(\.dismiss) private var dismiss

    @State private var selectedColorScheme: PosterColorScheme = .light
    @State private var selectedSize: PosterSize = .a2
    @State private var posterTitle: String = "My Travel Map"
    @State private var isExporting = false
    @State private var showShareSheet = false
    @State private var exportedPDFURL: URL?
    @State private var showError = false
    @State private var errorMessage = ""

    private var visitedCountryCodes: Set<String> {
        Set(
            visitedPlaces
                .filter {
                    $0.regionType == VisitedPlace.RegionType.country.rawValue
                        && !$0.isDeleted
                        && $0.isVisited
                }
                .map { $0.regionCode }
        )
    }

    private var countriesVisited: Int {
        visitedCountryCodes.count
    }

    private var continentsVisited: Int {
        let stats = LocalContinentStats.calculateStats(visitedCountries: Array(visitedCountryCodes))
        return stats.filter { $0.visited > 0 }.count
    }

    private var subtitle: String {
        "\(countriesVisited) countries visited across \(continentsVisited) continents"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Preview
                    PosterPreviewView(
                        visitedCountryCodes: visitedCountryCodes,
                        colorScheme: selectedColorScheme,
                        posterSize: selectedSize,
                        title: posterTitle,
                        subtitle: subtitle,
                        countriesVisited: countriesVisited,
                        continentsVisited: continentsVisited
                    )
                    .padding(.horizontal)

                    // Title input
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Title")
                            .font(.headline)

                        TextField("My Travel Map", text: $posterTitle)
                            .textFieldStyle(.roundedBorder)
                    }
                    .padding(.horizontal)

                    // Color scheme picker
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Style")
                            .font(.headline)
                            .padding(.horizontal)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(PosterColorScheme.allCases) { scheme in
                                    PosterSchemeButton(
                                        scheme: scheme,
                                        isSelected: selectedColorScheme == scheme
                                    ) {
                                        selectedColorScheme = scheme
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                    }

                    // Size picker
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Paper Size")
                            .font(.headline)

                        Picker("Paper Size", selection: $selectedSize) {
                            ForEach(PosterSize.allCases) { size in
                                Text(size.displayName).tag(size)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                    .padding(.horizontal)

                    // Export button
                    Button {
                        Task {
                            await exportPDF()
                        }
                    } label: {
                        HStack {
                            if isExporting {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Image(systemName: "arrow.down.doc.fill")
                            }
                            Text("Export PDF")
                        }
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(selectedColorScheme.visitedColor))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .disabled(isExporting)
                    .accessibilityLabel(isExporting ? "Generating poster" : "Export poster as PDF")
                    .padding(.horizontal)
                    .padding(.bottom, 20)
                }
                .padding(.top, 16)
            }
            .navigationTitle("Travel Map Poster")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showShareSheet) {
                if let url = exportedPDFURL {
                    ActivityViewController(activityItems: [url])
                }
            }
            .alert("Export Error", isPresented: $showError) {
                Button("OK") {}
            } message: {
                Text(errorMessage)
            }
        }
    }

    @MainActor
    private func exportPDF() async {
        isExporting = true
        await Task.yield()

        let renderer = PosterRenderer(
            visitedCountryCodes: visitedCountryCodes,
            colorScheme: selectedColorScheme,
            posterSize: selectedSize,
            title: posterTitle,
            subtitle: subtitle,
            countriesVisited: countriesVisited,
            continentsVisited: continentsVisited
        )

        guard let pdfData = renderer.renderPDF() else {
            errorMessage = "Failed to generate the poster. Please try again."
            showError = true
            isExporting = false
            return
        }

        // Write to temporary file for sharing
        let tempDir = FileManager.default.temporaryDirectory
        let sanitizedTitle = posterTitle.replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: "/", with: "-")
        let fileName = "\(sanitizedTitle)_\(selectedSize.rawValue.uppercased()).pdf"
        let fileURL = tempDir.appendingPathComponent(fileName)

        do {
            try pdfData.write(to: fileURL)
            exportedPDFURL = fileURL
            showShareSheet = true
        } catch {
            errorMessage = "Failed to save PDF: \(error.localizedDescription)"
            showError = true
        }

        isExporting = false
    }
}

// MARK: - Poster Scheme Button

struct PosterSchemeButton: View {
    let scheme: PosterColorScheme
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(scheme.swiftUIBackground)
                    .frame(width: 52, height: 36)
                    .overlay(
                        // Mini map dots
                        HStack(spacing: 2) {
                            Circle().fill(scheme.swiftUIVisited).frame(width: 6, height: 6)
                            Circle().fill(scheme.swiftUILand).frame(width: 6, height: 6)
                            Circle().fill(scheme.swiftUIVisited).frame(width: 6, height: 6)
                        }
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(isSelected ? Color.primary : Color.clear, lineWidth: 2)
                    )

                Text(scheme.displayName)
                    .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? .primary : .secondary)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(scheme.displayName) theme")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// MARK: - Previews

#Preview("Poster Generator") {
    PosterGeneratorView(visitedPlaces: [])
}
