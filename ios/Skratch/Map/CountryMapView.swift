import MapKit
import SwiftUI
import UIKit

/// A map view that displays country boundaries with visited status highlighting
struct CountryMapView: UIViewRepresentable {
    let visitedCountryCodes: Set<String>
    @Binding var selectedCountry: String?

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.mapType = .mutedStandard
        mapView.showsCompass = true
        mapView.showsScale = true

        // Set initial region to show the world
        let worldRegion = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 20, longitude: 0),
            span: MKCoordinateSpan(latitudeDelta: 120, longitudeDelta: 180)
        )
        mapView.setRegion(worldRegion, animated: false)

        // Load and add country overlays
        context.coordinator.loadCountryBoundaries(for: mapView)

        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        // Update visited countries when they change
        context.coordinator.visitedCountryCodes = visitedCountryCodes
        context.coordinator.updateOverlayColors(in: mapView)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: CountryMapView
        var countryBoundaries: [String: GeoJSONParser.CountryBoundary] = [:]
        var visitedCountryCodes: Set<String>

        init(_ parent: CountryMapView) {
            self.parent = parent
            self.visitedCountryCodes = parent.visitedCountryCodes
            super.init()
        }

        func loadCountryBoundaries(for mapView: MKMapView) {
            // Load boundaries on background thread
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                let boundaries = GeoJSONParser.parseCountries()
                print("CountryMapView: Parsed \(boundaries.count) boundaries")

                DispatchQueue.main.async {
                    guard let self = self else { return }

                    for boundary in boundaries {
                        self.countryBoundaries[boundary.id] = boundary

                        // Add the multi-polygon overlay
                        let overlay = boundary.overlay
                        overlay.title = boundary.id
                        overlay.subtitle = boundary.name
                        mapView.addOverlay(overlay, level: .aboveRoads)
                    }
                    print("CountryMapView: Added \(mapView.overlays.count) overlays to map")
                }
            }
        }

        func updateOverlayColors(in mapView: MKMapView) {
            // Force renderer refresh by removing and re-adding overlays
            // This is a workaround since MKOverlayRenderer doesn't update automatically
            for overlay in mapView.overlays {
                if let multiPolygon = overlay as? MKMultiPolygon {
                    mapView.removeOverlay(multiPolygon)
                    mapView.addOverlay(multiPolygon, level: .aboveRoads)
                }
            }
        }

        // MARK: - MKMapViewDelegate

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let multiPolygon = overlay as? MKMultiPolygon {
                let renderer = MKMultiPolygonRenderer(multiPolygon: multiPolygon)

                // Check if this country is visited
                let isVisited = multiPolygon.title.map { visitedCountryCodes.contains($0) } ?? false

                if isVisited {
                    // Visited countries: green with higher opacity
                    renderer.fillColor = UIColor.systemGreen.withAlphaComponent(0.4)
                    renderer.strokeColor = UIColor.systemGreen.withAlphaComponent(0.8)
                    renderer.lineWidth = 1.5
                } else {
                    // Unvisited countries: subtle gray
                    renderer.fillColor = UIColor.systemGray.withAlphaComponent(0.1)
                    renderer.strokeColor = UIColor.systemGray.withAlphaComponent(0.3)
                    renderer.lineWidth = 0.5
                }

                return renderer
            }

            return MKOverlayRenderer(overlay: overlay)
        }

        func mapView(_ mapView: MKMapView, didSelect annotation: MKAnnotation) {
            // Handle annotation selection if needed
        }
    }
}


#Preview {
    CountryMapView(
        visitedCountryCodes: ["US", "CA", "MX", "GB", "FR"],
        selectedCountry: .constant(nil)
    )
}
