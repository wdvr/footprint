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
        let region: MKCoordinateRegion
        if countryCode == "US" {
            // Center on continental US
            region = MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 39.8, longitude: -98.5),
                span: MKCoordinateSpan(latitudeDelta: 50, longitudeDelta: 60)
            )
        } else {
            // Center on Canada
            region = MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 56, longitude: -96),
                span: MKCoordinateSpan(latitudeDelta: 50, longitudeDelta: 80)
            )
        }
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
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                guard let self = self else { return }

                let boundaries: [GeoJSONParser.StateBoundary]
                if self.parent.countryCode == "US" {
                    boundaries = GeoJSONParser.parseUSStates()
                } else {
                    boundaries = GeoJSONParser.parseCanadianProvinces()
                }

                print("StateMapView: Parsed \(boundaries.count) boundaries for \(self.parent.countryCode)")

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
                    // Unvisited states: yellow tint
                    renderer.fillColor = UIColor.systemYellow.withAlphaComponent(0.25)
                    renderer.strokeColor = UIColor.systemYellow.withAlphaComponent(0.5)
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
