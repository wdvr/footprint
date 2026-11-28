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

/// A small on-screen render of the poster, regenerated off the main thread when inputs change.
struct PosterPreviewView: View {
    let model: ScratchPosterModel
    let colorScheme: PosterColorScheme
    let posterSize: PosterSize

    @State private var previewImage: UIImage?

    var body: some View {
        Group {
            if let image = previewImage {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .shadow(color: .black.opacity(0.2), radius: 8, y: 4)
                    .accessibilityLabel("Poster preview: \(model.subtitle)")
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(colorScheme.swiftUIBackground)
                    .aspectRatio(posterSize.landscapeSize.width / posterSize.landscapeSize.height, contentMode: .fit)
                    .overlay {
                        ProgressView()
                    }
            }
        }
        .task(id: PreviewKey(model: model, scheme: colorScheme, size: posterSize)) {
            let model = model
            let scheme = colorScheme
            let size = posterSize
            let image = await Task.detached(priority: .userInitiated) {
                ScratchPosterRenderer.previewImage(model: model, scheme: scheme, size: size, width: 1000)
            }.value
            guard !Task.isCancelled else { return }
            previewImage = image
        }
    }

    private struct PreviewKey: Equatable {
        let model: ScratchPosterModel
        let scheme: PosterColorScheme
        let size: PosterSize
    }
}

// MARK: - Poster Generator View

/// Configures and exports the printable scratch-map poster as a vector PDF or a print-resolution PNG.
struct PosterGeneratorView: View {
    let visitedPlaces: [VisitedPlace]
    @Environment(\.dismiss) private var dismiss

    @State private var selectedColorScheme: PosterColorScheme = .light
    @State private var selectedSize: PosterSize = .a2
    @State private var posterTitle: String = "My Travel Map"
    @State private var exportingFormat: ExportFormat?
    @State private var exportedFile: ExportedFile?
    @State private var showError = false
    @State private var errorMessage = ""

    enum ExportFormat: String {
        case pdf, png
    }

    private struct ExportedFile: Identifiable {
        let url: URL
        var id: URL { url }
    }

    /// Countries the user tracks at state/province level, as configured in Settings.
    private var trackedCountries: Set<String> {
        Set(
            AppSettings.supportedStateCountries
                .map(\.code)
                .filter { AppSettings.shared.shouldTrackStates(for: $0) }
        )
    }

    private var model: ScratchPosterModel {
        ScratchPosterModel(places: visitedPlaces, trackedCountries: trackedCountries, title: posterTitle)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    PosterPreviewView(
                        model: model,
                        colorScheme: selectedColorScheme,
                        posterSize: selectedSize
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

                        Text(sizeDescription)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal)

                    VStack(spacing: 12) {
                        exportButton(
                            .pdf, title: "Export PDF", systemImage: "arrow.down.doc.fill",
                            accessibility: "Export poster as PDF", filled: true
                        )
                        exportButton(
                            .png, title: "Export PNG", systemImage: "photo.fill",
                            accessibility: "Export poster as high-resolution PNG", filled: false
                        )
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 20)
                }
                .padding(.top, 16)
            }
            .navigationTitle("Scratch Map Poster")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .sheet(item: $exportedFile) { file in
                ActivityViewController(activityItems: [file.url])
            }
            .alert("Export Error", isPresented: $showError) {
                Button("OK") {}
            } message: {
                Text(errorMessage)
            }
        }
    }

    private var sizeDescription: String {
        let pixels = selectedSize.pngPixelSize
        return "PDF is vector. PNG is \(Int(pixels.width)) × \(Int(pixels.height)) px at \(Int(selectedSize.pngDPI)) dpi."
    }

    private func exportButton(
        _ format: ExportFormat, title: String, systemImage: String, accessibility: String, filled: Bool
    ) -> some View {
        let tint = Color(red: 0.20, green: 0.78, blue: 0.35)
        return Button {
            Task { await export(format) }
        } label: {
            HStack {
                if exportingFormat == format {
                    ProgressView()
                        .tint(filled ? .white : tint)
                } else {
                    Image(systemName: systemImage)
                }
                Text(title)
            }
            .font(.headline)
            .foregroundStyle(filled ? .white : tint)
            .frame(maxWidth: .infinity)
            .padding()
            .background(filled ? tint : tint.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .disabled(exportingFormat != nil)
        .accessibilityLabel(exportingFormat == format ? "Generating poster" : accessibility)
    }

    @MainActor
    private func export(_ format: ExportFormat) async {
        exportingFormat = format
        defer { exportingFormat = nil }

        let model = model
        let scheme = selectedColorScheme
        let size = selectedSize
        let data = await Task.detached(priority: .userInitiated) { () -> Data? in
            switch format {
            case .pdf: return ScratchPosterRenderer.pdfData(model: model, scheme: scheme, size: size)
            case .png: return ScratchPosterRenderer.pngData(model: model, scheme: scheme, size: size)
            }
        }.value

        guard let data else {
            errorMessage = "Failed to generate the poster. Please try again."
            showError = true
            return
        }

        let sanitizedTitle = posterTitle
            .replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: "/", with: "-")
        let baseName = sanitizedTitle.isEmpty ? "Footprint_Poster" : sanitizedTitle
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(baseName)_\(size.rawValue.uppercased()).\(format.rawValue)")

        do {
            try data.write(to: fileURL)
            exportedFile = ExportedFile(url: fileURL)
        } catch {
            errorMessage = "Failed to save the poster: \(error.localizedDescription)"
            showError = true
        }
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
