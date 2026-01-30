import MapKit
import SwiftUI
import UIKit

/// Custom annotation for photo locations
class PhotoPinAnnotation: NSObject, MKAnnotation {
    dynamic var coordinate: CLLocationCoordinate2D
    let photoCount: Int
    let countryCode: String?
    let regionName: String?

    init(photoLocation: PhotoLocation) {
        self.coordinate = photoLocation.coordinate
        self.photoCount = photoLocation.photoCount
        self.countryCode = photoLocation.countryCode
        self.regionName = photoLocation.regionName
        super.init()
    }

    var title: String? {
        if photoCount == 1 {
            return "1 photo"
        } else {
            return "\(photoCount) photos"
        }
    }

    var subtitle: String? {
        regionName
    }
}

/// A map view that displays country boundaries with visited status highlighting
struct CountryMapView: UIViewRepresentable {
    let visitedCountryCodes: Set<String>
    let bucketListCountryCodes: Set<String>
    let visitedStateCodes: Set<String>  // Format: "US-CA", "CA-ON", etc.
    let bucketListStateCodes: Set<String>  // Format: "US-CA", "CA-ON", etc.
    @Binding var selectedCountry: String?
    @Binding var centerOnUserLocation: Bool
    var onCountryTapped: ((String) -> Void)?
    var showUserLocation: Bool = false
    var showPhotoPins: Bool = false

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.mapType = .mutedStandard
        mapView.showsCompass = true
        mapView.showsScale = true
        mapView.showsUserLocation = showUserLocation

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
        context.coordinator.bucketListCountryCodes = bucketListCountryCodes
        context.coordinator.visitedStateCodes = visitedStateCodes
        context.coordinator.bucketListStateCodes = bucketListStateCodes
        context.coordinator.onCountryTapped = onCountryTapped
        mapView.showsUserLocation = showUserLocation

        // Center on user location if requested
        if centerOnUserLocation {
            DispatchQueue.main.async {
                self.centerOnUserLocation = false
                if let userLocation = mapView.userLocation.location {
                    let region = MKCoordinateRegion(
                        center: userLocation.coordinate,
                        span: MKCoordinateSpan(latitudeDelta: 5, longitudeDelta: 5)
                    )
                    mapView.setRegion(region, animated: true)
                }
            }
        }

        // Update selected country if changed externally
        if context.coordinator.selectedCountryCode != selectedCountry {
            context.coordinator.selectedCountryCode = selectedCountry
            context.coordinator.updateOverlayColors(in: mapView)
        } else {
            context.coordinator.updateOverlayColors(in: mapView)
        }

        // Update photo pins
        context.coordinator.updatePhotoPins(in: mapView, show: showPhotoPins)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: CountryMapView
        var countryBoundaries: [String: GeoJSONParser.CountryBoundary] = [:]
        var stateBoundaries: [String: GeoJSONParser.StateBoundary] = [:]  // Key: "US-CA", "CA-ON"
        var visitedCountryCodes: Set<String>
        var bucketListCountryCodes: Set<String>
        var visitedStateCodes: Set<String>
        var bucketListStateCodes: Set<String>
        var selectedCountryCode: String?
        var onCountryTapped: ((String) -> Void)?
        weak var mapView: MKMapView?
        var photoPinsShown: Bool = false

        init(_ parent: CountryMapView) {
            self.parent = parent
            self.visitedCountryCodes = parent.visitedCountryCodes
            self.bucketListCountryCodes = parent.bucketListCountryCodes
            self.visitedStateCodes = parent.visitedStateCodes
            self.bucketListStateCodes = parent.bucketListStateCodes
            self.selectedCountryCode = parent.selectedCountry
            self.onCountryTapped = parent.onCountryTapped
            super.init()
        }

        // MARK: - Photo Pins

