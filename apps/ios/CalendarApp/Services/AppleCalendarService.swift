import EventKit
import SwiftUI

@MainActor
final class AppleCalendarService: ObservableObject {
    private let store = EKEventStore()
    @Published private(set) var authStatus: EKAuthorizationStatus = EKEventStore.authorizationStatus(for: .event)

    func requestAccess() async -> Bool {
        do {
            let granted = try await store.requestFullAccessToEvents()
            authStatus = EKEventStore.authorizationStatus(for: .event)
            return granted
        } catch {
            authStatus = EKEventStore.authorizationStatus(for: .event)
            return false
        }
    }

    func fetchEvents(from startDate: Date, to endDate: Date) -> [CalendarEvent] {
        guard EKEventStore.authorizationStatus(for: .event) == .fullAccess else { return [] }
        let predicate = store.predicateForEvents(withStart: startDate, end: endDate, calendars: nil)
        let ekEvents = store.events(matching: predicate)
        return ekEvents.map { map($0) }
    }

    private func map(_ ek: EKEvent) -> CalendarEvent {
        let cgColor = ek.calendar.cgColor
        let color = cgColor.map { Color(cgColor: $0) } ?? .red
        return CalendarEvent(
            id: "apple-\(ek.eventIdentifier ?? UUID().uuidString)",
            title: ek.title ?? "No Title",
            startDate: ek.startDate,
            endDate: ek.endDate,
            isAllDay: ek.isAllDay,
            source: .apple,
            calendarName: ek.calendar.title,
            color: color
        )
    }
}
