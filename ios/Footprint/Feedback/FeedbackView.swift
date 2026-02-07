import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Feedback Models

enum FeedbackType: String, CaseIterable, Codable {
    case bug = "bug"
    case feature = "feature"
    case improvement = "improvement"
    case general = "general"

    var displayName: String {
        switch self {
        case .bug: return "Bug Report"
        case .feature: return "Feature Request"
        case .improvement: return "Improvement"
        case .general: return "General Feedback"
        }
    }

    var icon: String {
        switch self {
        case .bug: return "ladybug"
        case .feature: return "lightbulb"
        case .improvement: return "arrow.up.circle"
        case .general: return "bubble.left"
        }
    }
}

enum FeedbackStatus: String, Codable {
    case new = "new"
    case reviewed = "reviewed"
    case inProgress = "in_progress"
    case completed = "completed"
    case declined = "declined"

    var displayName: String {
        switch self {
        case .new: return "New"
        case .reviewed: return "Reviewed"
        case .inProgress: return "In Progress"
        case .completed: return "Completed"
        case .declined: return "Declined"
        }
    }

    var color: Color {
        switch self {
        case .new: return .blue
        case .reviewed: return .orange
        case .inProgress: return .purple
        case .completed: return .green
        case .declined: return .gray
        }
    }
}

struct FeedbackItem: Identifiable, Codable {
    let id: String  // feedback_id
    let type: FeedbackType
    let title: String
    let status: FeedbackStatus
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id = "feedback_id"
        case type
        case title
        case status
        case createdAt = "created_at"
    }
}

// MARK: - Feedback View

struct FeedbackView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var feedbackItems: [FeedbackItem] = []
    @State private var isLoading = false
    @State private var showingNewFeedback = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            Group {
                if isLoading && feedbackItems.isEmpty {
                    ProgressView("Loading...")
                } else if let error = error {
                    ContentUnavailableView {
                        Label("Error", systemImage: "exclamationmark.triangle")
                    } description: {
                        Text(error)
                    } actions: {
                        Button("Retry") {
                            Task { await loadFeedback() }
                        }
                    }
                } else if feedbackItems.isEmpty {
                    ContentUnavailableView {
                        Label("No Feedback Yet", systemImage: "bubble.left.and.bubble.right")
                    } description: {
                        Text("Share your ideas, report bugs, or suggest improvements!")
                    } actions: {
                        Button("Submit Feedback") {
                            showingNewFeedback = true
                        }
                        .buttonStyle(.borderedProminent)
                    }
                } else {
                    List {
                        ForEach(feedbackItems) { item in
                            FeedbackRow(item: item)
                        }
                    }
                    .refreshable {
                        await loadFeedback()
                    }
                }
            }
            .navigationTitle("Feedback")
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button {
                        showingNewFeedback = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("New feedback")
                    .accessibilityHint("Submit new feedback or report a bug")
                }
            }
            .sheet(isPresented: $showingNewFeedback) {
                NewFeedbackView(onSubmit: {
                    Task { await loadFeedback() }
                })
            }
            .task {
                await loadFeedback()
            }
        }
    }

    private func loadFeedback() async {
        isLoading = true
        error = nil

        do {
            feedbackItems = try await FeedbackAPI.getMyFeedback()
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }
}

// MARK: - Feedback Row

struct FeedbackRow: View {
    let item: FeedbackItem

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: item.type.icon)
                .font(.title2)
                .foregroundStyle(.secondary)
                .frame(width: 32)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.headline)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    Text(item.type.displayName)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text("\u{2022}")
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)

                    Text(item.status.displayName)
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(item.status.color.opacity(0.15))
                        .foregroundStyle(item.status.color)
                        .clipShape(Capsule())
                }
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(item.title), \(item.type.displayName), status: \(item.status.displayName)")
    }
}

// MARK: - New Feedback View

struct NewFeedbackView: View {
    @Environment(\.dismiss) private var dismiss
    let onSubmit: () -> Void

    @State private var selectedType: FeedbackType = .general
    @State private var title = ""
    @State private var description = ""
    @State private var isSubmitting = false
    @State private var error: String?

    private var isValid: Bool {
        title.count >= 3 && description.count >= 10
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Type", selection: $selectedType) {
                        ForEach(FeedbackType.allCases, id: \.self) { type in
                            Label(type.displayName, systemImage: type.icon)
                                .tag(type)
                        }
                    }
                    .pickerStyle(.menu)
                } header: {
                    Text("Feedback Type")
                }

                Section {
                    TextField("Brief summary", text: $title)
                        #if os(iOS)
                        .textInputAutocapitalization(.sentences)
                        #endif
                } header: {
                    Text("Title")
                } footer: {
                    Text("Minimum 3 characters")
                }

                Section {
                    TextEditor(text: $description)
                        .frame(minHeight: 150)
                } header: {
                    Text("Description")
                } footer: {
                    Text("\(description.count)/2000 characters (minimum 10)")
                }

                if let error = error {
                    Section {
                        Text(error)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("New Feedback")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Submit") {
                        Task { await submitFeedback() }
                    }
                    .disabled(!isValid || isSubmitting)
                }
            }
        }
    }

    private func submitFeedback() async {
        isSubmitting = true
        error = nil

        do {
            try await FeedbackAPI.submitFeedback(
                type: selectedType,
                title: title,
                description: description
            )
            onSubmit()
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }

        isSubmitting = false
    }
}

// MARK: - Feedback API

enum FeedbackAPI {
    static func getMyFeedback() async throws -> [FeedbackItem] {
        try await APIClient.shared.request(
            path: "/feedback/",
            method: .get
        )
    }

    static func submitFeedback(
        type: FeedbackType,
        title: String,
        description: String
    ) async throws {
        struct CreateRequest: Encodable {
            let type: String
            let title: String
            let description: String
            let app_version: String?
            let device_info: String?
        }

        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
        #if os(iOS)
        let model = await UIDevice.current.model
        let systemVersion = await UIDevice.current.systemVersion
        let deviceInfo = "\(model) - iOS \(systemVersion)"
        #else
        let deviceInfo = "macOS"
        #endif

        let _: FeedbackItem = try await APIClient.shared.request(
            path: "/feedback/",
            method: .post,
            body: CreateRequest(
                type: type.rawValue,
                title: title,
                description: description,
                app_version: appVersion,
                device_info: deviceInfo
            )
        )
    }
}

#Preview {
    FeedbackView()
}
