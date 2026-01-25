import SwiftData
import SwiftUI

/// View for importing locations from the photo library
struct PhotoImportView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(filter: #Predicate<VisitedPlace> { !$0.isDeleted })
    private var existingPlaces: [VisitedPlace]

    @State private var importManager = PhotoImportManager()
    @State private var selectedLocations: Set<DiscoveredLocation> = []
    @State private var showImportConfirmation = false

    var body: some View {
        NavigationStack {
            VStack {
                switch importManager.state {
                case .idle:
                    IdleView(onStartScan: startScan)

                case .requestingPermission:
                    PermissionRequestView()

                case .scanning(let progress, let processed, let total):
                    ScanningView(progress: progress, processed: processed, total: total)

                case .completed(let locations):
                    if locations.isEmpty {
                        NoLocationsFoundView(onDismiss: { dismiss() })
                    } else {
                        LocationsListView(
                            locations: locations,
                            selectedLocations: $selectedLocations,
                            onImport: { showImportConfirmation = true }
                        )
                    }

                case .error(let message):
                    ErrorView(message: message, onRetry: startScan, onDismiss: { dismiss() })
                }
            }
            .navigationTitle("Import from Photos")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Import Locations", isPresented: $showImportConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Import") {
                    importSelectedLocations()
                }
            } message: {
                Text("Add \(selectedLocations.count) location\(selectedLocations.count == 1 ? "" : "s") to your visited places?")
            }
        }
    }

    private func startScan() {
        Task {
            await importManager.scanPhotoLibrary(existingPlaces: existingPlaces)

            // Auto-select all discovered locations
            if case .completed(let locations) = importManager.state {
                selectedLocations = Set(locations)
            }
        }
    }

    private func importSelectedLocations() {
        importManager.importLocations(Array(selectedLocations), into: modelContext)
        dismiss()
    }
}

// MARK: - Idle State View

private struct IdleView: View {
    let onStartScan: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 60))
                .foregroundStyle(.tint)

            VStack(spacing: 12) {
                Text("Scan Photo Library")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("Footprint can scan your photos to discover places you've visited based on location data embedded in your photos.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "lock.shield")
                        .foregroundStyle(.green)
                    Text("All processing happens on your device")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 8) {
                    Image(systemName: "icloud.slash")
                        .foregroundStyle(.green)
                    Text("No photos are uploaded to any server")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.top, 8)

            Spacer()

            Button(action: onStartScan) {
                Label("Start Scan", systemImage: "magnifyingglass")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.tint)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(.horizontal)
            .padding(.bottom, 24)
        }
    }
}

// MARK: - Permission Request View

private struct PermissionRequestView: View {
    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            ProgressView()
                .scaleEffect(1.5)

            Text("Requesting Photo Access...")
                .font(.headline)
                .foregroundStyle(.secondary)

            Spacer()
        }
    }
}

// MARK: - Scanning View

private struct ScanningView: View {
    let progress: Double
    let processed: Int
    let total: Int

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            ZStack {
                Circle()
                    .stroke(lineWidth: 8)
                    .opacity(0.2)
                    .foregroundStyle(.tint)

                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .foregroundStyle(.tint)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear, value: progress)

                VStack {
                    Text("\(Int(progress * 100))%")
                        .font(.title)
                        .fontWeight(.bold)
                    Text("\(processed)/\(total)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 120, height: 120)

            VStack(spacing: 8) {
                Text("Scanning Photos...")
                    .font(.headline)

                Text("Analyzing location data from your photos")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
    }
}

// MARK: - No Locations Found View

private struct NoLocationsFoundView: View {
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "photo.badge.checkmark")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)

            VStack(spacing: 12) {
                Text("No New Locations Found")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("All locations from your photos are already in your visited places, or your photos don't contain location data.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Spacer()

            Button("Done", action: onDismiss)
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding()
                .background(.tint)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal)
                .padding(.bottom, 24)
        }
    }
}

// MARK: - Locations List View

private struct LocationsListView: View {
    let locations: [DiscoveredLocation]
    @Binding var selectedLocations: Set<DiscoveredLocation>
    let onImport: () -> Void

    private var countries: [DiscoveredLocation] {
        locations.filter { $0.regionType == .country }
    }

    private var states: [DiscoveredLocation] {
        locations.filter { $0.regionType == .usState || $0.regionType == .canadianProvince }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 8) {
                Text("Found \(locations.count) Location\(locations.count == 1 ? "" : "s")")
                    .font(.headline)

                Text("Select the places you want to add")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding()

            // Selection controls
            HStack {
                Button("Select All") {
                    selectedLocations = Set(locations)
                }
                .font(.subheadline)

                Spacer()

                Button("Deselect All") {
                    selectedLocations.removeAll()
                }
                .font(.subheadline)
            }
            .padding(.horizontal)
            .padding(.bottom, 8)

            // Locations list
            List {
                if !countries.isEmpty {
                    Section("Countries") {
                        ForEach(countries) { location in
                            LocationRow(
                                location: location,
                                isSelected: selectedLocations.contains(location),
                                onToggle: { toggleSelection(location) }
                            )
                        }
                    }
                }

                if !states.isEmpty {
                    Section("States & Provinces") {
                        ForEach(states) { location in
                            LocationRow(
                                location: location,
                                isSelected: selectedLocations.contains(location),
                                onToggle: { toggleSelection(location) }
                            )
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)

            // Import button
            Button(action: onImport) {
                Text("Import \(selectedLocations.count) Location\(selectedLocations.count == 1 ? "" : "s")")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(selectedLocations.isEmpty ? Color.gray : Color.accentColor)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(selectedLocations.isEmpty)
            .padding()
        }
    }

    private func toggleSelection(_ location: DiscoveredLocation) {
        if selectedLocations.contains(location) {
            selectedLocations.remove(location)
        } else {
            selectedLocations.insert(location)
        }
    }
}

// MARK: - Location Row

private struct LocationRow: View {
    let location: DiscoveredLocation
    let isSelected: Bool
    let onToggle: () -> Void

    private var iconName: String {
        switch location.regionType {
        case .country: return "flag.fill"
        case .usState: return "star.fill"
        case .canadianProvince: return "leaf.fill"
        }
    }

    private var iconColor: Color {
        switch location.regionType {
        case .country: return .green
        case .usState: return .blue
        case .canadianProvince: return .red
        }
    }

    var body: some View {
        Button(action: onToggle) {
            HStack {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? .green : .secondary)
                    .font(.title2)

                Image(systemName: iconName)
                    .foregroundStyle(iconColor)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text(location.regionName)
                        .foregroundStyle(.primary)

                    HStack(spacing: 8) {
                        Text("\(location.photoCount) photo\(location.photoCount == 1 ? "" : "s")")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        if let date = location.earliestDate {
                            Text("Since \(date.formatted(date: .abbreviated, time: .omitted))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Spacer()

                Text(location.regionCode)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Error View

private struct ErrorView: View {
    let message: String
    let onRetry: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 60))
                .foregroundStyle(.orange)

            VStack(spacing: 12) {
                Text("Something Went Wrong")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text(message)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Spacer()

            VStack(spacing: 12) {
                Button(action: onRetry) {
                    Label("Try Again", systemImage: "arrow.clockwise")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.tint)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                Button("Cancel", action: onDismiss)
                    .font(.headline)
            }
            .padding(.horizontal)
            .padding(.bottom, 24)
        }
    }
}

#Preview {
    PhotoImportView()
        .modelContainer(for: VisitedPlace.self, inMemory: true)
}
