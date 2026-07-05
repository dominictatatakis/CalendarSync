import SwiftUI

struct EventSharingSheet: View {
    let event: CalendarEvent
    @EnvironmentObject var vm: CalendarViewModel
    @EnvironmentObject var auth: AuthViewModel
    @EnvironmentObject var friends: FriendsViewModel
    @State private var showDetails = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(event.title)
                            .font(.headline)
                        Text("Choose who can see this event and how much detail they can see.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }

                Section("Groups") {
                    ForEach(friends.groups) { group in
                        GroupSharingRow(
                            event: event,
                            group: group,
                            showDetails: $showDetails
                        )
                    }
                }

                Section {
                    Toggle("Show event title & details", isOn: $showDetails)
                    Text("When off, friends only see you as Busy during this time.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Share Event")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

struct GroupSharingRow: View {
    let event: CalendarEvent
    let group: FriendGroup
    @Binding var showDetails: Bool
    @EnvironmentObject var vm: CalendarViewModel
    @EnvironmentObject var auth: AuthViewModel

    private var isShared: Bool {
        vm.isEventShared(event, withGroup: group.id)
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(group.name)
                    .font(.subheadline)
                Text("\(group.memberIDs.count) member\(group.memberIDs.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Toggle("", isOn: Binding(
                get: { isShared },
                set: { _ in toggleShare() }
            ))
        }
    }

    private func toggleShare() {
        guard let uid = auth.currentUser?.id else { return }
        Task {
            try? await vm.toggleShareEvent(event, groupID: group.id, ownerID: uid, showDetails: showDetails)
        }
    }
}
