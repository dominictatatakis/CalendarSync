import SwiftUI

struct CreateSharedEventView: View {
    @EnvironmentObject var auth: AuthViewModel
    @EnvironmentObject var friends: FriendsViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var location = ""
    @State private var notes = ""
    @State private var startDate = Date.now.roundedToNextHour()
    @State private var endDate = Date.now.roundedToNextHour().addingTimeInterval(3600)
    @State private var selectedFriendIDs: Set<String> = []
    @State private var friendEmails: [String: String] = [:]
    @State private var didSend = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Event details") {
                    TextField("Title", text: $title)
                    TextField("Location (optional)", text: $location)
                    DatePicker("Starts", selection: $startDate, displayedComponents: [.date, .hourAndMinute])
                    DatePicker("Ends",   selection: $endDate,   displayedComponents: [.date, .hourAndMinute])
                        .onChange(of: startDate) { _, new in
                            if endDate <= new { endDate = new.addingTimeInterval(3600) }
                        }
                    TextField("Notes (optional)", text: $notes, axis: .vertical)
                        .lineLimit(3, reservesSpace: false)
                }

                Section("Invite friends") {
                    ForEach(friends.friends) { friend in
                        let isSelected = selectedFriendIDs.contains(friend.user.id)
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(isSelected ? Color.accentColor : .secondary)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(friend.user.displayName).font(.subheadline.weight(.medium))
                                    Text(friend.user.email).font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                            }
                            .contentShape(Rectangle())
                            .onTapGesture { toggle(friend.user.id, email: friend.user.email) }

                            if isSelected {
                                TextField("Email for invite", text: emailBinding(for: friend.user.id))
                                    .font(.caption)
                                    .keyboardType(.emailAddress)
                                    .textContentType(.emailAddress)
                                    .autocapitalization(.none)
                                    .padding(6)
                                    .background(Color.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 6))
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }

                if didSend {
                    Section {
                        HStack {
                            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                            Text("Invites sent! Friends will receive an email.")
                                .font(.subheadline)
                        }
                    }
                }
            }
            .navigationTitle("New Event")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Send") { send() }
                        .disabled(title.isEmpty || selectedFriendIDs.isEmpty)
                }
            }
        }
    }

    private func toggle(_ id: String, email: String) {
        if selectedFriendIDs.contains(id) {
            selectedFriendIDs.remove(id)
        } else {
            selectedFriendIDs.insert(id)
            if friendEmails[id] == nil { friendEmails[id] = email }
        }
    }

    private func emailBinding(for id: String) -> Binding<String> {
        Binding(
            get: { friendEmails[id, default: ""] },
            set: { friendEmails[id] = $0 }
        )
    }

    private func send() {
        HapticFeedback.success()
        let event = SharedEvent(
            id: UUID().uuidString,
            title: title,
            startDate: startDate,
            endDate: endDate,
            location: location.isEmpty ? nil : location,
            notes: notes.isEmpty ? nil : notes,
            organizerID: auth.currentUser?.id ?? "dev-user",
            organizerName: auth.currentUser?.displayName ?? "You",
            invites: []
        )
        friends.sendInvites(event: event, to: Array(selectedFriendIDs), emails: friendEmails)
        withAnimation { didSend = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { dismiss() }
    }
}

private extension Date {
    func roundedToNextHour() -> Date {
        let cal = Calendar.current
        let minutes = cal.component(.minute, from: self)
        let toAdd = minutes == 0 ? 0 : 60 - minutes
        return cal.date(byAdding: .minute, value: toAdd, to: self) ?? self
    }
}
