import SwiftUI

struct FriendsView: View {
    @EnvironmentObject var friends: FriendsViewModel
    @EnvironmentObject var auth: AuthViewModel
    @State private var showAddFriend = false
    @State private var showImportContacts = false
    @State private var searchText = ""
    @State private var selectedInvite: EventInvite?

    private var filteredFriends: [Friend] {
        guard !searchText.isEmpty else { return friends.friends }
        return friends.friends.filter {
            $0.user.displayName.localizedCaseInsensitiveContains(searchText) ||
            $0.user.email.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if friends.isLoading {
                    ProgressView("Loading…")
                } else {
                    list
                }
            }
            .navigationTitle("Friends")
            .searchable(text: $searchText, prompt: "Search friends")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button { showAddFriend = true } label: {
                            Label("Add by Email", systemImage: "person.badge.plus")
                        }
                        Button { showImportContacts = true } label: {
                            Label("Import Contacts", systemImage: "person.2.crop.square.stack")
                        }
                    } label: {
                        Image(systemName: "person.badge.plus")
                    }
                }
            }
            .sheet(isPresented: $showAddFriend) {
                AddFriendView().environmentObject(friends)
            }
            .sheet(isPresented: $showImportContacts) {
                ImportContactsView()
                    .environmentObject(auth)
                    .environmentObject(friends)
            }
            .sheet(item: $selectedInvite) { invite in
                NavigationStack {
                    IncomingInviteView(invite: invite, onDismiss: { selectedInvite = nil })
                        .environmentObject(friends)
                        .environmentObject(auth)
                }
            }
            .refreshable { await friends.load() }
            .onChange(of: friends.pendingNotificationInviteID) { _, newID in
                guard let inviteID = newID else { return }
                let match = friends.incomingInvites.first { $0.id == inviteID }
                if let found = match {
                    selectedInvite = found
                }
                friends.pendingNotificationInviteID = nil
            }
        }
    }

    private var list: some View {
        List {
            // ── Incoming invites ─────────────────────────────────────────
            let pending = friends.incomingInvites.filter { $0.status == .pending }
            if !pending.isEmpty {
                Section {
                    ForEach(pending) { invite in
                        InviteBannerRow(invite: invite)
                            .contentShape(Rectangle())
                            .onTapGesture { selectedInvite = invite }
                            .accessibilityLabel("Invite: \(invite.eventTitle) from \(invite.organizerName)")
                            .accessibilityHint("Tap to view and respond")
                    }
                } header: {
                    Label("Invites", systemImage: "envelope.badge.fill")
                        .foregroundStyle(Color.accentColor)
                }
            }

            // ── Pending friend requests ──────────────────────────────────
            if !friends.pendingRequests.isEmpty {
                Section("Friend requests") {
                    ForEach(friends.pendingRequests) { req in
                        PendingRequestRow(request: req).environmentObject(friends)
                    }
                }
            }

            // ── Friends by group ─────────────────────────────────────────
            if filteredFriends.isEmpty && !searchText.isEmpty {
                Section {
                    ContentUnavailableView.search(text: searchText)
                }
            } else {
                ForEach(friends.groups) { group in
                    let members = filteredFriends.filter { $0.groups.contains(group.id) }
                    if !members.isEmpty {
                        Section(group.name) {
                            ForEach(members) { friend in
                                NavigationLink(destination:
                                    FriendAvailabilityView(friend: friend)
                                        .environmentObject(friends)
                                ) {
                                    FriendRow(friend: friend)
                                }
                            }
                        }
                    }
                }

                let ungrouped = filteredFriends.filter { $0.groups.isEmpty }
                if !ungrouped.isEmpty {
                    Section("Other") {
                        ForEach(ungrouped) { friend in
                            NavigationLink(destination:
                                FriendAvailabilityView(friend: friend)
                                    .environmentObject(friends)
                            ) {
                                FriendRow(friend: friend)
                            }
                        }
                    }
                }

                if friends.friends.isEmpty {
                    emptyState
                }
            }
        }
    }

    private var emptyState: some View {
        Section {
            ContentUnavailableView {
                Label("No Friends Yet", systemImage: "person.2")
            } description: {
                Text("Add friends to see their availability.")
            } actions: {
                Button("Add a Friend") { showAddFriend = true }
                    .buttonStyle(.borderedProminent)
            }
        }
    }
}

// MARK: - Invite banner

struct InviteBannerRow: View {
    let invite: EventInvite

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "calendar.badge.plus")
                .font(.title2)
                .foregroundStyle(Color.accentColor)
                .frame(width: 40)

            VStack(alignment: .leading, spacing: 2) {
                Text(invite.eventTitle)
                    .font(.subheadline.weight(.semibold))
                Text("From \(invite.organizerName) · \(invite.startDate.formatted(.dateTime.weekday(.abbreviated).month().day()))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Friend row

struct FriendRow: View {
    let friend: Friend
    @EnvironmentObject var friends: FriendsViewModel

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(friends.overlayColor(for: friend.user.id).opacity(0.2))
                .frame(width: 40, height: 40)
                .overlay {
                    Text(friend.user.displayName.prefix(1).uppercased())
                        .font(.headline)
                        .foregroundStyle(friends.overlayColor(for: friend.user.id))
                }
            VStack(alignment: .leading, spacing: 2) {
                Text(friend.user.displayName)
                    .font(.subheadline.weight(.medium))
                Text(friend.user.email)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if friends.calendarOverlayFriendIDs.contains(friend.user.id) {
                Image(systemName: "calendar.badge.checkmark")
                    .font(.caption)
                    .foregroundStyle(friends.overlayColor(for: friend.user.id))
            }
        }
    }
}

// MARK: - Pending request row

struct PendingRequestRow: View {
    let request: FriendshipRow
    @EnvironmentObject var friends: FriendsViewModel

    private var requesterName: String {
        friends.friends.first(where: { $0.user.id == request.requesterID })?.user.displayName
            ?? "Alex Johnson" // mock name for unknown requesters
    }

    var body: some View {
        HStack {
            Circle()
                .fill(Color.secondary.opacity(0.15))
                .frame(width: 40, height: 40)
                .overlay {
                    Text(requesterName.prefix(1).uppercased())
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }
            VStack(alignment: .leading, spacing: 2) {
                Text(requesterName)
                    .font(.subheadline.weight(.medium))
                Text("Wants to connect")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Accept") {
                HapticFeedback.success()
                Task { try? await friends.acceptRequest(request) }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
    }
}
