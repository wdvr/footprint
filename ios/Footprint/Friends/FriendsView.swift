import Contacts
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Friend Models

struct Friend: Identifiable, Codable {
    let id: String  // user_id
    var displayName: String?
    var profilePictureUrl: String?
    var countriesVisited: Int
    var usStatesVisited: Int
    var canadianProvincesVisited: Int

    enum CodingKeys: String, CodingKey {
        case id = "user_id"
        case displayName = "display_name"
        case profilePictureUrl = "profile_picture_url"
        case countriesVisited = "countries_visited"
        case usStatesVisited = "us_states_visited"
        case canadianProvincesVisited = "canadian_provinces_visited"
    }
}

struct FriendRequest: Identifiable, Codable {
    let id: String  // request_id
    let fromUserId: String
    let toUserId: String
    let status: String
    let message: String?
    let createdAt: String
    let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case id = "request_id"
        case fromUserId = "from_user_id"
        case toUserId = "to_user_id"
        case status
        case message
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct FriendComparison: Codable {
    let friend: Friend
    let commonCountries: [String]
    let friendUniqueCountries: [String]
    let userUniqueCountries: [String]

    enum CodingKeys: String, CodingKey {
        case friend
        case commonCountries = "common_countries"
        case friendUniqueCountries = "friend_unique_countries"
        case userUniqueCountries = "user_unique_countries"
    }
}

// MARK: - Friends View

struct FriendsView: View {
    @State private var friends: [Friend] = []
    @State private var pendingRequests: [FriendRequest] = []
    @State private var isLoading = false
    @State private var error: String?
    @State private var showingAddFriend = false
    @State private var selectedFriend: Friend?
    @State private var showingComparison = false

