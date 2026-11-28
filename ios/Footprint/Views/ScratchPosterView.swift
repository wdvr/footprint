import SwiftUI
import UIKit

/// Design and export the printable scratch-map poster.
struct ScratchPosterView: View {
    let visitedPlaces: [VisitedPlace]

    @Environment(\.dismiss) private var dismiss
    @State private var title = "My Scratch Map"
    @State private var theme: ScratchPosterTheme = .gold
    @State private var size: ScratchPosterSize = .a2
    @State private var preview: UIImage?
    @State private var exporting: ExportKind?
    @State private var exportedURL: URL?
    @State private var showShareSheet = false
    @State private var showFullScreen = false
    @State private var errorMessage: String?

    private enum ExportKind { case pdf, png }

    private var content: ScratchPosterContent {
        ScratchPosterContent.make(title: title.isEmpty ? "My Scratch Map" : title, places: visitedPlaces)
    }

    private var renderKey: String {
        let c = content
        return "\(theme.rawValue)|\(size.rawValue)|\(c.title)|\(c.visitedCountryCodes.sorted())|\(c.visitedStateCodes.sorted())"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    posterPreview
                    section("Title") {
                        TextField("My Scratch Map", text: $title)
                            .textFieldStyle(.roundedBorder)
                            .submitLabel(.done)
                    }
                    section("Foil") {
                        HStack(spacing: 14) {
                            ForEach(ScratchPosterTheme.allCases) { option in themeButton(option) }
                        }
                    }
                    section("Paper") {
                        Picker("Paper", selection: $size) {
                            ForEach(ScratchPosterSize.allCases) { Text($0.displayName).tag($0) }
                        }
                        .pickerStyle(.menu)
                        Text(sizeDescription)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    exportButtons
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Scratch Map Poster")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } }
            }
            .task(id: renderKey) { await renderPreview() }
            .sheet(isPresented: $showShareSheet) {
                if let exportedURL { ActivityViewController(activityItems: [exportedURL]) }
            }
            .fullScreenCover(isPresented: $showFullScreen) { PosterZoomView(image: preview) }
            .alert("Export failed", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
                Button("OK") {}
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    // MARK: - Pieces

    private var posterPreview: some View {
        let page = size.pointSize
        return ZStack {
            if let preview {
                Image(uiImage: preview)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                Color(red: theme.frame.r, green: theme.frame.g, blue: theme.frame.b)
                    .aspectRatio(page.width / page.height, contentMode: .fit)
                    .overlay { ProgressView().tint(.white) }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .shadow(color: .black.opacity(0.25), radius: 10, y: 5)
        .onTapGesture { if preview != nil { showFullScreen = true } }
        .accessibilityLabel("Poster preview. \(content.summary)")
        .accessibilityHint("Double tap to zoom")
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.headline)
            content()
        }
    }

    private func themeButton(_ option: ScratchPosterTheme) -> some View {
        let tones = option.foil
        return Button {
            theme = option
        } label: {
            VStack(spacing: 6) {
                Circle()
                    .fill(LinearGradient(colors: [tones.light, tones.mid, tones.dark, tones.mid].map { Color(red: $0.r, green: $0.g, blue: $0.b) },
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 44, height: 44)
                    .overlay(Circle().stroke(theme == option ? Color.accentColor : .clear, lineWidth: 3).padding(-4))
                Text(option.displayName)
                    .font(.caption.weight(theme == option ? .semibold : .regular))
                    .foregroundStyle(theme == option ? .primary : .secondary)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(option.displayName) foil")
        .accessibilityAddTraits(theme == option ? .isSelected : [])
    }

    private var sizeDescription: String {
        let mm = size.millimetres
        let image = size.printImage
        return "\(Int(mm.long)) × \(Int(mm.short)) mm landscape. The PDF is vector, sharp at any print size; "
            + "the PNG is \(Int(image.size.width)) × \(Int(image.size.height)) px (\(image.dpi) dpi)."
    }

    private var exportButtons: some View {
        VStack(spacing: 12) {
            exportButton("Export print-ready PDF", systemImage: "printer.fill", kind: .pdf, prominent: true)
            exportButton("Export PNG image", systemImage: "photo", kind: .png, prominent: false)
        }
        .disabled(exporting != nil)
    }

    private func exportButton(_ label: String, systemImage: String, kind: ExportKind, prominent: Bool) -> some View {
        Button {
            Task { await export(kind) }
        } label: {
            HStack {
                if exporting == kind { ProgressView() } else { Image(systemName: systemImage) }
                Text(label)
            }
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
        }
        .buttonStyle(.bordered)
        .tint(prominent ? .accentColor : .secondary)
        .controlSize(.large)
    }

    // MARK: - Rendering

    private func renderPreview() async {
        try? await Task.sleep(for: .milliseconds(250))
        guard !Task.isCancelled else { return }
        let content = content, theme = theme, size = size
        let image = await Task.detached(priority: .userInitiated) {
            ScratchPosterRenderer.renderImage(content, theme: theme, size: size, pixelWidth: 1800)
        }.value
        guard !Task.isCancelled else { return }
        preview = image
    }

    private func export(_ kind: ExportKind) async {
        exporting = kind
        defer { exporting = nil }
        let content = content, theme = theme, size = size
        let name = content.title.components(separatedBy: CharacterSet.alphanumerics.inverted).filter { !$0.isEmpty }
            .joined(separator: "-")
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(name.isEmpty ? "Scratch-Map" : name)-\(size.rawValue.uppercased())")
            .appendingPathExtension(kind == .pdf ? "pdf" : "png")
        let data: Data? = await Task.detached(priority: .userInitiated) {
            switch kind {
            case .pdf:
                return ScratchPosterRenderer.renderPDF(content, theme: theme, size: size)
            case .png:
                return ScratchPosterRenderer.renderImage(content, theme: theme, size: size,
                                                         pixelWidth: size.printImage.size.width).pngData()
            }
        }.value
        do {
            guard let data else { throw CocoaError(.fileWriteUnknown) }
            try data.write(to: url, options: .atomic)
            exportedURL = url
            showShareSheet = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

/// Full-screen pinch-to-zoom look at the poster.
struct PosterZoomView: View {
    let image: UIImage?
    @Environment(\.dismiss) private var dismiss
    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .scaleEffect(scale)
                    .offset(offset)
                    .gesture(
                        MagnifyGesture()
                            .onChanged { scale = max(1, lastScale * $0.magnification) }
                            .onEnded { _ in
                                lastScale = scale
                                if scale == 1 { offset = .zero; lastOffset = .zero }
                            }
                            .simultaneously(with: DragGesture()
                                .onChanged { value in
                                    guard scale > 1 else { return }
                                    offset = CGSize(width: lastOffset.width + value.translation.width,
                                                    height: lastOffset.height + value.translation.height)
                                }
                                .onEnded { _ in lastOffset = offset })
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
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            Button { dismiss() } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.white)
                    .padding()
            }
            .accessibilityLabel("Close")
        }
        .statusBarHidden()
    }
}

#Preview {
    ScratchPosterView(visitedPlaces: [])
}
