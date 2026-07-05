import SwiftUI

struct ConnectedCalendarsView: View {
    @EnvironmentObject var vm: CalendarViewModel

    var body: some View {
        List {
            Section {
                Text("Connect your calendar accounts to see all your events in one place. Your data stays on your device — only availability (busy/free) is shared with friends.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            // Apple Calendar
            Section {
                CalendarProviderRow(
                    source: .apple,
                    statusLabel: appleStatusLabel,
                    isConnected: vm.unifiedService.apple.authStatus == .fullAccess
                ) {
                    Task { await vm.unifiedService.apple.requestAccess() }
                }
            }

            // Google Calendar
            Section {
                CalendarProviderRow(
                    source: .google,
                    statusLabel: vm.unifiedService.google.isConnected ? "Connected" : "Not connected",
                    isConnected: vm.unifiedService.google.isConnected
                ) {
                    connectGoogle()
                }
                if let error = vm.unifiedService.google.lastError {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
                if vm.unifiedService.google.isConnected {
                    Button("Sync now") {
                        Task { await vm.fetchEvents() }
                    }
                    .font(.subheadline)
                    Button("Disconnect Google", role: .destructive) {
                        vm.unifiedService.google.signOut()
                    }
                }
            }

            // Outlook — only shown when Azure credentials are configured
            if vm.unifiedService.outlook.isConfigured {
                Section {
                    CalendarProviderRow(
                        source: .outlook,
                        statusLabel: vm.unifiedService.outlook.isConnected ? "Connected" : "Not connected",
                        isConnected: vm.unifiedService.outlook.isConnected
                    ) {
                        connectOutlook()
                    }
                    if vm.unifiedService.outlook.isConnected {
                        Button("Disconnect Outlook", role: .destructive) {
                            vm.unifiedService.outlook.signOut()
                        }
                    }
                }
            } else {
                Section {
                    HStack(spacing: 12) {
                        Image(systemName: CalendarSource.outlook.icon)
                            .font(.title2)
                            .foregroundStyle(CalendarSource.outlook.color)
                            .frame(width: 32)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Outlook")
                                .font(.subheadline.weight(.medium))
                            Text("Azure credentials not configured")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .navigationTitle("Calendars")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var appleStatusLabel: String {
        switch vm.unifiedService.apple.authStatus {
        case .fullAccess:    return "Connected"
        case .denied:        return "Access denied — enable in Settings"
        case .restricted:    return "Restricted"
        default:             return "Not connected"
        }
    }

    private func connectGoogle() {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let root = windowScene.windows.first?.rootViewController else { return }
        Task {
            try? await vm.unifiedService.google.signIn(presenting: root)
            await vm.fetchEvents()
        }
    }

    private func connectOutlook() {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let root = windowScene.windows.first?.rootViewController else { return }
        Task {
            try? await vm.unifiedService.outlook.signIn(presenting: root)
            await vm.fetchEvents()
        }
    }
}

struct CalendarProviderRow: View {
    let source: CalendarSource
    let statusLabel: String
    let isConnected: Bool
    let onConnect: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: source.icon)
                .font(.title2)
                .foregroundStyle(source.color)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(source.rawValue)
                    .font(.subheadline.weight(.medium))
                Text(statusLabel)
                    .font(.caption)
                    .foregroundStyle(isConnected ? .green : .secondary)
            }

            Spacer()

            if !isConnected {
                Button("Connect", action: onConnect)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            } else {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            }
        }
        .padding(.vertical, 2)
    }
}
