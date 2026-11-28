import MapKit
import SwiftUI

extension PlaybackEvent {
    /// Parent country of each subdivision region type, for flags.
    static let regionTypeToCountry: [String: String] = [
        VisitedPlace.RegionType.usState.rawValue: "US",
        VisitedPlace.RegionType.canadianProvince.rawValue: "CA",
        VisitedPlace.RegionType.belgianProvince.rawValue: "BE",
        VisitedPlace.RegionType.dutchProvince.rawValue: "NL",
        VisitedPlace.RegionType.frenchRegion.rawValue: "FR",
        VisitedPlace.RegionType.spanishCommunity.rawValue: "ES",
        VisitedPlace.RegionType.italianRegion.rawValue: "IT",
        VisitedPlace.RegionType.germanState.rawValue: "DE",
        VisitedPlace.RegionType.ukCountry.rawValue: "GB",
        VisitedPlace.RegionType.russianFederalSubject.rawValue: "RU",
        VisitedPlace.RegionType.argentineProvince.rawValue: "AR",
        VisitedPlace.RegionType.australianState.rawValue: "AU",
        VisitedPlace.RegionType.mexicanState.rawValue: "MX",
        VisitedPlace.RegionType.brazilianState.rawValue: "BR",
        VisitedPlace.RegionType.japanesePrefecture.rawValue: "JP",
        VisitedPlace.RegionType.southKoreanProvince.rawValue: "KR",
        VisitedPlace.RegionType.norwegianCounty.rawValue: "NO",
    ]

    /// Visited places as playback events. Opt-in layers (counties) and region types this view
    /// doesn't know are skipped, so they never leak into the movie.
    static func events(from places: [VisitedPlace]) -> [PlaybackEvent] {
        places.compactMap { place in
            guard !place.isDeleted, place.isVisited,
                let type = VisitedPlace.RegionType(rawValue: place.regionType), type != .usCounty
            else { return nil }
            let isCountry = place.regionType == VisitedPlace.RegionType.country.rawValue
            return PlaybackEvent(
                date: place.visitedDate ?? place.markedAt,
                regionType: place.regionType,
                regionCode: place.regionCode,
                regionName: place.regionName,
                countryCode: isCountry ? place.regionCode : (regionTypeToCountry[place.regionType] ?? place.regionCode),
                isCountry: isCountry
            )
        }
    }

    var flagEmoji: String {
        var scalars = String.UnicodeScalarView()
        scalars.append(contentsOf: countryCode.uppercased().unicodeScalars.compactMap { UnicodeScalar(127397 + $0.value) })
        return String(scalars)
    }
}

/// Full-screen movie of the user's travel history: places fill in on the map as they were visited.
struct TimelinePlaybackView: View {
    let visitedPlaces: [VisitedPlace]

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var timeline: TimelinePlaybackTimeline?
    @State private var progress: Double = 0
    @State private var isPlaying = false
    @State private var speed: PlaybackSpeed = .normal
    @State private var isScrubbing = false
    @State private var resumeAfterScrub = false

