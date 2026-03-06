import MapKit
import SwiftUI

/// A single event in the travel timeline
struct TimelineEvent: Identifiable {
    let id = UUID()
    let date: Date
    let regionType: String
    let regionCode: String
    let regionName: String
    let flagEmoji: String

    var isState: Bool {
        regionType != VisitedPlace.RegionType.country.rawValue
    }

    /// Map from region type to parent country code
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

    /// The country code for flag emoji purposes (parent country for states)
    var countryCodeForFlag: String {
        if regionType == VisitedPlace.RegionType.country.rawValue {
            return regionCode
        }
        return Self.regionTypeToCountry[regionType] ?? regionCode
    }
}

/// Animated map playback showing countries/states filling in chronologically
struct TimelinePlaybackView: View {
    let visitedPlaces: [VisitedPlace]

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var isPlaying = false
    @State private var playbackSpeed: Double = 1.0
    @State private var sliderValue: Double = 0.0
    @State private var timelineEvents: [TimelineEvent] = []
    @State private var currentEventIndex: Int = -1
    @State private var latestEventText: String = ""
    @State private var latestEventFlag: String = ""
    @State private var showLatestEvent = false
    @State private var selectedCountry: String? = nil
    @State private var centerOnUserLocation = false
    @State private var timer: Timer?

    /// The total playback duration at 1x speed in seconds
    private let baseDuration: Double = 18.0
    /// Timer tick interval
    private let tickInterval: Double = 0.05

    private var dateFormatter: DateFormatter {
        let f = DateFormatter()
        f.dateFormat = "MMMM yyyy"
        return f
    }

    /// Visible country codes based on current playback position
    private var visibleCountryCodes: Set<String> {
        guard !timelineEvents.isEmpty, currentEventIndex >= 0 else { return [] }
        let endIndex = min(currentEventIndex, timelineEvents.count - 1)
        var codes = Set<String>()
        for i in 0...endIndex {
            let event = timelineEvents[i]
            if event.regionType == VisitedPlace.RegionType.country.rawValue {
                codes.insert(event.regionCode)
            }
        }
        return codes
    }

    /// Visible state codes based on current playback position
    private var visibleStateCodes: Set<String> {
        guard !timelineEvents.isEmpty, currentEventIndex >= 0 else { return [] }
        let endIndex = min(currentEventIndex, timelineEvents.count - 1)
        var codes = Set<String>()
        let settings = AppSettings.shared
        for i in 0...endIndex {
            let event = timelineEvents[i]
            if event.regionType == VisitedPlace.RegionType.usState.rawValue {
                codes.insert("US-\(event.regionCode)")
            } else if event.regionType == VisitedPlace.RegionType.canadianProvince.rawValue {
                codes.insert("CA-\(event.regionCode)")
            } else if event.regionType == VisitedPlace.RegionType.country.rawValue {
                // For countries tracked at country level, fill all states
                if !settings.shouldTrackStates(for: event.regionCode) {
                    for state in GeographicData.states(for: event.regionCode) {
                        codes.insert("\(event.regionCode)-\(state.id)")
                    }
                }
            }
        }
        return codes
    }

    /// Current date label for display
    private var currentDateLabel: String {
        guard !timelineEvents.isEmpty, currentEventIndex >= 0 else { return "" }
        let idx = min(currentEventIndex, timelineEvents.count - 1)
        return dateFormatter.string(from: timelineEvents[idx].date)
    }

    /// Year labels for the slider
    private var yearRange: (Int, Int) {
        guard let first = timelineEvents.first, let last = timelineEvents.last else {
            return (2024, 2024)
        }
        let cal = Calendar.current
        return (cal.component(.year, from: first.date), cal.component(.year, from: last.date))
    }

