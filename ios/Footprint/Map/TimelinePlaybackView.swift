import MapKit
import SwiftUI

/// Movie-style playback of the travel history: a journey line flies from place to place in the
/// order they were first visited, filling the map in and standing landmarks up as it goes.
struct TimelinePlaybackView: View {
    let visitedPlaces: [VisitedPlace]

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var playback: TimelinePlayback
    @State private var isPlaying = false
    @State private var playbackSpeed: Double = 1.0
    @State private var showLatestEvent = false
    @State private var selectedCountry: String? = nil
    @State private var centerOnUserLocation = false
    @State private var playTask: Task<Void, Never>?
    @State private var labelTask: Task<Void, Never>?

    init(visitedPlaces: [VisitedPlace]) {
        self.visitedPlaces = visitedPlaces
        _playback = State(initialValue: TimelinePlayback(stops: TimelineStop.stops(from: visitedPlaces)))
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.setLocalizedDateFormatFromTemplate("MMMM yyyy")
        return f
    }()

    private var currentDateLabel: String {
        playback.latestStop.map { Self.dateFormatter.string(from: $0.date) } ?? ""
    }

    private var yearRange: (Int, Int) {
        guard let first = playback.stops.first, let last = playback.stops.last else { return (0, 0) }
        let cal = Calendar.current
        return (cal.component(.year, from: first.date), cal.component(.year, from: last.date))
    }

    private var visibleStateCodes: Set<String> {
        playback.visibleStateCodes(
            tracksStates: { AppSettings.shared.shouldTrackStates(for: $0) },
            subdivisions: { GeographicData.states(for: $0).map(\.id) }
        )
    }

    var body: some View {
        ZStack {
            CountryMapView(
                visitedCountryCodes: playback.visibleCountryCodes,
                bucketListCountryCodes: [],
                visitedStateCodes: visibleStateCodes,
                bucketListStateCodes: [],
                selectedCountry: $selectedCountry,
                centerOnUserLocation: $centerOnUserLocation,
                journeyPath: playback.journeyPath,
                landmarks: playback.visibleLandmarks()
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                Spacer()
                if playback.stops.isEmpty {
                    emptyState
                } else {
                    latestPlaceLabel
                    controls
                }
            }
        }
        .statusBarHidden()
        .onAppear {
            if reduceMotion { playback.skipToEnd() }
        }
        .task {
            let centers = RegionCenters.centers(for: playback.stops)
            for index in playback.stops.indices {
                playback.stops[index].coordinate = centers[playback.stops[index].id]
            }
        }
        .onChange(of: playback.revealedCount) { _, count in
            if count > 0 { flashLatestPlace() } else { showLatestEvent = false }
        }
        .onDisappear { pausePlayback() }
    }

    // MARK: - Overlays

    private var topBar: some View {
        HStack {
            Button {
                pausePlayback()
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.white)
                    .shadow(radius: 4)
            }
            .accessibilityLabel("Close playback")

            Spacer()

            if !currentDateLabel.isEmpty {
                Text(currentDateLabel)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.5), radius: 4)
                    .contentTransition(.numericText())
                    .animation(.easeInOut(duration: 0.3), value: currentDateLabel)
            }

            Spacer()

            let count = playback.visibleCountryCodes.count
            if count > 0 {
                Text("\(count)")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                    .accessibilityLabel("\(count) countries")
            }
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }

    private var emptyState: some View {
        Text("Mark places as visited to play back your journey.")
            .font(.headline)
            .foregroundStyle(.white)
            .multilineTextAlignment(.center)
            .padding(20)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .padding(.bottom, 60)
    }

    @ViewBuilder
    private var latestPlaceLabel: some View {
        if showLatestEvent, let stop = playback.latestStop {
            HStack(spacing: 8) {
                Text(flagEmoji(for: stop.countryCode)).font(.title)
                Text(stop.regionName)
                    .font(.title3.weight(.medium))
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial)
            .clipShape(Capsule())
            .shadow(radius: 6)
            .transition(.opacity.combined(with: .scale(scale: 0.8)))
            .padding(.bottom, 16)
            .id(stop.id)
        }
    }

    private var controls: some View {
        VStack(spacing: 12) {
            VStack(spacing: 4) {
                Slider(value: Binding(
                    get: { playback.progress },
                    set: { value in
                        pausePlayback()
                        playback.seek(toProgress: value)
                    }
                ))
                .tint(.white)
                .accessibilityLabel("Timeline position")

                let (startYear, endYear) = yearRange
                if startYear != endYear {
                    HStack {
                        Text(String(startYear))
                        Spacer()
                        Text(String(endYear))
                    }
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))
                }
            }

            HStack(spacing: 24) {
                Button {
                    pausePlayback()
                    playback.rewind()
                } label: {
                    Image(systemName: "backward.end.fill")
                        .font(.title3)
                        .foregroundStyle(.white)
                }
                .accessibilityLabel("Rewind to start")

                Button {
                    isPlaying ? pausePlayback() : startPlayback()
                } label: {
                    Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.largeTitle)
                        .foregroundStyle(.white)
                }
                .accessibilityLabel(isPlaying ? "Pause" : "Play")

                Menu {
                    ForEach([1.0, 2.0, 4.0], id: \.self) { speed in
                        Button {
                            playbackSpeed = speed
                        } label: {
                            if playbackSpeed == speed {
                                Label("\(Int(speed))x", systemImage: "checkmark")
                            } else {
                                Text("\(Int(speed))x")
                            }
                        }
                    }
                } label: {
                    Text("\(Int(playbackSpeed))x")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(.white.opacity(0.2))
                        .clipShape(Capsule())
                }
                .accessibilityLabel("Playback speed: \(Int(playbackSpeed))x")
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(LinearGradient(colors: [.clear, .black.opacity(0.6)], startPoint: .top, endPoint: .bottom))
    }

    // MARK: - Playback

    private func startPlayback() {
        guard !playback.stops.isEmpty else { return }
        if playback.isAtEnd { playback.rewind() }
        isPlaying = true
        playTask?.cancel()
        playTask = Task { @MainActor in
            var last = Date()
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(33))
                guard !Task.isCancelled else { break }
                let now = Date()
                playback.advance(by: now.timeIntervalSince(last), speed: playbackSpeed)
                last = now
                if playback.isAtEnd {
                    isPlaying = false
                    break
                }
            }
        }
    }

    private func pausePlayback() {
        isPlaying = false
        playTask?.cancel()
        playTask = nil
    }

    private func flashLatestPlace() {
        withAnimation(.easeIn(duration: 0.2)) { showLatestEvent = true }
        labelTask?.cancel()
        let shown = playback.revealedCount
        labelTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.5 / playbackSpeed))
            guard !Task.isCancelled, playback.revealedCount == shown, isPlaying else { return }
            withAnimation(.easeOut(duration: 0.3)) { showLatestEvent = false }
        }
    }

    private func flagEmoji(for countryCode: String) -> String {
        countryCode.uppercased().unicodeScalars
            .compactMap { UnicodeScalar(127_397 + $0.value) }
            .map(String.init)
            .joined()
    }
}

