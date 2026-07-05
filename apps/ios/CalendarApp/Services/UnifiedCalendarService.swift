import Foundation
import SwiftUI

@MainActor
final class UnifiedCalendarService: ObservableObject {
    let apple   = AppleCalendarService()
    let google  = GoogleCalendarService()
    let outlook = OutlookCalendarService()

    @Published private(set) var events: [CalendarEvent] = []
    @Published private(set) var isLoading = false

    func setup() {
        try? outlook.setup()
    }

    func fetchEvents(from startDate: Date, to endDate: Date) async {
        isLoading = true
        defer { isLoading = false }

        // Apple is synchronous; Google and Outlook are async — run them concurrently
        let appleEvents = apple.fetchEvents(from: startDate, to: endDate)

        var googleEvents: [CalendarEvent] = []
        do {
            googleEvents = try await google.fetchEvents(from: startDate, to: endDate)
            google.lastError = nil
        } catch {
            google.lastError = error.localizedDescription
            print("[Google Calendar] Fetch error: \(error)")
        }

        let outlookEvents = (try? await outlook.fetchEvents(from: startDate, to: endDate)) ?? []
        events = (appleEvents + googleEvents + outlookEvents).sorted { $0.startDate < $1.startDate }
    }

    func events(on date: Date) -> [CalendarEvent] {
        let cal = Calendar.current
        return events.filter { event in
            if event.isAllDay {
                return cal.isDate(event.startDate, inSameDayAs: date)
            }
            return event.startDate <= cal.endOfDay(for: date) && event.endDate >= cal.startOfDay(for: date)
        }
    }

    func hasEvents(on date: Date) -> Bool {
        !events(on: date).isEmpty
    }

    #if DEBUG
    func injectMockEvents(_ mockEvents: [CalendarEvent]) {
        events = (events + mockEvents).sorted { $0.startDate < $1.startDate }
    }
    #endif
}

extension Calendar {
    func endOfDay(for date: Date) -> Date {
        var components = DateComponents()
        components.day = 1
        components.second = -1
        return self.date(byAdding: components, to: startOfDay(for: date)) ?? date
    }
}
