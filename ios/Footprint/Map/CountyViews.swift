import MapKit
import SwiftData
import SwiftUI

/// Visited / transit county sets derived from `VisitedPlace` rows (§2.5: transit does not count
/// toward coverage).
struct CountyCoverage {
    let visited: [String: VisitedPlace]
    let transit: [String: VisitedPlace]

    init(places: [VisitedPlace]) {
        var visited: [String: VisitedPlace] = [:]
        var transit: [String: VisitedPlace] = [:]
        for place in places where place.regionType == VisitedPlace.RegionType.usCounty.rawValue
            && !place.isDeleted && place.isVisited {
            if place.isTransit {
                transit[place.regionCode] = place
            } else {
                visited[place.regionCode] = place
            }
        }
        self.visited = visited
        self.transit = transit
    }

    func visitedCount(in counties: [CountyInfo]) -> Int {
        counties.filter { visited[$0.fips] != nil }.count
    }

    func landShare(of counties: [CountyInfo]) -> Double {
        let total = counties.reduce(0) { $0 + $1.landKm2 }
        guard total > 0 else { return 0 }
        return counties.filter { visited[$0.fips] != nil }.reduce(0) { $0 + $1.landKm2 } / total
    }
}

/// US page: county coverage overall and per state.
struct USCountiesView: View {
    @Query private var places: [VisitedPlace]
    private let index = CountyIndex.shared

    var body: some View {
        let coverage = CountyCoverage(places: places)
        let all = index.map { Array($0.counties.values) } ?? []
        List {
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Text("\(coverage.visitedCount(in: all)) of \(all.count.formatted()) counties")
                        .font(.title2.weight(.semibold))
                    Text("\(coverage.landShare(of: all).formatted(.percent.precision(.fractionLength(1)))) of US land")
                        .foregroundStyle(.secondary)
                    ProgressView(value: all.isEmpty ? 0 : Double(coverage.visitedCount(in: all)) / Double(all.count))
                        .tint(.green)
                }
                .accessibilityElement(children: .combine)
                .padding(.vertical, 4)
            }
            Section("States") {
                ForEach(stateRows(coverage: coverage), id: \.state.id) { row in
                    NavigationLink {
                        StateCountiesView(state: row.state)
                    } label: {
                        HStack {
                            Text(row.state.name)
                            Spacer()
                            Text("\(row.visited)/\(row.total)")
                                .monospacedDigit()
                                .foregroundStyle(row.visited == row.total ? .green : .secondary)
                        }
                    }
                    .accessibilityLabel("\(row.state.name), \(row.visited) of \(row.total) \(index?.pluralTerm(forState: row.state.id) ?? "counties") visited")
                }
            }
        }
        .navigationTitle("Counties")
    }

    private struct StateRow {
        let state: StateProvince
        let visited: Int
        let total: Int
    }

    private func stateRows(coverage: CountyCoverage) -> [StateRow] {
        guard let index else { return [] }
        let puertoRico = StateProvince("PR", "Puerto Rico", country: "PR")
        return (GeographicData.states(for: "US") + [puertoRico])
            .compactMap { state -> StateRow? in
                let counties = index.counties(inState: state.id)
                guard !counties.isEmpty else { return nil }
                return StateRow(state: state, visited: coverage.visitedCount(in: counties), total: counties.count)
            }
            .sorted { ($0.visited, $1.state.name) > ($1.visited, $0.state.name) }
    }
}

/// A state's county map and its Visited / Transit / Not yet list.
struct StateCountiesView: View {
    let state: StateProvince
    @Environment(\.modelContext) private var modelContext
    @Query private var places: [VisitedPlace]
    @State private var segment: Segment = .visited
    @State private var selectedFips: String?

    enum Segment: String, CaseIterable, Identifiable {
        case visited = "Visited"
        case transit = "Transit"
        case notYet = "Not yet"
        var id: String { rawValue }
    }

    private var counties: [CountyInfo] { CountyIndex.shared?.counties(inState: state.id) ?? [] }
    private var term: String { CountyIndex.shared?.pluralTerm(forState: state.id) ?? "counties" }

