import MapKit
import SwiftData
import SwiftUI

/// A full-screen world map export view that renders all visited countries
/// on a single shareable image
struct WorldMapExportView: View {
    let visitedCountryCodes: Set<String>
    let bucketListCountryCodes: Set<String>
    let visitedStateCodes: Set<String>
    let bucketListStateCodes: Set<String>
    let visitedPlaces: [VisitedPlace]

    @Environment(\.dismiss) private var dismiss
    @State private var renderedImage: UIImage?
    @State private var isRendering = true
    @State private var showShareSheet = false

    private var countryCount: Int {
        visitedCountryCodes.count
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()

                if let image = renderedImage {
                    VStack(spacing: 16) {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .shadow(radius: 8)
                            .padding(.horizontal)

                        Text("\(countryCount) countries visited")
                            .font(.headline)
                            .foregroundStyle(.secondary)

                        Button {
                            showShareSheet = true
                        } label: {
                            Label("Share Map", systemImage: "square.and.arrow.up")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(.blue)
                                .foregroundStyle(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .padding(.horizontal)
                    }
                } else {
                    VStack(spacing: 12) {
                        ProgressView()
                            .scaleEffect(1.5)
                        Text("Rendering world map...")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("World Map")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                if renderedImage != nil {
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            showShareSheet = true
                        } label: {
                            Image(systemName: "square.and.arrow.up")
                        }
                    }
                }
            }
            .sheet(isPresented: $showShareSheet) {
                if let image = renderedImage {
                    ActivityViewController(activityItems: [image])
                }
            }
            .task {
                await renderMap()
            }
        }
    }

    private func renderMap() async {
        let image = await WorldMapRenderer.render(
            visitedCountryCodes: visitedCountryCodes,
            bucketListCountryCodes: bucketListCountryCodes,
            visitedStateCodes: visitedStateCodes,
            bucketListStateCodes: bucketListStateCodes
        )
        await MainActor.run {
            renderedImage = image
            isRendering = false
        }
    }
}

