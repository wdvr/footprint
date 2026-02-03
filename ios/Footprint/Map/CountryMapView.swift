import MapKit
import SwiftUI
import UIKit

/// Playful bubble-style annotation view for photo pins
class PhotoBubbleAnnotationView: MKAnnotationView {
    private let bubbleView = UIView()
    private let iconView = UIImageView()
    private let badgeView = UIView()
    private let badgeLabel = UILabel()
    private var gradientLayer: CAGradientLayer?

    override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        setupView()
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setupView()
    }

    private func setupView() {
        canShowCallout = false
        frame = CGRect(x: 0, y: 0, width: 44, height: 52)
        centerOffset = CGPoint(x: 0, y: -26)
        displayPriority = .defaultHigh

        // Main bubble - circular with playful gradient
        let bubbleSize: CGFloat = 44
        bubbleView.frame = CGRect(x: 0, y: 0, width: bubbleSize, height: bubbleSize)
        bubbleView.layer.cornerRadius = bubbleSize / 2
        bubbleView.clipsToBounds = true
        addSubview(bubbleView)

        // Gradient background
        let gradient = CAGradientLayer()
        gradient.frame = bubbleView.bounds
        gradient.cornerRadius = bubbleSize / 2
        gradient.startPoint = CGPoint(x: 0, y: 0)
        gradient.endPoint = CGPoint(x: 1, y: 1)
        bubbleView.layer.addSublayer(gradient)
        gradientLayer = gradient

        // White inner ring for depth
        let innerRing = UIView(frame: bubbleView.bounds.insetBy(dx: 2, dy: 2))
        innerRing.backgroundColor = .clear
        innerRing.layer.cornerRadius = (bubbleSize - 4) / 2
        innerRing.layer.borderWidth = 2
        innerRing.layer.borderColor = UIColor.white.withAlphaComponent(0.5).cgColor
        bubbleView.addSubview(innerRing)

        // Photo icon in center
        let iconSize: CGFloat = 22
        iconView.frame = CGRect(
            x: (bubbleSize - iconSize) / 2,
            y: (bubbleSize - iconSize) / 2,
            width: iconSize,
            height: iconSize
        )
        iconView.contentMode = .scaleAspectFit
        iconView.tintColor = .white
        bubbleView.addSubview(iconView)

        // Badge for count - positioned at bottom right
        let badgeSize: CGFloat = 20
        badgeView.frame = CGRect(
            x: bubbleSize - badgeSize + 4,
            y: bubbleSize - badgeSize + 4,
            width: badgeSize,
            height: badgeSize
        )
        badgeView.backgroundColor = .white
        badgeView.layer.cornerRadius = badgeSize / 2
        badgeView.layer.shadowColor = UIColor.black.cgColor
        badgeView.layer.shadowOffset = CGSize(width: 0, height: 1)
        badgeView.layer.shadowRadius = 2
        badgeView.layer.shadowOpacity = 0.3
        addSubview(badgeView)

        // Badge label
        badgeLabel.frame = badgeView.bounds
        badgeLabel.font = .systemFont(ofSize: 10, weight: .bold)
        badgeLabel.textAlignment = .center
        badgeLabel.adjustsFontSizeToFitWidth = true
        badgeLabel.minimumScaleFactor = 0.6
        badgeView.addSubview(badgeLabel)

        // Soft shadow under bubble
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOffset = CGSize(width: 0, height: 3)
        layer.shadowRadius = 6
        layer.shadowOpacity = 0.2
    }

    func configure(photoCount: Int, isCluster: Bool) {
        // Format count
        let countText: String
        if photoCount >= 10000 {
            countText = "\(photoCount / 1000)k"
        } else if photoCount >= 1000 {
            countText = String(format: "%.1fk", Double(photoCount) / 1000.0)
        } else {
            countText = "\(photoCount)"
        }

        // Set icon
        let config = UIImage.SymbolConfiguration(weight: .medium)
        let iconName = isCluster ? "photo.stack.fill" : "camera.fill"
        iconView.image = UIImage(systemName: iconName, withConfiguration: config)

        // Fun gradient colors based on count
        let colors: [CGColor]
        let badgeColor: UIColor

        if photoCount >= 1000 {
            // Hot pink to orange gradient
            colors = [
                UIColor(red: 1.0, green: 0.4, blue: 0.6, alpha: 1.0).cgColor,
                UIColor(red: 1.0, green: 0.6, blue: 0.3, alpha: 1.0).cgColor
            ]
            badgeColor = UIColor(red: 1.0, green: 0.4, blue: 0.5, alpha: 1.0)
        } else if photoCount >= 100 {
            // Purple to pink gradient
            colors = [
                UIColor(red: 0.6, green: 0.4, blue: 1.0, alpha: 1.0).cgColor,
                UIColor(red: 1.0, green: 0.5, blue: 0.8, alpha: 1.0).cgColor
            ]
            badgeColor = UIColor(red: 0.7, green: 0.4, blue: 0.9, alpha: 1.0)
        } else if photoCount >= 10 {
            // Teal to green gradient
            colors = [
                UIColor(red: 0.2, green: 0.8, blue: 0.8, alpha: 1.0).cgColor,
                UIColor(red: 0.4, green: 0.9, blue: 0.6, alpha: 1.0).cgColor
            ]
            badgeColor = UIColor(red: 0.2, green: 0.7, blue: 0.7, alpha: 1.0)
        } else {
            // Sky blue to light purple gradient
            colors = [
                UIColor(red: 0.4, green: 0.7, blue: 1.0, alpha: 1.0).cgColor,
                UIColor(red: 0.7, green: 0.6, blue: 1.0, alpha: 1.0).cgColor
            ]
            badgeColor = UIColor(red: 0.5, green: 0.6, blue: 0.95, alpha: 1.0)
        }

        gradientLayer?.colors = colors
        badgeLabel.text = countText
        badgeLabel.textColor = badgeColor

        // Adjust badge size for larger numbers
        let textWidth = countText.size(withAttributes: [.font: badgeLabel.font!]).width
        let newBadgeWidth = max(20, textWidth + 8)
        badgeView.frame = CGRect(
            x: 44 - newBadgeWidth + 4,
            y: 44 - 20 + 4,
            width: newBadgeWidth,
            height: 20
        )
        badgeView.layer.cornerRadius = 10
        badgeLabel.frame = badgeView.bounds
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        badgeLabel.text = nil
        iconView.image = nil
    }
}