    var body: some View {
        NavigationStack {
            Group {
                if isLoading && friends.isEmpty {
                    ProgressView("Loading friends...")
                } else if let error = error {
                    ContentUnavailableView {
                        Label("Error", systemImage: "exclamationmark.triangle")
                    } description: {
                        Text(error)
                    } actions: {
                        Button("Retry") {
                            Task { await loadData() }
                        }
                    }
                } else if friends.isEmpty && pendingRequests.isEmpty {
                    ContentUnavailableView {
                        Label("No Friends Yet", systemImage: "person.2")
                    } description: {
                        Text("Add friends to compare your travel adventures!")
                    } actions: {
                        Button("Add Friends") {
                            showingAddFriend = true
                        }
                        .buttonStyle(.borderedProminent)
                    }
                } else {
                    List {
                        // Pending requests section
                        if !pendingRequests.isEmpty {
                            Section("Friend Requests") {
                                ForEach(pendingRequests) { request in
                                    FriendRequestRow(
                                        request: request,
                                        onAccept: { await acceptRequest(request) },
                                        onReject: { await rejectRequest(request) }
                                    )
                                }
                            }
                        }

                        // Friends section
                        Section("Friends (\(friends.count))") {
                            ForEach(friends) { friend in
                                Button {
                                    selectedFriend = friend
                                    showingComparison = true
                                } label: {
                                    FriendRow(friend: friend)
                                }
                                .buttonStyle(.plain)
                            }
                            .onDelete(perform: removeFriends)
                        }
                    }
                    .refreshable {
                        await loadData()
                    }
                }
            }
            .navigationTitle("Friends")
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button {
                        showingAddFriend = true
                    } label: {
                        Image(systemName: "person.badge.plus")
                    }
                    .accessibilityLabel("Add friend")
                    .accessibilityHint("Search contacts to send a friend request")
                }
            }
            .sheet(isPresented: $showingAddFriend) {
                AddFriendView(onFriendAdded: {
                    Task { await loadData() }
                })
            }
            .sheet(isPresented: $showingComparison) {
                if let friend = selectedFriend {
                    FriendComparisonView(friend: friend)
                }
            }
            .task {
                await loadData()
            }
        }
    }

    private func loadData() async {
        isLoading = true
        error = nil

        do {
            async let friendsTask = FriendsAPI.getFriends()
            async let requestsTask = FriendsAPI.getPendingRequests()

            let (loadedFriends, loadedRequests) = try await (friendsTask, requestsTask)
            friends = loadedFriends
            pendingRequests = loadedRequests
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    private func acceptRequest(_ request: FriendRequest) async {
        do {
            try await FriendsAPI.respondToRequest(requestId: request.id, accept: true)
            await loadData()
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func rejectRequest(_ request: FriendRequest) async {
        do {
            try await FriendsAPI.respondToRequest(requestId: request.id, accept: false)
            await loadData()
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func removeFriends(at offsets: IndexSet) {
        Task {
            for index in offsets {
                let friend = friends[index]
                do {
                    try await FriendsAPI.removeFriend(friendId: friend.id)
                } catch {
                    self.error = error.localizedDescription
                }
            }
            await loadData()
        }
    }
}

// MARK: - Friend Row

struct FriendRow: View {
    let friend: Friend

    var body: some View {
        HStack(spacing: 12) {
            // Avatar
            Circle()
                .fill(Color.blue.opacity(0.2))
                .frame(width: 50, height: 50)
                .overlay {
                    Text(initials)
                        .font(.headline)
                        .foregroundStyle(.blue)
                }

            VStack(alignment: .leading, spacing: 4) {
                Text(friend.displayName ?? "Friend")
                    .font(.headline)

                HStack(spacing: 8) {
                    Label("\(friend.countriesVisited)", systemImage: "flag.fill")
                    Label("\(friend.usStatesVisited + friend.canadianProvincesVisited)", systemImage: "mappin")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(friend.displayName ?? "Friend"), \(friend.countriesVisited) countries visited")
    }

    private var initials: String {
        guard let name = friend.displayName else { return "?" }
        let parts = name.split(separator: " ")
        if parts.count >= 2 {
            return "\(parts[0].prefix(1))\(parts[1].prefix(1))"
        }
        return String(name.prefix(2)).uppercased()
    }
}

// MARK: - Friend Request Row

struct FriendRequestRow: View {
    let request: FriendRequest
    let onAccept: () async -> Void
    let onReject: () async -> Void

    @State private var isProcessing = false

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Friend Request")
                    .font(.headline)
                if let message = request.message, !message.isEmpty {
                    Text(message)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Text("From: \(request.fromUserId.prefix(8))...")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if isProcessing {
                ProgressView()
            } else {
                HStack(spacing: 12) {
                    Button {
                        isProcessing = true
                        Task {
                            await onAccept()
                            isProcessing = false
                        }
                    } label: {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.green)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Accept friend request")

                    Button {
                        isProcessing = true
                        Task {
                            await onReject()
                            isProcessing = false
                        }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.red)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Reject friend request")
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Add Friend View

struct AddFriendView: View {
    @Environment(\.dismiss) private var dismiss
    let onFriendAdded: () -> Void

    @State private var searchText = ""
    @State private var contacts: [CNContact] = []
    @State private var isLoadingContacts = false
    @State private var contactsError: String?
    @State private var showingContactsPermission = false
    @State private var selectedContact: CNContact?
    @State private var isSendingRequest = false
    @State private var requestMessage = ""

    var body: some View {
        NavigationStack {
            Group {
                if isLoadingContacts {
                    ProgressView("Loading contacts...")
                } else if let error = contactsError {
                    ContentUnavailableView {
                        Label("Contacts Unavailable", systemImage: "person.crop.circle.badge.exclamationmark")
                    } description: {
                        Text(error)
                    } actions: {
                        #if os(iOS)
                        Button("Open Settings") {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        }
                        #endif
                    }
                } else {
                    List {
                        Section {
                            TextField("Search by name or email", text: $searchText)
                                .textContentType(.name)
                        }

                        Section("Contacts") {
                            ForEach(filteredContacts, id: \.identifier) { contact in
                                Button {
                                    selectedContact = contact
                                } label: {
                                    ContactRow(contact: contact)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Add Friend")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .sheet(item: $selectedContact) { contact in
                SendRequestSheet(
                    contact: contact,
                    message: $requestMessage,
                    isSending: $isSendingRequest,
                    onSend: {
                        await sendFriendRequest(to: contact)
                    },
                    onCancel: {
                        selectedContact = nil
                    }
                )
                .presentationDetents([.height(300)])
            }
            .task {
                await loadContacts()
            }
        }
    }

    private var filteredContacts: [CNContact] {
        if searchText.isEmpty {
            return contacts
        }
        return contacts.filter { contact in
            let fullName = "\(contact.givenName) \(contact.familyName)".lowercased()
            let emails = contact.emailAddresses.map { $0.value as String }.joined(separator: " ").lowercased()
            let query = searchText.lowercased()
            return fullName.contains(query) || emails.contains(query)
        }
    }

    private func loadContacts() async {
        isLoadingContacts = true
        contactsError = nil

        let store = CNContactStore()
        let authStatus = CNContactStore.authorizationStatus(for: .contacts)

        switch authStatus {
        case .notDetermined:
            do {
                let granted = try await store.requestAccess(for: .contacts)
                if granted {
                    await fetchContacts(store: store)
                } else {
                    contactsError = "Please grant access to your contacts to add friends."
                }
            } catch {
                contactsError = error.localizedDescription
            }

        case .authorized, .limited:
            await fetchContacts(store: store)

        case .denied, .restricted:
            contactsError = "Contacts access is denied. Please enable it in Settings."

        @unknown default:
            contactsError = "Unknown authorization status."
        }

        isLoadingContacts = false
    }

    private func fetchContacts(store: CNContactStore) async {
        let keysToFetch: [CNKeyDescriptor] = [
            CNContactGivenNameKey as CNKeyDescriptor,
            CNContactFamilyNameKey as CNKeyDescriptor,
            CNContactEmailAddressesKey as CNKeyDescriptor,
            CNContactPhoneNumbersKey as CNKeyDescriptor,
            CNContactImageDataAvailableKey as CNKeyDescriptor,
            CNContactThumbnailImageDataKey as CNKeyDescriptor
        ]

        let request = CNContactFetchRequest(keysToFetch: keysToFetch)
        request.sortOrder = .givenName

        var fetchedContacts: [CNContact] = []

        do {
            try store.enumerateContacts(with: request) { contact, _ in
                // Only include contacts with email (needed for finding users)
                if !contact.emailAddresses.isEmpty {
                    fetchedContacts.append(contact)
                }
            }
            contacts = fetchedContacts
        } catch {
            contactsError = error.localizedDescription
        }
    }

    private func sendFriendRequest(to contact: CNContact) async {
        isSendingRequest = true

        // For now, we'll use the email as the user identifier
        // In a real app, you'd look up the user by email first
        guard let email = contact.emailAddresses.first?.value as String? else {
            isSendingRequest = false
            return
        }

        do {
            // Note: The backend currently expects a user_id, not email
            // You'd need to add a user lookup by email endpoint
            try await FriendsAPI.sendRequest(
                toUserId: email,  // Placeholder - would need email lookup
                message: requestMessage.isEmpty ? nil : requestMessage
            )
            selectedContact = nil
            requestMessage = ""
            onFriendAdded()
            dismiss()
        } catch {
            // Handle error - could show an alert
            print("Failed to send friend request: \(error)")
        }

        isSendingRequest = false
    }
}


// MARK: - Contact Row

struct ContactRow: View {
    let contact: CNContact

    var body: some View {
        HStack(spacing: 12) {
            // Avatar - just show initials (works on all platforms)
            Circle()
                .fill(Color.gray.opacity(0.2))
                .frame(width: 44, height: 44)
                .overlay {
                    Text(initials)
                        .font(.subheadline)
                        .foregroundStyle(.gray)
                }

            VStack(alignment: .leading, spacing: 2) {
                Text("\(contact.givenName) \(contact.familyName)")
                    .font(.body)

                if let email = contact.emailAddresses.first?.value as String? {
                    Text(email)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var initials: String {
        let first = contact.givenName.prefix(1)
        let last = contact.familyName.prefix(1)
        return "\(first)\(last)".uppercased()
    }
}

// MARK: - Send Request Sheet

struct SendRequestSheet: View {
    let contact: CNContact
    @Binding var message: String
    @Binding var isSending: Bool
    let onSend: () async -> Void
    let onCancel: () -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // Contact info
                HStack(spacing: 12) {
                    Circle()
                        .fill(Color.blue.opacity(0.2))
                        .frame(width: 60, height: 60)
                        .overlay {
                            Text("\(contact.givenName.prefix(1))\(contact.familyName.prefix(1))")
                                .font(.title2)
                                .foregroundStyle(.blue)
                        }

                    VStack(alignment: .leading) {
                        Text("\(contact.givenName) \(contact.familyName)")
                            .font(.headline)
                        if let email = contact.emailAddresses.first?.value as String? {
                            Text(email)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                }
                .padding(.horizontal)

                // Message field
                TextField("Add a message (optional)", text: $message, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(3)
                    .padding(.horizontal)

                // Send button
                Button {
                    Task {
                        await onSend()
                    }
                } label: {
                    if isSending {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Text("Send Friend Request")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isSending)
                .padding(.horizontal)

                Spacer()
            }
            .padding(.top)
            .navigationTitle("Send Request")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onCancel()
                    }
                }
            }
        }
    }
}

// MARK: - Friend Comparison View

struct FriendComparisonView: View {
    let friend: Friend
    @Environment(\.dismiss) private var dismiss

    @State private var comparison: FriendComparison?
    @State private var isLoading = true
    @State private var error: String?

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("Loading comparison...")
                } else if let error = error {
                    ContentUnavailableView {
                        Label("Error", systemImage: "exclamationmark.triangle")
                    } description: {
                        Text(error)
                    }
                } else if let comparison = comparison {
                    ScrollView {
                        VStack(spacing: 24) {
                            // Friend header
                            VStack(spacing: 8) {
                                Circle()
                                    .fill(Color.blue.opacity(0.2))
                                    .frame(width: 80, height: 80)
                                    .overlay {
                                        Text(initials)
                                            .font(.title)
                                            .foregroundStyle(.blue)
                                    }

                                Text(friend.displayName ?? "Friend")
                                    .font(.title2)
                                    .fontWeight(.semibold)

                                Text("\(friend.countriesVisited) countries visited")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.top)

                            // Stats comparison
                            HStack(spacing: 20) {
                                ComparisonStat(
                                    title: "Common",
                                    count: comparison.commonCountries.count,
                                    color: .green,
                                    icon: "person.2.fill"
                                )
                                ComparisonStat(
                                    title: "Only You",
                                    count: comparison.userUniqueCountries.count,
                                    color: .blue,
                                    icon: "person.fill"
                                )
                                ComparisonStat(
                                    title: "Only \(friend.displayName?.split(separator: " ").first.map(String.init) ?? "Friend")",
                                    count: comparison.friendUniqueCountries.count,
                                    color: .orange,
                                    icon: "person.fill"
                                )
                            }
                            .padding(.horizontal)

                            // Country lists
                            VStack(alignment: .leading, spacing: 16) {
                                if !comparison.commonCountries.isEmpty {
                                    CountryListSection(
                                        title: "Countries You've Both Visited",
                                        countries: comparison.commonCountries,
                                        color: .green
                                    )
                                }

                                if !comparison.userUniqueCountries.isEmpty {
                                    CountryListSection(
                                        title: "Countries Only You've Visited",
                                        countries: comparison.userUniqueCountries,
                                        color: .blue
                                    )
                                }

                                if !comparison.friendUniqueCountries.isEmpty {
                                    CountryListSection(
                                        title: "Countries Only \(friend.displayName ?? "Friend") Has Visited",
                                        countries: comparison.friendUniqueCountries,
                                        color: .orange
                                    )
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                }
            }
            .navigationTitle("Compare")
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
            .task {
                await loadComparison()
            }
        }
    }

    private var initials: String {
        guard let name = friend.displayName else { return "?" }
        let parts = name.split(separator: " ")
        if parts.count >= 2 {
            return "\(parts[0].prefix(1))\(parts[1].prefix(1))"
        }
        return String(name.prefix(2)).uppercased()
    }

    private func loadComparison() async {
        isLoading = true
        do {
            comparison = try await FriendsAPI.compareWith(friendId: friend.id)
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }
}

struct ComparisonStat: View {
    let title: String
    let count: Int
    let color: Color
    let icon: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
                .accessibilityHidden(true)

            Text("\(count)")
                .font(.title)
                .fontWeight(.bold)

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(count) countries")
    }
}

struct CountryListSection: View {
    let title: String
    let countries: [String]
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(countries, id: \.self) { code in
                    let name = GeographicData.countries.first { $0.id == code }?.name ?? code
                    HStack {
                        Circle()
                            .fill(color.opacity(0.3))
                            .frame(width: 8, height: 8)
                        Text(name)
                            .font(.caption)
                            .lineLimit(1)
                        Spacer()
                    }
                    .padding(.vertical, 4)
                    .padding(.horizontal, 8)
                    .background(Color.secondary.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
            }
        }
    }
}

// MARK: - Friends API

enum FriendsAPI {
    static func getFriends() async throws -> [Friend] {
        try await APIClient.shared.request(
            path: "/friends/",
            method: .get
        )
    }

    static func getPendingRequests() async throws -> [FriendRequest] {
        try await APIClient.shared.request(
            path: "/friends/requests",
            method: .get
        )
    }

    static func sendRequest(toUserId: String, message: String?) async throws {
        struct RequestBody: Encodable {
            let to_user_id: String
            let message: String?
        }
        let _: [String: String] = try await APIClient.shared.request(
            path: "/friends/requests",
            method: .post,
            body: RequestBody(to_user_id: toUserId, message: message)
        )
    }

    static func respondToRequest(requestId: String, accept: Bool) async throws {
        struct ResponseBody: Encodable {
            let accept: Bool
        }
        let _: [String: String] = try await APIClient.shared.request(
            path: "/friends/requests/\(requestId)/respond",
            method: .post,
            body: ResponseBody(accept: accept)
        )
    }

    static func removeFriend(friendId: String) async throws {
        let _: [String: String] = try await APIClient.shared.request(
            path: "/friends/\(friendId)",
            method: .delete
        )
    }

    static func compareWith(friendId: String) async throws -> FriendComparison {
        try await APIClient.shared.request(
            path: "/friends/\(friendId)/compare",
            method: .get
        )
    }
}

#Preview {
    FriendsView()
}
