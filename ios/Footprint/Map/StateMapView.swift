import MapKit
import SwiftUI
import UIKit

/// A map view that displays state/province boundaries with visited status highlighting
struct StateMapView: UIViewRepresentable {
    let countryCode: String  // "US" or "CA"
    let visitedStateCodes: Set<String>
    @Binding var selectedState: String?
    var onStateTapped: ((String) -> Void)?

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.mapType = .mutedStandard
        mapView.showsCompass = true
        mapView.showsScale = true

        // Set initial region based on country
        let region = Self.regionForCountry(countryCode)
        mapView.setRegion(region, animated: false)

        // Add tap gesture recognizer for state selection
        let tapGesture = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleMapTap(_:))
        )
        mapView.addGestureRecognizer(tapGesture)

        // Load and add state overlays
        context.coordinator.loadStateBoundaries(for: mapView)

        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        context.coordinator.visitedStateCodes = visitedStateCodes
        context.coordinator.onStateTapped = onStateTapped

        if context.coordinator.selectedStateCode != selectedState {
            context.coordinator.selectedStateCode = selectedState
            context.coordinator.updateOverlayColors(in: mapView)
        } else {
            context.coordinator.updateOverlayColors(in: mapView)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    /// Returns the appropriate map region for a given country code
    private static func regionForCountry(_ countryCode: String) -> MKCoordinateRegion {
        switch countryCode {
        case "US":
            // Continental US
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 39.8, longitude: -98.5),
                span: MKCoordinateSpan(latitudeDelta: 50, longitudeDelta: 60)
            )
        case "CA":
            // Canada
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 56, longitude: -96),
                span: MKCoordinateSpan(latitudeDelta: 50, longitudeDelta: 80)
            )
        case "RU":
            // Russia - centered to show European and Asian parts
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 62, longitude: 94),
                span: MKCoordinateSpan(latitudeDelta: 50, longitudeDelta: 100)
            )
        case "GB":
            // United Kingdom
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 54.5, longitude: -3),
                span: MKCoordinateSpan(latitudeDelta: 10, longitudeDelta: 12)
            )
        case "FR":
            // France (metropolitan)
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 46.6, longitude: 2.5),
                span: MKCoordinateSpan(latitudeDelta: 10, longitudeDelta: 12)
            )
        case "ES":
            // Spain
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 40.0, longitude: -3.7),
                span: MKCoordinateSpan(latitudeDelta: 10, longitudeDelta: 14)
            )
        case "IT":
            // Italy
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 42.5, longitude: 12.5),
                span: MKCoordinateSpan(latitudeDelta: 10, longitudeDelta: 12)
            )
        case "DE":
            // Germany
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 51.2, longitude: 10.4),
                span: MKCoordinateSpan(latitudeDelta: 8, longitudeDelta: 10)
            )
        case "NL":
            // Netherlands
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 52.2, longitude: 5.3),
                span: MKCoordinateSpan(latitudeDelta: 3.5, longitudeDelta: 4)
            )
        case "BE":
            // Belgium
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 50.5, longitude: 4.5),
                span: MKCoordinateSpan(latitudeDelta: 2.5, longitudeDelta: 3.5)
            )
        case "AR":
            // Argentina
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: -38.5, longitude: -63.6),
                span: MKCoordinateSpan(latitudeDelta: 35, longitudeDelta: 25)
            )
        case "BR":
            // Brazil
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: -14.2, longitude: -51.9),
                span: MKCoordinateSpan(latitudeDelta: 40, longitudeDelta: 40)
            )
        case "AU":
            // Australia
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: -25.3, longitude: 134.5),
                span: MKCoordinateSpan(latitudeDelta: 35, longitudeDelta: 45)
            )
        case "MX":
            // Mexico
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 23.6, longitude: -102.5),
                span: MKCoordinateSpan(latitudeDelta: 20, longitudeDelta: 25)
            )
        default:
            // Default fallback - world view
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 20, longitude: 0),
                span: MKCoordinateSpan(latitudeDelta: 100, longitudeDelta: 180)
            )
        }
    }

    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: StateMapView
        var stateBoundaries: [String: GeoJSONParser.StateBoundary] = [:]
        var visitedStateCodes: Set<String>
        var selectedStateCode: String?
        var onStateTapped: ((String) -> Void)?

        init(_ parent: StateMapView) {
            self.parent = parent
            self.visitedStateCodes = parent.visitedStateCodes
            self.selectedStateCode = parent.selectedState
            self.onStateTapped = parent.onStateTapped
            super.init()
        }

        // MARK: - Tap Gesture Handling

        @objc func handleMapTap(_ gesture: UITapGestureRecognizer) {
            guard let mapView = gesture.view as? MKMapView else { return }

            let tapPoint = gesture.location(in: mapView)
            let tapCoordinate = mapView.convert(tapPoint, toCoordinateFrom: mapView)
            let mapPoint = MKMapPoint(tapCoordinate)

            // Find which state was tapped
            for (stateCode, boundary) in stateBoundaries {
                if isPoint(mapPoint, inside: boundary.overlay) {
                    DispatchQueue.main.async {
                        self.selectedStateCode = stateCode
                        self.parent.selectedState = stateCode
                        self.updateOverlayColors(in: mapView)
                        self.zoomToState(boundary, in: mapView)
                        self.onStateTapped?(stateCode)
                    }
                    return
                }
            }

            // Tapped outside any state - deselect
            DispatchQueue.main.async {
                self.selectedStateCode = nil
                self.parent.selectedState = nil
                self.updateOverlayColors(in: mapView)
            }
        }

        private func isPoint(_ point: MKMapPoint, inside multiPolygon: MKMultiPolygon) -> Bool {
            for polygon in multiPolygon.polygons {
                if isPoint(point, insidePolygon: polygon) {
                    return true
                }
            }
            return false
        }

        private func isPoint(_ point: MKMapPoint, insidePolygon polygon: MKPolygon) -> Bool {
            let renderer = MKPolygonRenderer(polygon: polygon)
            let mapPoint = renderer.point(for: point)
            return renderer.path?.contains(mapPoint) ?? false
        }

        private func zoomToState(_ boundary: GeoJSONParser.StateBoundary, in mapView: MKMapView) {
            let boundingRect = boundary.overlay.boundingMapRect
            let edgePadding = UIEdgeInsets(top: 50, left: 50, bottom: 100, right: 50)
            mapView.setVisibleMapRect(boundingRect, edgePadding: edgePadding, animated: true)
        }

        func loadStateBoundaries(for mapView: MKMapView) {
            let countryCode = parent.countryCode
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                guard let self = self else { return }

                // Use generic state parsing for all countries
                let boundaries = GeoJSONParser.parseStates(forCountry: countryCode)

                print("StateMapView: Parsed \(boundaries.count) boundaries for \(countryCode)")

                DispatchQueue.main.async {
                    for boundary in boundaries {
                        self.stateBoundaries[boundary.id] = boundary

                        let overlay = boundary.overlay
                        overlay.title = boundary.id
                        overlay.subtitle = boundary.name
                        mapView.addOverlay(overlay, level: .aboveRoads)
                    }
                    print("StateMapView: Added \(mapView.overlays.count) overlays to map")
                }
            }
        }

        func updateOverlayColors(in mapView: MKMapView) {
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

                let stateCode = multiPolygon.title
                let isVisited = stateCode.map { visitedStateCodes.contains($0) } ?? false
                let isSelected = stateCode == selectedStateCode

                if isSelected {
                    // Selected state: blue highlight with thick border
                    renderer.fillColor = UIColor.systemBlue.withAlphaComponent(0.3)
                    renderer.strokeColor = UIColor.systemBlue
                    renderer.lineWidth = 3.0
                } else if isVisited {
                    // Visited states: green to match visited countries
                    renderer.fillColor = UIColor.systemGreen.withAlphaComponent(0.4)
                    renderer.strokeColor = UIColor.systemGreen.withAlphaComponent(0.8)
                    renderer.lineWidth = 1.5
                } else {
                    // Unvisited states: subtle light red tint
                    renderer.fillColor = UIColor.systemRed.withAlphaComponent(0.15)
                    renderer.strokeColor = UIColor.systemRed.withAlphaComponent(0.3)
                    renderer.lineWidth = 0.5
                }

                return renderer
            }

            return MKOverlayRenderer(overlay: overlay)
        }
    }
}

#Preview("US States") {
    StateMapView(
        countryCode: "US",
        visitedStateCodes: ["CA", "NY", "TX", "FL"],
        selectedState: .constant(nil),
        onStateTapped: { code in
            print("Tapped state: \(code)")
        }
    )
}

#Preview("Canadian Provinces") {
    StateMapView(
        countryCode: "CA",
        visitedStateCodes: ["ON", "BC", "QC"],
        selectedState: .constant(nil),
        onStateTapped: { code in
            print("Tapped province: \(code)")
        }
    )
}
