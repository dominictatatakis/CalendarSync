import Foundation
import GoogleSignIn
import SwiftUI

@MainActor
final class GoogleCalendarService: ObservableObject {
    @Published private(set) var isConnected = false
    @Published var lastError: String?
    private var accessToken: String?

    private let calendarScope = "https://www.googleapis.com/auth/calendar.readonly"

    // MARK: - Auth

    func signIn(presenting viewController: UIViewController) async throws {
        let config = GIDConfiguration(clientID: Secrets.googleClientID)
        GIDSignIn.sharedInstance.configuration = config

        let result = try await GIDSignIn.sharedInstance.signIn(
            withPresenting: viewController,
            hint: nil,
            additionalScopes: [calendarScope]
        )
        accessToken = result.user.accessToken.tokenString
        isConnected = true
    }

    func restoreSession() async {
        do {
            try await GIDSignIn.sharedInstance.restorePreviousSignIn()
            accessToken = GIDSignIn.sharedInstance.currentUser?.accessToken.tokenString
            isConnected = accessToken != nil
        } catch {
            isConnected = false
        }
    }

    func signOut() {
        GIDSignIn.sharedInstance.signOut()
        accessToken = nil
        isConnected = false
    }

    // MARK: - Fetch Events

    func fetchEvents(from startDate: Date, to endDate: Date) async throws -> [CalendarEvent] {
        guard let token = accessToken else { return [] }

        // Refresh token if needed
        if let user = GIDSignIn.sharedInstance.currentUser {
            try await user.refreshTokensIfNeeded()
            accessToken = user.accessToken.tokenString
        }

        let freshToken = accessToken ?? token
        let calendars = try await fetchCalendarList(token: freshToken)
        var events: [CalendarEvent] = []

        await withTaskGroup(of: [CalendarEvent].self) { group in
            for calendar in calendars {
                group.addTask { [weak self] in
                    guard let self else { return [] }
                    return (try? await self.fetchEvents(
                        calendarID: calendar.id,
                        calendarName: calendar.summary,
                        color: calendar.color,
                        from: startDate,
                        to: endDate,
                        token: token
                    )) ?? []
                }
            }
            for await result in group {
                events.append(contentsOf: result)
            }
        }
        return events
    }

    // MARK: - Private

    private struct GoogleCalendarMeta {
        let id: String
        let summary: String
        let color: Color
    }

    private func fetchCalendarList(token: String) async throws -> [GoogleCalendarMeta] {
        var components = URLComponents(string: "https://www.googleapis.com/calendar/v3/users/me/calendarList")!
        components.queryItems = [URLQueryItem(name: "minAccessRole", value: "reader")]
        var request = URLRequest(url: components.url!)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, _) = try await URLSession.shared.data(for: request)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let items = json?["items"] as? [[String: Any]] ?? []

        return items.compactMap { item in
            guard let id = item["id"] as? String,
                  let summary = item["summary"] as? String else { return nil }
            let hexColor = item["backgroundColor"] as? String ?? "#4285F4"
            return GoogleCalendarMeta(id: id, summary: summary, color: Color(hex: hexColor))
        }
    }

    private func fetchEvents(
        calendarID: String,
        calendarName: String,
        color: Color,
        from startDate: Date,
        to endDate: Date,
        token: String
    ) async throws -> [CalendarEvent] {
        var components = URLComponents(string: "https://www.googleapis.com/calendar/v3/calendars/\(calendarID.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? calendarID)/events")!
        components.queryItems = [
            URLQueryItem(name: "timeMin", value: ISO8601DateFormatter().string(from: startDate)),
            URLQueryItem(name: "timeMax", value: ISO8601DateFormatter().string(from: endDate)),
            URLQueryItem(name: "singleEvents", value: "true"),
            URLQueryItem(name: "orderBy", value: "startTime"),
            URLQueryItem(name: "maxResults", value: "250")
        ]
        var request = URLRequest(url: components.url!)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, _) = try await URLSession.shared.data(for: request)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let items = json?["items"] as? [[String: Any]] ?? []

        return items.compactMap { item -> CalendarEvent? in
            guard let id = item["id"] as? String,
                  let title = item["summary"] as? String,
                  let startRaw = item["start"] as? [String: String],
                  let endRaw = item["end"] as? [String: String] else { return nil }

            let isAllDay = startRaw["date"] != nil
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = isAllDay
                ? [.withFullDate]
                : [.withInternetDateTime, .withFractionalSeconds]

            guard let start = formatter.date(from: startRaw["date"] ?? startRaw["dateTime"] ?? ""),
                  let end   = formatter.date(from: endRaw["date"]   ?? endRaw["dateTime"]   ?? "") else { return nil }

            return CalendarEvent(
                id: "google-\(id)",
                title: title,
                startDate: start,
                endDate: end,
                isAllDay: isAllDay,
                source: .google,
                calendarName: calendarName,
                color: color
            )
        }
    }
}

// MARK: - Color hex helper
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >> 8)  & 0xFF) / 255
        let b = Double(int         & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}