/// Helper to normalize country codes between boundary data and app data
/// Some boundary data uses different codes (e.g., CN-TW for Taiwan vs TW in app)
private func normalizedCountryCode(_ boundaryCode: String) -> String {
    // Map boundary codes to app codes
    let boundaryToAppMapping = [
        "CN-TW": "TW",  // Taiwan
    ]
    return boundaryToAppMapping[boundaryCode] ?? boundaryCode
}

/// Custom annotation for photo locations
class PhotoPinAnnotation: NSObject, MKAnnotation {
    dynamic var coordinate: CLLocationCoordinate2D
    let photoCount: Int
    let countryCode: String?
    let regionName: String?
    let photoAssetIDs: [String]
    let gridKey: String

    init(photoLocation: PhotoLocation) {
        self.coordinate = photoLocation.coordinate
        self.photoCount = photoLocation.photoCount
        self.countryCode = photoLocation.countryCode
        self.regionName = photoLocation.regionName
        self.photoAssetIDs = photoLocation.photoAssetIDs
        self.gridKey = photoLocation.gridKey
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
    var onPhotoPinTapped: (([String]) -> Void)?  // Called with photo asset IDs
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
        context.coordinator.onPhotoPinTapped = onPhotoPinTapped
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
        var onPhotoPinTapped: (([String]) -> Void)?
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
                // Debug: Check if photoAssetIDs are populated
                let locationsWithIDs = photoLocations.filter { !$0.photoAssetIDs.isEmpty }
                print("[CountryMapView] Loading \(photoLocations.count) locations, \(locationsWithIDs.count) have asset IDs")
                if let first = locationsWithIDs.first {
                    print("[CountryMapView] Sample: \(first.photoCount) photos, \(first.photoAssetIDs.count) IDs")
                }
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

            // Check if tap was on an annotation (photo pin or cluster)
            // If so, let the annotation selection handle it
            for annotation in mapView.annotations {
                if annotation is MKUserLocation { continue }
                if let view = mapView.view(for: annotation) {
                    let annotationPoint = mapView.convert(annotation.coordinate, toPointTo: mapView)
                    let hitRect = view.frame.insetBy(dx: -20, dy: -20)  // Generous hit area
                    if hitRect.contains(tapPoint) {
                        // Tap was on an annotation, don't handle as country tap
                        return
                    }
                }
            }

            let tapCoordinate = mapView.convert(tapPoint, toCoordinateFrom: mapView)
            let mapPoint = MKMapPoint(tapCoordinate)

            // Find which country was tapped
            for (countryCode, boundary) in countryBoundaries {
                if isPoint(mapPoint, inside: boundary.overlay) {
                    // Normalize code for app use (e.g., CN-TW -> TW)
                    let normalizedCode = normalizedCountryCode(countryCode)
                    // Update selection
                    DispatchQueue.main.async {
                        self.selectedCountryCode = countryCode
                        self.parent.selectedCountry = normalizedCode
                        self.updateOverlayColors(in: mapView)

                        // Zoom to the country
                        self.zoomToCountry(boundary, in: mapView)

                        // Notify callback with normalized code
                        self.onCountryTapped?(normalizedCode)
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
                    let normalizedCode = normalizedCountryCode(code)
                    let isVisited = visitedCountryCodes.contains(normalizedCode)
                    let isBucketList = bucketListCountryCodes.contains(normalizedCode)
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
                    let normalizedCode = normalizedCountryCode(code)
                    let isVisited = visitedCountryCodes.contains(normalizedCode)
                    let isBucketList = bucketListCountryCodes.contains(normalizedCode)
                    let isSelected = code == selectedCountryCode || normalizedCode == selectedCountryCode

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

            // Handle photo pin annotations with playful bubble style
            if let photoPin = annotation as? PhotoPinAnnotation {
                let identifier = "PhotoPinAnnotation"
                var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? PhotoBubbleAnnotationView

                if annotationView == nil {
                    annotationView = PhotoBubbleAnnotationView(annotation: photoPin, reuseIdentifier: identifier)
                } else {
                    annotationView?.annotation = photoPin
                }

                // Always set clustering identifier (important for reused views)
                annotationView?.clusteringIdentifier = "PhotoPinCluster"
                annotationView?.configure(photoCount: photoPin.photoCount, isCluster: false)

                return annotationView
            }

            // Handle cluster annotations with playful bubble style
            if let cluster = annotation as? MKClusterAnnotation {
                let identifier = "PhotoPinClusterAnnotation"
                var clusterView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? PhotoBubbleAnnotationView

                if clusterView == nil {
                    clusterView = PhotoBubbleAnnotationView(annotation: cluster, reuseIdentifier: identifier)
                } else {
                    clusterView?.annotation = cluster
                }

                // Calculate total photos in cluster (sum of all member pin counts)
                let totalPhotos = cluster.memberAnnotations
                    .compactMap { $0 as? PhotoPinAnnotation }
                    .reduce(0) { $0 + $1.photoCount }

                clusterView?.configure(photoCount: totalPhotos, isCluster: true)

                return clusterView
            }

            return nil
        }

        func mapView(_ mapView: MKMapView, didSelect annotation: MKAnnotation) {
            // Handle photo pin selection
            if let photoPin = annotation as? PhotoPinAnnotation {
                mapView.deselectAnnotation(annotation, animated: false)
                DispatchQueue.main.async {
                    self.onPhotoPinTapped?(photoPin.photoAssetIDs)
                }
            } else if let cluster = annotation as? MKClusterAnnotation {
                // Collect all photo asset IDs from the cluster
                let allAssetIDs = cluster.memberAnnotations
                    .compactMap { $0 as? PhotoPinAnnotation }
                    .flatMap { $0.photoAssetIDs }
                if !allAssetIDs.isEmpty {
                    mapView.deselectAnnotation(annotation, animated: false)
                    DispatchQueue.main.async {
                        self.onPhotoPinTapped?(allAssetIDs)
                    }
                }
            }
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
        },
        onPhotoPinTapped: { assetIDs in
            print("Tapped photo pin with \(assetIDs.count) photos")
        }
    )
}