    var body: some View {
        ZStack {
            // Full-screen map
            CountryMapView(
                visitedCountryCodes: visibleCountryCodes,
                bucketListCountryCodes: [],
                visitedStateCodes: visibleStateCodes,
                bucketListStateCodes: [],
                selectedCountry: $selectedCountry,
                centerOnUserLocation: $centerOnUserLocation
            )
            .ignoresSafeArea()

            // Overlay controls
            VStack(spacing: 0) {
                // Top bar with close button and date
                HStack {
                    Button {
                        stopPlayback()
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.white)
                            .shadow(radius: 4)
                    }
                    .accessibilityLabel("Close playback")

                    Spacer()

                    // Date label
                    if !currentDateLabel.isEmpty {
                        Text(currentDateLabel)
                            .font(.title2.weight(.semibold))
                            .foregroundStyle(.white)
                            .shadow(color: .black.opacity(0.5), radius: 4)
                            .animation(.easeInOut(duration: 0.3), value: currentDateLabel)
                    }

                    Spacer()

                    // Counter
                    let count = visibleCountryCodes.count
                    if count > 0 {
                        Text("\(count)")
                            .font(.title3.weight(.bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(.ultraThinMaterial)
                            .clipShape(Capsule())
                    }
                }
                .padding(.horizontal)
                .padding(.top, 8)

                Spacer()

                // Latest place appearing
                if showLatestEvent && !latestEventText.isEmpty {
                    HStack(spacing: 8) {
                        if !latestEventFlag.isEmpty {
                            Text(latestEventFlag)
                                .font(.title)
                        }
                        Text(latestEventText)
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
                }

                // Playback controls bar
                VStack(spacing: 12) {
                    // Slider with year labels
                    VStack(spacing: 4) {
                        Slider(value: $sliderValue, in: 0...1) { editing in
                            if editing {
                                pausePlayback()
                            }
                        }
                        .onChange(of: sliderValue) { _, newValue in
                            updateFromSlider(newValue)
                        }
                        .tint(.white)

                        // Year labels
                        let (startYear, endYear) = yearRange
                        if startYear != endYear {
                            HStack {
                                Text(String(startYear))
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.7))
                                Spacer()
                                Text(String(endYear))
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.7))
                            }
                        }
                    }

                    // Control buttons
                    HStack(spacing: 24) {
                        // Rewind to start
                        Button {
                            rewindToStart()
                        } label: {
                            Image(systemName: "backward.end.fill")
                                .font(.title3)
                                .foregroundStyle(.white)
                        }
                        .accessibilityLabel("Rewind to start")

                        // Play/Pause
                        Button {
                            togglePlayback()
                        } label: {
                            Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                                .font(.largeTitle)
                                .foregroundStyle(.white)
                        }
                        .accessibilityLabel(isPlaying ? "Pause" : "Play")

                        // Speed selector
                        Menu {
                            ForEach([1.0, 2.0, 4.0], id: \.self) { speed in
                                Button {
                                    playbackSpeed = speed
                                } label: {
                                    HStack {
                                        Text("\(Int(speed))x")
                                        if playbackSpeed == speed {
                                            Image(systemName: "checkmark")
                                        }
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
                .background(
                    LinearGradient(
                        colors: [.clear, .black.opacity(0.6)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            }
        }
        .statusBarHidden()
        .onAppear {
            buildTimeline()
            if reduceMotion {
                // Skip to final state
                skipToEnd()
            }
        }
        .onDisappear {
            stopPlayback()
        }
    }

    // MARK: - Timeline Building

    private func buildTimeline() {
        let activePlaces = visitedPlaces.filter { !$0.isDeleted && $0.isVisited }

        // Sentinel date for places with no date (far future so they sort last)
        let distantFuture = Date.distantFuture

        timelineEvents = activePlaces.map { place in
            let effectiveDate = place.visitedDate ?? place.markedAt
            let countryCode: String
            if place.regionType == VisitedPlace.RegionType.country.rawValue {
                countryCode = place.regionCode
            } else {
                countryCode = TimelineEvent.regionTypeToCountry[place.regionType] ?? place.regionCode
            }
            let flag = flagEmoji(for: countryCode)
            return TimelineEvent(
                date: effectiveDate,
                regionType: place.regionType,
                regionCode: place.regionCode,
                regionName: place.regionName,
                flagEmoji: flag
            )
        }
        .sorted { a, b in
            if a.date == Date.distantFuture && b.date != Date.distantFuture { return false }
            if b.date == Date.distantFuture && a.date != Date.distantFuture { return true }
            return a.date < b.date
        }

        if timelineEvents.isEmpty { return }

        // Start with nothing visible
        currentEventIndex = -1
        sliderValue = 0
    }

    // MARK: - Playback Control

    private func togglePlayback() {
        if isPlaying {
            pausePlayback()
        } else {
            startPlayback()
        }
    }

    private func startPlayback() {
        guard !timelineEvents.isEmpty else { return }

        // If at end, restart
        if currentEventIndex >= timelineEvents.count - 1 {
            currentEventIndex = -1
            sliderValue = 0
        }

        isPlaying = true

        let totalEvents = Double(timelineEvents.count)
        let ticksNeeded = baseDuration / tickInterval
        let eventsPerTick = totalEvents / ticksNeeded

        timer = Timer.scheduledTimer(withTimeInterval: tickInterval, repeats: true) { _ in
            let advance = eventsPerTick * playbackSpeed
            let newIndex = Double(currentEventIndex) + advance

            if Int(newIndex) >= timelineEvents.count - 1 {
                currentEventIndex = timelineEvents.count - 1
                sliderValue = 1.0
                showEventLabel(at: currentEventIndex)
                pausePlayback()
            } else {
                let nextIndex = Int(newIndex)
                if nextIndex != currentEventIndex && nextIndex >= 0 {
                    currentEventIndex = nextIndex
                    sliderValue = Double(nextIndex) / Double(timelineEvents.count - 1)
                    showEventLabel(at: nextIndex)
                }
            }
        }
    }

    private func pausePlayback() {
        isPlaying = false
        timer?.invalidate()
        timer = nil
    }

    private func stopPlayback() {
        pausePlayback()
    }

    private func rewindToStart() {
        pausePlayback()
        currentEventIndex = -1
        sliderValue = 0
        withAnimation(.easeOut(duration: 0.3)) {
            showLatestEvent = false
        }
    }

    private func skipToEnd() {
        guard !timelineEvents.isEmpty else { return }
        currentEventIndex = timelineEvents.count - 1
        sliderValue = 1.0
        showEventLabel(at: currentEventIndex)
    }

    private func updateFromSlider(_ value: Double) {
        guard !timelineEvents.isEmpty else { return }
        let index = Int(value * Double(timelineEvents.count - 1))
        let clampedIndex = max(-1, min(index, timelineEvents.count - 1))
        if clampedIndex != currentEventIndex {
            currentEventIndex = clampedIndex
            if clampedIndex >= 0 {
                showEventLabel(at: clampedIndex)
            }
        }
    }

    private func showEventLabel(at index: Int) {
        guard index >= 0, index < timelineEvents.count else { return }
        let event = timelineEvents[index]
        latestEventFlag = event.flagEmoji
        latestEventText = event.regionName
        withAnimation(.easeIn(duration: 0.2)) {
            showLatestEvent = true
        }
        // Auto-hide after a delay (unless playing fast)
        DispatchQueue.main.asyncAfter(deadline: .now() + (1.5 / playbackSpeed)) {
            if currentEventIndex != index {
                withAnimation(.easeOut(duration: 0.3)) {
                    showLatestEvent = false
                }
            }
        }
    }

    // MARK: - Helpers

    private func flagEmoji(for countryCode: String) -> String {
        let base: UInt32 = 127397
        var flag = ""
        for scalar in countryCode.uppercased().unicodeScalars {
            if let unicode = UnicodeScalar(base + scalar.value) {
                flag.append(String(unicode))
            }
        }
        return flag
    }
}

#Preview {
    TimelinePlaybackView(visitedPlaces: [])
}
