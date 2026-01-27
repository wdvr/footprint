import SwiftUI
import SwiftData

/// Main view showing all import sources with their connection status
struct ImportSourcesView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var showingGoogleImport = false
    @State private var showingPhotoImport = false

    private let googleAuth = GoogleAuthManager.shared
    private var photoManager: PhotoImportManager { PhotoImportManager.shared }

    var body: some View {
        NavigationStack {
            List {
                // Google Section
                Section {
                    GoogleCalendarRow(
                        isConnected: googleAuth.isConnected,
                        email: googleAuth.connectedEmail,
                        lastImported: UserDefaults.standard.object(forKey: "lastCalendarImport") as? Date,
                        onReimport: { showingGoogleImport = true }
                    )

                    GmailRow(
                        isConnected: googleAuth.isConnected,
                        email: googleAuth.connectedEmail,
                        lastImported: UserDefaults.standard.object(forKey: "lastGmailImport") as? Date,
                        onReimport: { showingGoogleImport = true }
                    )
                } header: {
                    Text("Google")
                } footer: {
                    if googleAuth.isConnected {
                        Text("Connected as \(googleAuth.connectedEmail ?? "Unknown")")
                    } else {
                        Text("Connect your Google account to import travel history from emails and calendar events.")
                    }
                }

                // Apple Photos Section
                Section {
                    PhotosRow(
                        authStatus: photoManager.authorizationStatus,
                        lastSynced: UserDefaults.standard.object(forKey: "lastPhotoSync") as? Date,
                        isScanning: photoManager.isScanning,
                        onSync: { showingPhotoImport = true }
                    )
                } header: {
                    Text("Apple Photos")
                } footer: {
                    Text("Automatically find countries from photos with GPS data in your library.")
                }

                // Disconnect Section
                if googleAuth.isConnected {
                    Section {
                        Button(role: .destructive) {
                            Task {
                                await googleAuth.disconnect()
                            }
                        } label: {
                            Label("Disconnect Google Account", systemImage: "link.badge.minus")
                        }
                    }
                }
            }
            .navigationTitle("Import Sources")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingGoogleImport) {
                ImportView()
            }
            .sheet(isPresented: $showingPhotoImport) {
                PhotoImportView()
            }
            .task {
                await googleAuth.checkConnectionStatus()
            }
        }
    }
}

// MARK: - Google Calendar Row

private struct GoogleCalendarRow: View {
    let isConnected: Bool
    let email: String?
    let lastImported: Date?
    let onReimport: () -> Void

    var body: some View {
        HStack {
            Image(systemName: "calendar")
                .font(.title2)
                .foregroundStyle(isConnected ? .blue : .secondary)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text("Google Calendar")
                    .font(.body)

                if isConnected {
                    if let date = lastImported {
                        Text("Last imported \(date.formatted(date: .abbreviated, time: .omitted))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Not yet imported")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Text("Not connected")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if isConnected {
                Button("Reimport") {
                    onReimport()
                }
                .font(.subheadline)
            } else {
                Button("Connect") {
                    onReimport()
                }
                .font(.subheadline)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Gmail Row

private struct GmailRow: View {
    let isConnected: Bool
    let email: String?
    let lastImported: Date?
    let onReimport: () -> Void

    var body: some View {
        HStack {
            Image(systemName: "envelope.fill")
                .font(.title2)
                .foregroundStyle(isConnected ? .red : .secondary)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text("Gmail")
                    .font(.body)

                if isConnected {
                    if let date = lastImported {
                        Text("Last imported \(date.formatted(date: .abbreviated, time: .omitted))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Not yet imported")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Text("Not connected")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if isConnected {
                Button("Reimport") {
                    onReimport()
                }
                .font(.subheadline)
            } else {
                Button("Connect") {
                    onReimport()
                }
                .font(.subheadline)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Photos Row

private struct PhotosRow: View {
    let authStatus: PHAuthorizationStatus
    let lastSynced: Date?
    let isScanning: Bool
    let onSync: () -> Void

    private var isConnected: Bool {
        authStatus == .authorized || authStatus == .limited
    }

    var body: some View {
        Button(action: onSync) {
            HStack {
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.title2)
                    .foregroundStyle(isConnected ? .purple : .secondary)
                    .frame(width: 32)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Apple Photos")
                        .font(.body)
                        .foregroundStyle(.primary)

                    if isConnected {
                        if isScanning {
                            Text("Scanning... Tap to view progress")
                                .font(.caption)
                                .foregroundStyle(.blue)
                        } else if let date = lastSynced {
                            Text("Last synced \(date.formatted(date: .abbreviated, time: .omitted))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            Text("Not yet synced")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        Text("Not connected")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                if isScanning {
                    HStack(spacing: 8) {
                        ProgressView()
                            .scaleEffect(0.8)
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else if isConnected {
                    Text("Sync")
                        .font(.subheadline)
                        .foregroundStyle(.tint)
                } else {
                    Text("Connect")
                        .font(.subheadline)
                        .foregroundStyle(.tint)
                }
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

import Photos

#Preview {
    ImportSourcesView()
}