    /// How long (playback seconds at 1×) a newly visited place stays in the arrivals ticker.
    private let arrivalWindow: TimeInterval = 2.5

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let timeline {
                PlaybackMapLayer(timeline: timeline, revealedCount: timeline.revealedCount(at: progress))
                    .equatable()
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    header(timeline)
                    Spacer()
                    arrivals(timeline)
                    controls(timeline)
                }
            } else {
                emptyState
            }
        }
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
        .onAppear {
            guard timeline == nil else { return }
            timeline = TimelinePlaybackTimeline(events: PlaybackEvent.events(from: visitedPlaces))
            if reduceMotion {
                progress = 1
            } else if timeline != nil {
                isPlaying = true
            }
        }
        .onDisappear { isPlaying = false }
        .task(id: isPlaying) {
            guard isPlaying else { return }
            let clock = ContinuousClock()
            var last = clock.now
            while !Task.isCancelled, isPlaying, let timeline {
                try? await Task.sleep(for: .milliseconds(16))
                let now = clock.now
                let seconds = (now - last) / .seconds(1)
                last = now
                guard !isScrubbing else { continue }
                progress = timeline.advanced(from: progress, elapsed: seconds, speed: speed)
                if progress >= 1 { isPlaying = false }
            }
        }
    }

    // MARK: - Header

    private func header(_ timeline: TimelinePlaybackTimeline) -> some View {
        let date = timeline.date(at: progress)
        let countries = timeline.countryCount(at: progress)
        let places = timeline.revealedCount(at: progress)
        return VStack(spacing: 6) {
            HStack {
                Button {
                    isPlaying = false
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(width: 36, height: 36)
                        .background(.ultraThinMaterial, in: Circle())
                }
                .accessibilityLabel("Close playback")
                Spacer()
            }

            Text(date, format: .dateTime.month(.wide).year())
                .font(.system(size: 40, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white)
                .contentTransition(.numericText())
                .shadow(color: .black.opacity(0.6), radius: 6)
                .accessibilityLabel(Text(date, format: .dateTime.month(.wide).year()))

            HStack(spacing: 16) {
                counter(value: countries, label: countries == 1 ? "country" : "countries")
                counter(value: places, label: places == 1 ? "place" : "places")
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 24)
        .background(
            LinearGradient(colors: [.black.opacity(0.65), .clear], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
        )
    }

    private func counter(value: Int, label: LocalizedStringKey) -> some View {
        HStack(spacing: 4) {
            Text("\(value)")
                .font(.headline.weight(.bold))
                .monospacedDigit()
                .contentTransition(.numericText())
            Text(label)
                .font(.subheadline)
        }
        .foregroundStyle(.white.opacity(0.9))
        .accessibilityElement(children: .combine)
    }

    // MARK: - Arrivals

    private func arrivals(_ timeline: TimelinePlaybackTimeline) -> some View {
        let recent = timeline.recentEvents(at: progress, window: arrivalWindow)
        return VStack(spacing: 8) {
            ForEach(recent.reversed(), id: \.event.id) { item in
                HStack(spacing: 8) {
                    Text(item.event.flagEmoji).font(.title2)
                    Text(item.event.regionName)
                        .font(.headline)
                        .foregroundStyle(.white)
                        .lineLimit(1)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial, in: Capsule())
                .opacity(1 - item.age * item.age)
                .scaleEffect(CGFloat(item.age < 0.08 && !reduceMotion ? 0.92 + item.age : 1))
                .transition(.opacity)
            }
        }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.25), value: recent.map(\.event.id))
        .padding(.bottom, 12)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Recently visited: \(recent.map(\.event.regionName).joined(separator: ", "))"))
        .accessibilityHidden(recent.isEmpty)
    }

    // MARK: - Controls

    private func controls(_ timeline: TimelinePlaybackTimeline) -> some View {
        VStack(spacing: 10) {
            scrubber(timeline)

            HStack {
                Text(timeline.startDate, format: .dateTime.year())
                Spacer()
                Text(timeline.endDate, format: .dateTime.year())
            }
            .font(.caption.monospacedDigit())
            .foregroundStyle(.white.opacity(0.7))

            HStack(spacing: 36) {
                Button {
                    progress = 0
                } label: {
                    Image(systemName: "backward.end.fill").font(.title2)
                }
                .accessibilityLabel("Restart")

                Button {
                    togglePlayback()
                } label: {
                    Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 56))
                        .contentTransition(.symbolEffect(.replace))
                }
                .accessibilityLabel(isPlaying ? "Pause" : "Play")

                Button {
                    speed = speed.next
                } label: {
                    Text(speed.label)
                        .font(.headline.monospacedDigit())
                        .frame(minWidth: 48)
                        .padding(.vertical, 6)
                        .background(.white.opacity(0.2), in: Capsule())
                }
                .accessibilityLabel("Playback speed")
                .accessibilityValue(speed.label)
            }
            .foregroundStyle(.white)
        }
        .padding(.horizontal, 20)
        .padding(.top, 28)
        .padding(.bottom, 12)
        .background(
            LinearGradient(colors: [.clear, .black.opacity(0.7)], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
        )
    }

    private func scrubber(_ timeline: TimelinePlaybackTimeline) -> some View {
        Slider(value: $progress, in: 0...1) { editing in
            isScrubbing = editing
            if editing {
                resumeAfterScrub = isPlaying
            } else if resumeAfterScrub, progress < 1 {
                isPlaying = true
            }
        }
        .tint(.white)
        .background(alignment: .leading) {
            GeometryReader { proxy in
                ForEach(timeline.yearMarkers(), id: \.year) { marker in
                    Capsule()
                        .fill(.white.opacity(0.45))
                        .frame(width: 2, height: 10)
                        .position(x: proxy.size.width * marker.progress, y: proxy.size.height / 2)
                }
            }
            .allowsHitTesting(false)
        }
        .accessibilityLabel("Timeline")
        .accessibilityValue(Text(timeline.date(at: progress), format: .dateTime.month(.wide).year()))
    }

    private func togglePlayback() {
        if isPlaying {
            isPlaying = false
        } else {
            if progress >= 1 { progress = 0 }
            isPlaying = true
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "film")
                .font(.system(size: 48))
            Text("No visits to play yet")
                .font(.title3.weight(.semibold))
            Text("Mark places you've visited and they'll appear here in the order you went.")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(.white.opacity(0.7))
            Button("Close") { dismiss() }
                .buttonStyle(.borderedProminent)
                .padding(.top, 8)
        }
        .foregroundStyle(.white)
        .padding(32)
    }
}

/// The map, re-rendered only when a place is revealed or hidden: `CountryMapView` rebuilds all
/// overlays on every update, so it must not follow the per-frame playback clock.
private struct PlaybackMapLayer: View, Equatable {
    let timeline: TimelinePlaybackTimeline
    let revealedCount: Int

    nonisolated static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.revealedCount == rhs.revealedCount && lhs.timeline.events == rhs.timeline.events
    }

    var body: some View {
        let revealed = timeline.events.prefix(revealedCount)
        let countries = Set(revealed.filter(\.isCountry).map(\.regionCode))
        CountryMapView(
            visitedCountryCodes: countries,
            bucketListCountryCodes: [],
            visitedStateCodes: Self.stateCodes(revealed: revealed, countries: countries),
            bucketListStateCodes: [],
            selectedCountry: .constant(nil),
            centerOnUserLocation: .constant(false)
        )
    }

    /// Same fill rules as the main map: US/CA subdivisions individually, and every subdivision
    /// of a country tracked at country level.
    private static func stateCodes(revealed: ArraySlice<PlaybackEvent>, countries: Set<String>) -> Set<String> {
        var codes = Set<String>()
        for event in revealed {
            if event.regionType == VisitedPlace.RegionType.usState.rawValue {
                codes.insert("US-\(event.regionCode)")
            } else if event.regionType == VisitedPlace.RegionType.canadianProvince.rawValue {
                codes.insert("CA-\(event.regionCode)")
            }
        }
        let settings = AppSettings.shared
        for country in countries where !settings.shouldTrackStates(for: country) {
            for state in GeographicData.states(for: country) {
                codes.insert("\(country)-\(state.id)")
            }
        }
        return codes
    }
}

#Preview {
    TimelinePlaybackView(visitedPlaces: [])
}