/// Representative points for timeline stops: a point inside each region's largest landmass, so a
/// country's overseas islands do not drag its point out to sea. Subdivisions without a bundled
/// boundary file (e.g. German states) use the subdivision points in `world_states.json`.
enum RegionCenters {
    static func centers(for stops: [TimelineStop]) -> [String: GeoPoint] {
        var countries: [String: GeoPoint] = [:]
        for boundary in GeoJSONParser.parseCountries() {
            let code = boundary.id == "CN-TW" ? "TW" : boundary.id
            if let point = center(of: boundary.polygons) { countries[code] = point }
        }
        var subdivisions: [String: GeoPoint] = [:]
        let listed = worldStatePoints()
        for country in Set(stops.filter { !$0.isCountry }.map(\.countryCode)) {
            for boundary in GeoJSONParser.parseStates(forCountry: country) {
                if let point = center(of: boundary.polygons) {
                    subdivisions["\(country)-\(SubdivisionCode.short(boundary.id))"] = point
                }
            }
            for state in GeographicData.states(for: country) where subdivisions["\(country)-\(state.id)"] == nil {
                subdivisions["\(country)-\(state.id)"] = listed[country]?[normalized(state.name)]
            }
        }
        var result: [String: GeoPoint] = [:]
        for stop in stops {
            result[stop.id] = stop.isCountry
                ? countries[stop.regionCode]
                : subdivisions["\(stop.countryCode)-\(stop.regionCode)"] ?? countries[stop.countryCode]
        }
        return result
    }

    static func center(of polygons: [MKPolygon]) -> GeoPoint? {
        func area(_ polygon: MKPolygon) -> Double { polygon.boundingMapRect.width * polygon.boundingMapRect.height }
        guard let largest = polygons.max(by: { area($0) < area($1) }) else { return nil }
        let ring = UnsafeBufferPointer(start: largest.points(), count: largest.pointCount).map {
            GeoPoint(latitude: $0.coordinate.latitude, longitude: $0.coordinate.longitude)
        }
        return GeoPoint.interiorPoint(of: ring)
    }

    private struct ListedState: Decodable {
        let name: String
        let lat: String
        let lng: String
    }

    /// Country code -> normalized subdivision name -> point.
    private static func worldStatePoints() -> [String: [String: GeoPoint]] {
        guard let url = Bundle.main.url(forResource: "world_states", withExtension: "json", subdirectory: "GeoData")
                ?? Bundle.main.url(forResource: "world_states", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([String: [ListedState]].self, from: data)
        else { return [:] }
        return decoded.mapValues { states in
            var points: [String: GeoPoint] = [:]
            for state in states {
                if let lat = Double(state.lat), let lng = Double(state.lng) {
                    points[normalized(state.name)] = GeoPoint(latitude: lat, longitude: lng)
                }
            }
            return points
        }
    }

    private static func normalized(_ name: String) -> String {
        name.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
            .replacingOccurrences(of: " state", with: "")
            .replacingOccurrences(of: " province", with: "")
            .trimmingCharacters(in: .whitespaces)
    }
}

#Preview {
    TimelinePlaybackView(visitedPlaces: [])
}