/// Renders a high-resolution world map image with country overlays
enum WorldMapRenderer {
    static func render(
        visitedCountryCodes: Set<String>,
        bucketListCountryCodes: Set<String>,
        visitedStateCodes: Set<String>,
        bucketListStateCodes: Set<String>
    ) async -> UIImage {
        // Use MKMapSnapshotter for the base map
        let size = CGSize(width: 2400, height: 1200)

        let options = MKMapSnapshotter.Options()
        options.region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 20, longitude: 0),
            span: MKCoordinateSpan(latitudeDelta: 150, longitudeDelta: 360)
        )
        options.size = size
        options.mapType = .mutedStandard
        options.showsBuildings = false
        options.pointOfInterestFilter = .excludingAll

        let snapshotter = MKMapSnapshotter(options: options)

        do {
            let snapshot = try await snapshotter.start()
            let baseImage = snapshot.image

            // Parse boundaries
            let countryBoundaries = GeoJSONParser.parseCountries()
            let usStates = GeoJSONParser.parseUSStates()
            let caProvinces = GeoJSONParser.parseCanadianProvinces()

            // Draw overlays on top of the snapshot
            let renderer = UIGraphicsImageRenderer(size: size)
            let finalImage = renderer.image { ctx in
                // Draw base map
                baseImage.draw(at: .zero)

                let context = ctx.cgContext

                // Draw country overlays
                for boundary in countryBoundaries {
                    let code = boundary.id
                    let normalizedCode = normalizedCountryCode(code)
                    let isVisited = visitedCountryCodes.contains(normalizedCode)
                    let isBucketList = bucketListCountryCodes.contains(normalizedCode)

                    // For US/CA, just draw border (states shown separately)
                    if code == "US" || code == "CA" {
                        if isVisited {
                            drawOverlay(
                                boundary.overlay, on: snapshot, in: context,
                                fillColor: .clear,
                                strokeColor: UIColor.systemGreen.withAlphaComponent(0.8),
                                lineWidth: 1.5
                            )
                        }
                        continue
                    }

                    if isVisited {
                        drawOverlay(
                            boundary.overlay, on: snapshot, in: context,
                            fillColor: UIColor.systemGreen.withAlphaComponent(0.4),
                            strokeColor: UIColor.systemGreen.withAlphaComponent(0.8),
                            lineWidth: 1.5
                        )
                    } else if isBucketList {
                        drawOverlay(
                            boundary.overlay, on: snapshot, in: context,
                            fillColor: UIColor.systemOrange.withAlphaComponent(0.4),
                            strokeColor: UIColor.systemOrange.withAlphaComponent(0.8),
                            lineWidth: 1.5
                        )
                    }
                }

                // Draw US state overlays
                for state in usStates {
                    let code = "US-\(state.id)"
                    let isVisited = visitedStateCodes.contains(code)
                    let isBucketList = bucketListStateCodes.contains(code)

                    if isVisited {
                        drawOverlay(
                            state.overlay, on: snapshot, in: context,
                            fillColor: UIColor.systemGreen.withAlphaComponent(0.4),
                            strokeColor: UIColor.systemGreen.withAlphaComponent(0.8),
                            lineWidth: 0.5
                        )
                    } else if isBucketList {
                        drawOverlay(
                            state.overlay, on: snapshot, in: context,
                            fillColor: UIColor.systemOrange.withAlphaComponent(0.4),
                            strokeColor: UIColor.systemOrange.withAlphaComponent(0.8),
                            lineWidth: 0.5
                        )
                    }
                }

                // Draw Canadian province overlays
                for province in caProvinces {
                    let code = "CA-\(province.id)"
                    let isVisited = visitedStateCodes.contains(code)
                    let isBucketList = bucketListStateCodes.contains(code)

                    if isVisited {
                        drawOverlay(
                            province.overlay, on: snapshot, in: context,
                            fillColor: UIColor.systemGreen.withAlphaComponent(0.4),
                            strokeColor: UIColor.systemGreen.withAlphaComponent(0.8),
                            lineWidth: 0.5
                        )
                    } else if isBucketList {
                        drawOverlay(
                            province.overlay, on: snapshot, in: context,
                            fillColor: UIColor.systemOrange.withAlphaComponent(0.4),
                            strokeColor: UIColor.systemOrange.withAlphaComponent(0.8),
                            lineWidth: 0.5
                        )
                    }
                }

                // Draw legend and title
                drawLegend(
                    in: context, size: size,
                    visitedCount: visitedCountryCodes.count,
                    bucketListCount: bucketListCountryCodes.count
                )
            }

            return finalImage
        } catch {
            // Fallback: return a placeholder
            let renderer = UIGraphicsImageRenderer(size: CGSize(width: 800, height: 400))
            return renderer.image { ctx in
                UIColor.systemBackground.setFill()
                ctx.fill(CGRect(origin: .zero, size: CGSize(width: 800, height: 400)))
                let text = "Failed to render map"
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 24),
                    .foregroundColor: UIColor.label,
                ]
                text.draw(at: CGPoint(x: 300, y: 180), withAttributes: attrs)
            }
        }
    }

    private static func drawOverlay(
        _ multiPolygon: MKMultiPolygon,
        on snapshot: MKMapSnapshotter.Snapshot,
        in context: CGContext,
        fillColor: UIColor,
        strokeColor: UIColor,
        lineWidth: CGFloat
    ) {
        for polygon in multiPolygon.polygons {
            let points = polygon.points()
            let pointCount = polygon.pointCount
            guard pointCount > 0 else { continue }

            let path = CGMutablePath()
            for i in 0..<pointCount {
                let coordinate = points[i].coordinate
                let point = snapshot.point(for: coordinate)
                if i == 0 {
                    path.move(to: point)
                } else {
                    path.addLine(to: point)
                }
            }
            path.closeSubpath()

            // Draw interior polygons (holes)
            let interiorPolygons = polygon.interiorPolygons ?? []
            for i in 0..<interiorPolygons.count {
                let interior = interiorPolygons[i]
                let interiorPoints = interior.points()
                let interiorCount = interior.pointCount
                for j in 0..<interiorCount {
                    let coord = interiorPoints[j].coordinate
                    let pt = snapshot.point(for: coord)
                    if j == 0 {
                        path.move(to: pt)
                    } else {
                        path.addLine(to: pt)
                    }
                }
                path.closeSubpath()
            }

            context.addPath(path)
            context.setFillColor(fillColor.cgColor)
            context.fillPath()

            context.addPath(path)
            context.setStrokeColor(strokeColor.cgColor)
            context.setLineWidth(lineWidth)
            context.strokePath()
        }
    }

    private static func drawLegend(
        in context: CGContext, size: CGSize,
        visitedCount: Int, bucketListCount: Int
    ) {
        // Title
        let title = "My Footprint"
        let titleAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 36, weight: .bold),
            .foregroundColor: UIColor.label,
        ]
        title.draw(at: CGPoint(x: 24, y: 16), withAttributes: titleAttrs)

        // Stats
        let stats = "\(visitedCount) countries"
        if bucketListCount > 0 {
            let fullStats = "\(visitedCount) countries visited · \(bucketListCount) on bucket list"
            let statsAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 20, weight: .medium),
                .foregroundColor: UIColor.secondaryLabel,
            ]
            fullStats.draw(at: CGPoint(x: 24, y: 58), withAttributes: statsAttrs)
        } else {
            let statsAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 20, weight: .medium),
                .foregroundColor: UIColor.secondaryLabel,
            ]
            stats.draw(at: CGPoint(x: 24, y: 58), withAttributes: statsAttrs)
        }

        // Legend squares
        let legendY = size.height - 40
        let squareSize: CGFloat = 16

        // Visited
        context.setFillColor(UIColor.systemGreen.withAlphaComponent(0.5).cgColor)
        context.fill(CGRect(x: 24, y: legendY, width: squareSize, height: squareSize))
        let visitedLabel = "Visited"
        let legendAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 14, weight: .medium),
            .foregroundColor: UIColor.secondaryLabel,
        ]
        visitedLabel.draw(at: CGPoint(x: 46, y: legendY - 1), withAttributes: legendAttrs)

        // Bucket list
        if bucketListCount > 0 {
            context.setFillColor(UIColor.systemOrange.withAlphaComponent(0.5).cgColor)
            context.fill(CGRect(x: 110, y: legendY, width: squareSize, height: squareSize))
            let bucketLabel = "Bucket List"
            bucketLabel.draw(at: CGPoint(x: 132, y: legendY - 1), withAttributes: legendAttrs)
        }
    }
}

/// Helper to normalize country codes (same as CountryMapView)
private func normalizedCountryCode(_ boundaryCode: String) -> String {
    let boundaryToAppMapping = [
        "CN-TW": "TW"
    ]
    return boundaryToAppMapping[boundaryCode] ?? boundaryCode
}
