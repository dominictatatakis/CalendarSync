import Foundation
import MSAL
import SwiftUI

@MainActor
final class OutlookCalendarService: ObservableObject {
    @Published private(set) var isConnected = false
    private var accessToken: String?
    private var application: MSALPublicClientApplication?

    var isConfigured: Bool { !Secrets.msalClientID.hasPrefix("YOUR_") }

    private let scopes = ["Calendars.Read", "User.Read"]
    private let graphBase = "https://graph.microsoft.com/v1.0"

    // MARK: - Setup

    func setup() throws {
        let config = try MSALPublicClientApplicationConfig(
            clientId: Secrets.msalClientID,
            redirectUri: Secrets.msalRedirectURI,
            authority: nil
        )
        application = try MSALPublicClientApplication(configuration: config)
    }

    // MARK: - Auth

    func signIn(presenting viewController: UIViewController) async throws {
        guard let app = application else { throw OutlookError.notConfigured }
        let webParams = MSALWebviewParameters(authPresentationViewController: viewController)
        let params = MSALInteractiveTokenParameters(scopes: scopes, webviewParameters: webParams)

        let result = try await withCheckedThrowingContinuation { (cont: CheckedContinuation<MSALResult, Error>) in
            app.acquireToken(with: params) { result, error in
                if let error { cont.resume(throwing: error) }
                else if let result { cont.resume(returning: result) }
                else { cont.resume(throwing: OutlookError.unknown) }
            }
        }
        accessToken = result.accessToken
        isConnected = true
    }

    func restoreSession() async {
        guard let app = application else { return }
        let accounts = (try? app.allAccounts()) ?? []
        guard let account = accounts.first else { return }

        let params = MSALSilentTokenParameters(scopes: scopes, account: account)
        let result = try? await withCheckedThrowingContinuation { (cont: CheckedContinuation<MSALResult, Error>) in
            app.acquireTokenSilent(with: params) { result, error in
                if let error { cont.resume(throwing: error) }
                else if let result { cont.resume(returning: result) }
                else { cont.resume(throwing: OutlookError.unknown) }
            }
        }
        accessToken = result?.accessToken
        isConnected = accessToken != nil
    }

    func signOut() {
        guard let app = application,
              let account = try? app.allAccounts().first else { return }
        try? app.remove(account)
        accessToken = nil
        isConnected = false
    }

    // MARK: - Fetch Events

    func fetchEvents(from startDate: Date, to endDate: Date) async throws -> [CalendarEvent] {
        guard let token = accessToken else { return [] }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        let start = formatter.string(from: startDate)
        let end   = formatter.string(from: endDate)

        let urlString = "\(graphBase)/me/calendarView?startDateTime=\(start)&endDateTime=\(end)&$top=250&$select=id,subject,start,end,isAllDay,calendar"
        guard let url = URL(string: urlString) else { return [] }
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, _) = try await URLSession.shared.data(for: request)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let items = json?["value"] as? [[String: Any]] ?? []

        return items.compactMap { item -> CalendarEvent? in
            guard let id      = item["id"] as? String,
                  let subject = item["subject"] as? String,
                  let startD  = (item["start"] as? [String: String])?["dateTime"],
                  let endD    = (item["end"]   as? [String: String])?["dateTime"] else { return nil }

            let isAllDay = item["isAllDay"] as? Bool ?? false
            let graphFormatter = ISO8601DateFormatter()
            graphFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

            guard let startDate = graphFormatter.date(from: startD) ?? ISO8601DateFormatter().date(from: startD),
                  let endDate   = graphFormatter.date(from: endD)   ?? ISO8601DateFormatter().date(from: endD) else { return nil }

            return CalendarEvent(
                id: "outlook-\(id)",
                title: subject,
                startDate: startDate,
                endDate: endDate,
                isAllDay: isAllDay,
                source: .outlook,
                calendarName: "Outlook",
                color: Color(red: 0, green: 0.47, blue: 0.84)
            )
        }
    }

    enum OutlookError: Error {
        case notConfigured, unknown
    }
}
