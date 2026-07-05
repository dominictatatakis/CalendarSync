import UserNotifications
import UIKit

// MARK: - Deep link destination

enum NotificationDeepLink: Equatable {
    case friendRequests
    case eventInvite(id: String)
}

// MARK: - Manager

@MainActor
final class NotificationManager: NSObject, ObservableObject {

    static let shared = NotificationManager()

    @Published var deepLink: NotificationDeepLink?

    private let service = SupabaseService()

    private override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }

    // MARK: - Permission & registration

    func requestPermission() async {
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .badge, .sound])
            if granted {
                UIApplication.shared.registerForRemoteNotifications()
            }
        } catch {
            print("[APNs] Permission error: \(error)")
        }
    }

    // MARK: - Token handling

    func handleToken(_ data: Data) async {
        let token = data.map { String(format: "%02x", $0) }.joined()
        print("[APNs] Device token: \(token)")
        try? await service.saveDeviceToken(token)
    }

    // MARK: - Payload routing

    func handlePayload(_ userInfo: [AnyHashable: Any]) {
        guard let type = userInfo["type"] as? String else { return }
        switch type {
        case "friend_request":
            deepLink = .friendRequests
        case "event_invite":
            let id = userInfo["invite_id"] as? String ?? ""
            deepLink = .eventInvite(id: id)
        default:
            break
        }
    }

    // MARK: - Badge

    func syncBadge(count: Int) {
        UNUserNotificationCenter.current().setBadgeCount(count) { _ in }
    }

    // MARK: - Debug test notifications

    #if DEBUG
    func scheduleTestNotification(type: String) {
        let content = UNMutableNotificationContent()
        content.sound = .default
        var info: [String: Any] = ["type": type]

        switch type {
        case "friend_request":
            content.title = "New Friend Request"
            content.body = "Taylor Swift wants to connect"
            content.badge = 1
        case "event_invite":
            content.title = "New Event Invite"
            content.body = "Sarah Chen invited you to Rooftop drinks"
            info["invite_id"] = "mock-invite-1"
            content.badge = 1
        default:
            return
        }

        content.userInfo = info
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 4, repeats: false)
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: trigger
        )
        UNUserNotificationCenter.current().add(request)
    }
    #endif
}

// MARK: - UNUserNotificationCenterDelegate

extension NotificationManager: UNUserNotificationCenterDelegate {

    // Show banner even when app is in foreground
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        return [.banner, .badge, .sound]
    }

    // Handle tap on a notification
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        handlePayload(response.notification.request.content.userInfo)
    }
}
