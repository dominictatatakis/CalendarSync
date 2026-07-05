import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var auth: AuthViewModel
    @EnvironmentObject var vm: CalendarViewModel
    @State private var showNameEditor = false
    @State private var newName = ""

    var body: some View {
        NavigationStack {
            List {
                // Profile
                Section("Profile") {
                    HStack(spacing: 12) {
                        Circle()
                            .fill(Color.accentColor.opacity(0.2))
                            .frame(width: 52, height: 52)
                            .overlay {
                                Text(auth.currentUser?.displayName.prefix(1).uppercased() ?? "?")
                                    .font(.title2.bold())
                                    .foregroundStyle(.tint)
                            }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(auth.currentUser?.displayName ?? "–")
                                .font(.headline)
                            Text(auth.currentUser?.email ?? "–")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("Edit") { showNameEditor = true }
                            .font(.subheadline)
                    }
                    .padding(.vertical, 4)
                }

                // Connected calendars
                Section {
                    NavigationLink(destination: ConnectedCalendarsView()) {
                        Label("Connected Calendars", systemImage: "calendar.badge.plus")
                    }
                }

                // Privacy
                Section("Privacy") {
                    LabeledContent("Default visibility") {
                        Text("Busy only")
                            .foregroundStyle(.secondary)
                    }
                    Text("Events are hidden from friends by default. You control sharing per event.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                // Sign out
                Section {
                    Button(role: .destructive) {
                        Task { await auth.signOut() }
                    } label: {
                        Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                }

                #if DEBUG
                Section("Developer") {
                    Button {
                        Task { await NotificationManager.shared.requestPermission() }
                    } label: {
                        Label("Request Notification Permission", systemImage: "bell.badge")
                    }
                    Button {
                        NotificationManager.shared.scheduleTestNotification(type: "friend_request")
                    } label: {
                        Label("Test: Friend Request (4s)", systemImage: "person.badge.plus")
                    }
                    Button {
                        NotificationManager.shared.scheduleTestNotification(type: "event_invite")
                    } label: {
                        Label("Test: Event Invite (4s)", systemImage: "calendar.badge.plus")
                    }
                }
                #endif
            }
            .navigationTitle("Settings")
            .alert("Edit Name", isPresented: $showNameEditor) {
                TextField("Display name", text: $newName)
                Button("Save") {
                    Task { try? await auth.updateDisplayName(newName) }
                }
                Button("Cancel", role: .cancel) {}
            }
            .onAppear { newName = auth.currentUser?.displayName ?? "" }
        }
    }
}