    var body: some View {
        let coverage = CountyCoverage(places: places)
        VStack(spacing: 0) {
            CountyMapView(state: state.id, coverage: coverage, selectedFips: $selectedFips)
                .frame(height: 280)
                .overlay(alignment: .bottom) {
                    if let fips = selectedFips, let county = CountyIndex.shared?.counties[fips] {
                        CountyCard(county: county, place: coverage.visited[fips] ?? coverage.transit[fips])
                            .padding(8)
                    }
                }
            List {
                Section {
                    Text("\(coverage.visitedCount(in: counties)) of \(counties.count) \(term) · \(coverage.landShare(of: counties).formatted(.percent.precision(.fractionLength(0)))) of land")
                        .font(.headline)
                    Picker("Show", selection: $segment) {
                        ForEach(Segment.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                }
                Section {
                    let shown = rows(for: segment, coverage: coverage)
                    if shown.isEmpty {
                        Text(segment == .notYet ? "Every one visited." : "None yet.")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(shown) { county in
                        CountyRow(county: county, place: coverage.visited[county.fips] ?? coverage.transit[county.fips]) {
                            toggle(county, coverage: coverage)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture { selectedFips = county.fips }
                    }
                }
            }
        }
        .navigationTitle(state.name)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    private func rows(for segment: Segment, coverage: CountyCoverage) -> [CountyInfo] {
        switch segment {
        case .visited: return counties.filter { coverage.visited[$0.fips] != nil }
        case .transit: return counties.filter { coverage.transit[$0.fips] != nil }
        case .notYet: return counties.filter { coverage.visited[$0.fips] == nil && coverage.transit[$0.fips] == nil }
        }
    }

    private func toggle(_ county: CountyInfo, coverage: CountyCoverage) {
        if let place = coverage.visited[county.fips] ?? coverage.transit[county.fips] {
            place.isDeleted = true
            place.lastModifiedAt = Date()
            place.isSynced = false
        } else if let removed = places.first(where: {
            $0.regionType == VisitedPlace.RegionType.usCounty.rawValue && $0.regionCode == county.fips
        }) {
            removed.isDeleted = false
            removed.status = VisitedPlace.PlaceStatus.visited.rawValue
            removed.visitType = VisitedPlace.VisitType.visited.rawValue
            removed.lastModifiedAt = Date()
            removed.isSynced = false
        } else {
            modelContext.insert(VisitedPlace(regionType: .usCounty, regionCode: county.fips, regionName: county.name))
        }
        try? modelContext.save()
    }
}

private struct CountyRow: View {
    let county: CountyInfo
    let place: VisitedPlace?
    let onToggle: () -> Void

    var body: some View {
        HStack {
            Button(action: onToggle) {
                Image(systemName: place == nil ? "circle" : (place!.isTransit ? "car.circle.fill" : "checkmark.circle.fill"))
                    .foregroundStyle(place == nil ? .secondary : (place!.isTransit ? Color.orange : Color.green))
                    .font(.title3)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(place == nil ? "Mark \(county.name) visited" : "Remove \(county.name)")
            VStack(alignment: .leading, spacing: 2) {
                Text(county.name)
                if let place {
                    Text(Self.detail(place))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    static func detail(_ place: VisitedPlace) -> String {
        var parts: [String] = []
        if let date = place.visitedDate {
            parts.append("First \(date.formatted(date: .abbreviated, time: .omitted))")
        }
        if place.visitCount > 1 {
            parts.append("\(place.visitCount) visits")
        }
        return parts.isEmpty ? (place.isTransit ? "Passed through" : "Visited") : parts.joined(separator: " · ")
    }
}

private struct CountyCard: View {
    let county: CountyInfo
    let place: VisitedPlace?

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(county.name).font(.headline)
            Text(place.map(CountyRow.detail) ?? "Not visited yet")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
        .accessibilityElement(children: .combine)
    }
}

/// County choropleth for one state: visited, transit, unvisited (§2.6).
struct CountyMapView: UIViewRepresentable {
    let state: String
    let coverage: CountyCoverage
    @Binding var selectedFips: String?

    static let visitedColor = UIColor.systemGreen
    static let transitColor = UIColor.systemOrange

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.mapType = .mutedStandard
        mapView.pointOfInterestFilter = .excludingAll
        let shapes = CountyMatcher.shared.shapes(forState: state)
        context.coordinator.shapes = shapes
        var rect = MKMapRect.null
        for shape in shapes {
            let overlay = MKMultiPolygon(shape.polygons.compactMap { Self.polygon($0) })
            overlay.title = shape.fips
            mapView.addOverlay(overlay)
            rect = rect.union(overlay.boundingMapRect)
        }
        if !rect.isNull {
            mapView.setVisibleMapRect(rect, edgePadding: UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16), animated: false)
        }
        mapView.addGestureRecognizer(UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.tapped(_:))))
        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        context.coordinator.parent = self
        for overlay in mapView.overlays {
            if let renderer = mapView.renderer(for: overlay) as? MKMultiPolygonRenderer {
                context.coordinator.style(renderer, fips: overlay.title ?? nil)
                renderer.setNeedsDisplay()
            }
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    private static func polygon(_ rings: [[(lon: Double, lat: Double)]]) -> MKPolygon? {
        guard let outer = rings.first else { return nil }
        let holes = rings.dropFirst().map { ring in
            let coords = ring.map { CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lon) }
            return MKPolygon(coordinates: coords, count: coords.count)
        }
        let coords = outer.map { CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lon) }
        return MKPolygon(coordinates: coords, count: coords.count, interiorPolygons: holes)
    }

    final class Coordinator: NSObject, MKMapViewDelegate {
        var parent: CountyMapView
        var shapes: [CountyShape] = []

        init(_ parent: CountyMapView) { self.parent = parent }

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            guard let multi = overlay as? MKMultiPolygon else { return MKOverlayRenderer(overlay: overlay) }
            let renderer = MKMultiPolygonRenderer(multiPolygon: multi)
            style(renderer, fips: multi.title)
            return renderer
        }

        func style(_ renderer: MKMultiPolygonRenderer, fips: String?) {
            let fill: UIColor
            if let fips, parent.coverage.visited[fips] != nil {
                fill = CountyMapView.visitedColor.withAlphaComponent(0.55)
            } else if let fips, parent.coverage.transit[fips] != nil {
                fill = CountyMapView.transitColor.withAlphaComponent(0.45)
            } else {
                fill = UIColor.systemGray.withAlphaComponent(0.12)
            }
            renderer.fillColor = fill
            renderer.strokeColor = fips == parent.selectedFips ? .label : UIColor.systemGray.withAlphaComponent(0.6)
            renderer.lineWidth = fips == parent.selectedFips ? 2 : 0.5
        }

        @objc func tapped(_ gesture: UITapGestureRecognizer) {
            guard let mapView = gesture.view as? MKMapView else { return }
            let coordinate = mapView.convert(gesture.location(in: mapView), toCoordinateFrom: mapView)
            let fips = shapes.first { $0.contains(latitude: coordinate.latitude, longitude: coordinate.longitude) }?.fips
            parent.selectedFips = fips
        }
    }
}
