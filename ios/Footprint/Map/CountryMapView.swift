import MapKit
import SwiftUI
import UIKit

/// A map view that displays country boundaries with visited status highlighting
struct CountryMapView: UIViewRepresentable {
    let visitedCountryCodes: Set<String>
    let visitedStateCodes: Set<String>  // Format: "US-CA", "CA-ON", etc.
    @Binding var selectedCountry: String?
    var onCountryTapped: ((String) -> Void)?

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

        // Add tap gesture recognizer for country selection
        let tapGesture = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleMapTap(_:))
        )
        mapView.addGestureRecognizer(tapGesture)

        // Load and add country overlays
        context.coordinator.loadCountryBoundaries(for: mapView)

        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        // Update visited countries and states when they change
        context.coordinator.visitedCountryCodes = visitedCountryCodes
        context.coordinator.visitedStateCodes = visitedStateCodes
        context.coordinator.onCountryTapped = onCountryTapped

        // Update selected country if changed externally
        if context.coordinator.selectedCountryCode != selectedCountry {
            context.coordinator.selectedCountryCode = selectedCountry
            context.coordinator.updateOverlayColors(in: mapView)
        } else {
            context.coordinator.updateOverlayColors(in: mapView)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: CountryMapView
        var countryBoundaries: [String: GeoJSONParser.CountryBoundary] = [:]
        var stateBoundaries: [String: GeoJSONParser.StateBoundary] = [:]  // Key: "US-CA", "CA-ON"
        var visitedCountryCodes: Set<String>
        var visitedStateCodes: Set<String>
        var selectedCountryCode: String?
        var onCountryTapped: ((String) -> Void)?
        weak var mapView: MKMapView?

        init(_ parent: CountryMapView) {
            self.parent = parent
            self.visitedCountryCodes = parent.visitedCountryCodes
            self.visitedStateCodes = parent.visitedStateCodes
            self.selectedCountryCode = parent.selectedCountry
            self.onCountryTapped = parent.onCountryTapped
            super.init()
        }

        // MARK: - Tap Gesture Handling

        @objc func handleMapTap(_ gesture: UITapGestureRecognizer) {
            guard let mapView = gesture.view as? MKMapView else { return }
            self.mapView = mapView

            let tapPoint = gesture.location(in: mapView)
            let tapCoordinate = mapView.convert(tapPoint, toCoordinateFrom: mapView)
            let mapPoint = MKMapPoint(tapCoordinate)

            // Find which country was tapped
            for (countryCode, boundary) in countryBoundaries {
                if isPoint(mapPoint, inside: boundary.overlay) {
                    // Update selection
                    DispatchQueue.main.async {
                        self.selectedCountryCode = countryCode
                        self.parent.selectedCountry = countryCode
                        self.updateOverlayColors(in: mapView)

                        // Zoom to the country
                        self.zoomToCountry(boundary, in: mapView)

                        // Notify callback
                        self.onCountryTapped?(countryCode)
                    }
                    return
                }
            }

            // Tapped outside any country - deselect
            DispatchQueue.main.async {
                self.selectedCountryCode = nil
                self.parent.selectedCountry = nil
                self.updateOverlayColors(in: mapView)
            }
        }

        /// Check if a point is inside a multi-polygon
        private func isPoint(_ point: MKMapPoint, inside multiPolygon: MKMultiPolygon) -> Bool {
            for polygon in multiPolygon.polygons {
                if isPoint(point, insidePolygon: polygon) {
                    return true
                }
            }
            return false
        }

        /// Check if a point is inside a polygon using ray casting algorithm
        private func isPoint(_ point: MKMapPoint, insidePolygon polygon: MKPolygon) -> Bool {
            let renderer = MKPolygonRenderer(polygon: polygon)
            let mapPoint = renderer.point(for: point)
            return renderer.path?.contains(mapPoint) ?? false
        }

        /// Zoom the map to show a country with animation
        private func zoomToCountry(_ boundary: GeoJSONParser.CountryBoundary, in mapView: MKMapView) {
            let boundingRect = boundary.overlay.boundingMapRect
            let edgePadding = UIEdgeInsets(top: 50, left: 50, bottom: 100, right: 50)
            mapView.setVisibleMapRect(boundingRect, edgePadding: edgePadding, animated: true)
        }

        func loadCountryBoundaries(for mapView: MKMapView) {
            // Load boundaries on background thread
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                let countryBoundaries = GeoJSONParser.parseCountries()
                let usStates = GeoJSONParser.parseUSStates()
                let caProvinces = GeoJSONParser.parseCanadianProvinces()
                print("CountryMapView: Parsed \(countryBoundaries.count) countries, \(usStates.count) US states, \(caProvinces.count) CA provinces")

                DispatchQueue.main.async {
                    guard let self = self else { return }

                    // Add country boundaries
                    for boundary in countryBoundaries {
                        self.countryBoundaries[boundary.id] = boundary

                        let overlay = boundary.overlay
                        overlay.title = boundary.id
                        overlay.subtitle = boundary.name
                        mapView.addOverlay(overlay, level: .aboveRoads)
                    }

                    // Add US state boundaries (rendered above countries)
                    for state in usStates {
                        let key = "US-\(state.id)"
                        self.stateBoundaries[key] = state

                        let overlay = state.overlay
                        overlay.title = key  // "US-CA", "US-TX", etc.
                        overlay.subtitle = state.name
                        mapView.addOverlay(overlay, level: .aboveRoads)
                    }

                    // Add Canadian province boundaries
                    for province in caProvinces {
                        let key = "CA-\(province.id)"
                        self.stateBoundaries[key] = province

                        let overlay = province.overlay
                        overlay.title = key  // "CA-ON", "CA-BC", etc.
                        overlay.subtitle = province.name
                        mapView.addOverlay(overlay, level: .aboveRoads)
                    }

                    print("CountryMapView: Added \(mapView.overlays.count) total overlays to map")
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

                let code = multiPolygon.title ?? ""
                let isState = code.contains("-")  // State codes are "US-CA", "CA-ON", etc.

                if isState {
                    // State/Province rendering
                    let isVisited = visitedStateCodes.contains(code)

                    if isVisited {
                        // Visited states: green to match visited countries
                        renderer.fillColor = UIColor.systemGreen.withAlphaComponent(0.4)
                        renderer.strokeColor = UIColor.systemGreen.withAlphaComponent(0.8)
                        renderer.lineWidth = 1.0
                    } else {
                        // Unvisited states: subtle light red tint
                        renderer.fillColor = UIColor.systemRed.withAlphaComponent(0.15)
                        renderer.strokeColor = UIColor.systemRed.withAlphaComponent(0.3)
                        renderer.lineWidth = 0.5
                    }
                } else {
                    // Country rendering
                    let isVisited = visitedCountryCodes.contains(code)
                    let isSelected = code == selectedCountryCode

                    if isSelected {
                        // Selected country: blue highlight with thick border
                        renderer.fillColor = UIColor.systemBlue.withAlphaComponent(0.3)
                        renderer.strokeColor = UIColor.systemBlue
                        renderer.lineWidth = 3.0
                    } else if isVisited {
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
        visitedStateCodes: ["US-CA", "US-NY", "US-TX", "CA-ON", "CA-BC"],
        selectedCountry: .constant(nil),
        onCountryTapped: { code in
            print("Tapped country: \(code)")
        }
    )
}
