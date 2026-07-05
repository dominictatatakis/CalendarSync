import SwiftUI
import GoogleSignIn

@main
struct CalendarAppApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    @StateObject private var authViewModel      = AuthViewModel()
    @StateObject private var calendarViewModel  = CalendarViewModel()
    @StateObject private var friendsViewModel   = FriendsViewModel()
    @StateObject private var notificationManager = NotificationManager.shared

    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            Group {
                if authViewModel.isAuthenticated {
                    ContentView()
                        .environmentObject(authViewModel)
                        .environmentObject(calendarViewModel)
                        .environmentObject(friendsViewModel)
                        .environmentObject(notificationManager)
                        .task {
                            await calendarViewModel.loadAll()
                            await friendsViewModel.load()
                            await notificationManager.requestPermission()
                        }
                } else {
                    PhoneAuthView()
                        .environmentObject(authViewModel)
                }
            }
            .onOpenURL { url in
                GIDSignIn.sharedInstance.handle(url)
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active && authViewModel.isAuthenticated {
                Task {
                    await calendarViewModel.fetchEvents()
                    await friendsViewModel.load()
                }
            }
        }
    }
}

// MARK: - Root tab view

struct ContentView: View {
    @EnvironmentObject var friendsVM: FriendsViewModel
    @EnvironmentObject var notificationManager: NotificationManager
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            CalendarContainerView()
                .tabItem { Label("Calendar", systemImage: "calendar") }
                .tag(0)

            FriendsView()
                .tabItem { Label("Friends", systemImage: "person.2") }
                .tag(1)
                .badge(friendsVM.inviteBadgeCount)

            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
                .tag(2)
        }
        .onChange(of: notificationManager.deepLink) { _, link in
            guard let link else { return }
            selectedTab = 1  // always land on Friends
            switch link {
            case .friendRequests:
                break  // requests section is at the top of FriendsView
            case .eventInvite(let id):
                friendsVM.pendingNotificationInviteID = id
            }
            notificationManager.deepLink = nil
        }
        .onChange(of: friendsVM.inviteBadgeCount) { _, count in
            notificationManager.syncBadge(count: count)
        }
    }
}
