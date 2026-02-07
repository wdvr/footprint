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
                // Google Section - temporarily disabled
                // TODO: Re-enable when Google Calendar/Gmail import is ready
                /*
                Section {
                    ImportSourceRow(
                        title: "Google Calendar",
                        icon: "calendar",
                        iconColor: .blue,
                        isConnected: googleAuth.isConnected,
                        lastImported: UserDefaults.standard.object(forKey: "lastCalendarImport") as? Date,
                        onAction: { showingGoogleImport = true }
                    )

                    ImportSourceRow(
                        title: "Gmail",
                        icon: "envelope.fill",
                        iconColor: .red,
                        isConnected: googleAuth.isConnected,
                        lastImported: UserDefaults.standard.object(forKey: "lastGmailImport") as? Date,
                        onAction: { showingGoogleImport = true }
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
                */

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

                // Disconnect Section - temporarily disabled with Google import
                /*
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
                */
            }
            .navigationTitle("Import Sources")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            // Google import sheet - temporarily disabled
            // .sheet(isPresented: $showingGoogleImport) {
            //     ImportView()
            // }
            .sheet(isPresented: $showingPhotoImport) {
                PhotoImportView()
            }
            // Google connection check - temporarily disabled
            // .task {
            //     await googleAuth.checkConnectionStatus()
            // }
        }
    }
}

// MARK: - Import Source Row (Reusable)

private struct ImportSourceRow: View {
    let title: String
    let icon: String
    let iconColor: Color
    let isConnected: Bool
    let lastImported: Date?
    let onAction: () -> Void

    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(isConnected ? iconColor : .secondary)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body)

                Group {
                    if isConnected {
                        if let date = lastImported {
                            Text("Last imported \(date.formatted(date: .abbreviated, time: .omitted))")
                        } else {
                            Text("Not yet imported")
                        }
                    } else {
                        Text("Not connected")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            Button(isConnected ? "Reimport" : "Connect") {
                onAction()
            }
            .font(.subheadline)
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