        func updatePhotoPins(in mapView: MKMapView, show: Bool) {
            // Remove existing photo pins if hiding
            if !show && photoPinsShown {
                let photoPinAnnotations = mapView.annotations.compactMap { $0 as? PhotoPinAnnotation }
                mapView.removeAnnotations(photoPinAnnotations)
                photoPinsShown = false
                return
            }

            // Add photo pins if showing and not already shown
            if show && !photoPinsShown {
                let photoLocations = PhotoLocationStore.shared.load()
                let annotations = photoLocations.map { PhotoPinAnnotation(photoLocation: $0) }
                mapView.addAnnotations(annotations)
                photoPinsShown = true
            }
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
                    let isBucketList = bucketListStateCodes.contains(code)

                    if isVisited {
                        // Visited states: green
                        renderer.fillColor = UIColor.systemGreen.withAlphaComponent(0.4)
                        renderer.strokeColor = UIColor.systemGreen.withAlphaComponent(0.8)
                        renderer.lineWidth = 1.0
                    } else if isBucketList {
                        // Bucket list states: orange
                        renderer.fillColor = UIColor.systemOrange.withAlphaComponent(0.4)
                        renderer.strokeColor = UIColor.systemOrange.withAlphaComponent(0.8)
                        renderer.lineWidth = 1.0
                    } else {
                        // Unvisited states: subtle light red
                        renderer.fillColor = UIColor.systemRed.withAlphaComponent(0.15)
                        renderer.strokeColor = UIColor.systemRed.withAlphaComponent(0.4)
                        renderer.lineWidth = 0.5
                    }
                } else if code == "US" || code == "CA" {
                    // Don't fill US/Canada - let state overlays show through to base map
                    // But keep green outline to show country is visited
                    let isVisited = visitedCountryCodes.contains(code)
                    let isBucketList = bucketListCountryCodes.contains(code)
                    renderer.fillColor = .clear
                    if isVisited {
                        renderer.strokeColor = UIColor.systemGreen
                        renderer.lineWidth = 1.5
                    } else if isBucketList {
                        renderer.strokeColor = UIColor.systemOrange
                        renderer.lineWidth = 1.5
                    } else {
                        renderer.strokeColor = UIColor.systemGray.withAlphaComponent(0.3)
                        renderer.lineWidth = 0.5
                    }
                } else {
                    // Country rendering
                    let isVisited = visitedCountryCodes.contains(code)
                    let isBucketList = bucketListCountryCodes.contains(code)
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
                    } else if isBucketList {
                        // Bucket list countries: orange
                        renderer.fillColor = UIColor.systemOrange.withAlphaComponent(0.4)
                        renderer.strokeColor = UIColor.systemOrange.withAlphaComponent(0.8)
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

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            // Don't customize user location annotation
            if annotation is MKUserLocation {
                return nil
            }

            // Handle photo pin annotations
            if let photoPin = annotation as? PhotoPinAnnotation {
                let identifier = "PhotoPin"
                var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView

                if annotationView == nil {
                    annotationView = MKMarkerAnnotationView(annotation: photoPin, reuseIdentifier: identifier)
                    annotationView?.canShowCallout = true
                    annotationView?.clusteringIdentifier = "PhotoCluster"
                } else {
                    annotationView?.annotation = photoPin
                }

                // Style based on photo count
                if photoPin.photoCount >= 10 {
                    annotationView?.markerTintColor = .systemRed
                    annotationView?.glyphText = "\(photoPin.photoCount)"
                } else if photoPin.photoCount >= 5 {
                    annotationView?.markerTintColor = .systemOrange
                    annotationView?.glyphText = "\(photoPin.photoCount)"
                } else {
                    annotationView?.markerTintColor = .systemBlue
                    annotationView?.glyphImage = UIImage(systemName: "photo")
                }

                annotationView?.displayPriority = .defaultHigh

                return annotationView
            }

            // Handle cluster annotations
            if let cluster = annotation as? MKClusterAnnotation {
                let identifier = "PhotoCluster"
                var clusterView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView

                if clusterView == nil {
                    clusterView = MKMarkerAnnotationView(annotation: cluster, reuseIdentifier: identifier)
                    clusterView?.canShowCallout = true
                } else {
                    clusterView?.annotation = cluster
                }

                // Calculate total photos in cluster
                let totalPhotos = cluster.memberAnnotations
                    .compactMap { $0 as? PhotoPinAnnotation }
                    .reduce(0) { $0 + $1.photoCount }

                clusterView?.markerTintColor = .systemPurple
                clusterView?.glyphText = "\(totalPhotos)"
                clusterView?.displayPriority = .defaultHigh

                return clusterView
            }

            return nil
        }

        func mapView(_ mapView: MKMapView, didSelect annotation: MKAnnotation) {
            // Handle annotation selection if needed
        }
    }
}


#Preview {
    CountryMapView(
        visitedCountryCodes: ["US", "CA", "MX", "GB", "FR"],
        bucketListCountryCodes: ["JP", "AU", "NZ"],
        visitedStateCodes: ["US-CA", "US-NY", "US-TX", "CA-ON", "CA-BC"],
        bucketListStateCodes: ["US-HI", "US-AK", "CA-QC"],
        selectedCountry: .constant(nil),
        centerOnUserLocation: .constant(false),
        onCountryTapped: { code in
            print("Tapped country: \(code)")
        }
    )
}
