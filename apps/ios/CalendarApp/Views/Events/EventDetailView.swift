import SwiftUI

struct EventDetailView: View {
    let event: CalendarEvent
    @EnvironmentObject var vm: CalendarViewModel
    @EnvironmentObject var auth: AuthViewModel
    @EnvironmentObject var friends: FriendsViewModel
    @State private var showSharingSheet = false

    var body: some View {
        List {
            // Header
            Section {
                HStack(spacing: 12) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(event.color)
                        .frame(width: 6, height: 48)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(event.title)
                            .font(.title3.bold())
                        Label(event.calendarName, systemImage: event.source.icon)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }

            // Time
            Section {
                if event.isAllDay {
                    LabeledContent("Date") {
                        Text(event.startDate.formatted(.dateTime.weekday(.wide).month().day().year()))
                    }
                    Label("All Day", systemImage: "sun.max")
                } else {
                    LabeledContent("Starts") {
                        Text(event.startDate.formatted(.dateTime.weekday(.abbreviated).month().day().hour().minute()))
                    }
                    LabeledContent("Ends") {
                        Text(event.endDate.formatted(.dateTime.weekday(.abbreviated).month().day().hour().minute()))
                    }
                    LabeledContent("Duration") {
                        Text(durationString)
                    }
                }
            }

            // Sharing
            Section("Visibility") {
                if let group = friends.closeFriendsGroup() {
                    let isShared = vm.isEventShared(event, withGroup: group.id)
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Share with Close Friends")
                                .font(.subheadline)
                            Text(isShared ? "Showing as busy" : "Hidden from friends")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Toggle("", isOn: Binding(
                            get: { isShared },
                            set: { _ in showSharingSheet = true }
                        ))
                    }
                } else {
                    Text("Add friends to share availability")
                        .foregroundStyle(.secondary)
                        .font(.subheadline)
                }
            }
        }
        .navigationTitle("Event")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showSharingSheet) {
            EventSharingSheet(event: event)
                .environmentObject(vm)
                .environmentObject(auth)
                .environmentObject(friends)
        }
        .onAppear {
            if let uid = auth.currentUser?.id {
                Task { await vm.loadShareSettings(ownerID: uid) }
            }
        }
    }

    private var durationString: String {
        let minutes = Int(event.duration / 60)
        if minutes < 60 { return "\(minutes)m" }
        let h = minutes / 60, m = minutes % 60
        return m > 0 ? "\(h)h \(m)m" : "\(h)h"
    }
}
