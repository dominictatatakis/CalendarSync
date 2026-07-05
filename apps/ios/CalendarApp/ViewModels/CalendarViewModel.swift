import Foundation
import SwiftUI
import Combine

@MainActor
final class CalendarViewModel: ObservableObject {
    let unifiedService = UnifiedCalendarService()

    @Published var selectedDate: Date = .now
    @Published var displayMode: CalendarDisplayMode = .month
    @Published var eventShares: [EventShareRow] = []

    private let supabaseService = SupabaseService()
    private var cancellables = Set<AnyCancellable>()

    init() {
        // Forward UnifiedCalendarService changes so all views re-render when events load
        unifiedService.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
    }

    enum CalendarDisplayMode: String, CaseIterable {
        case month = "Month"
        case week  = "Week"
        case day   = "Day"
    }

    var visibleMonthTitle: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: selectedDate)
    }

    func loadAll() async {
        unifiedService.setup()
        await unifiedService.apple.requestAccess()
        await unifiedService.google.restoreSession()
        await unifiedService.outlook.restoreSession()
        await fetchEvents()
        #if DEBUG
        loadMockEvents()
        #endif
    }

    #if DEBUG
    private func loadMockEvents() {
        let cal = Calendar.current
        let now = Date.now
        let outlook = Color(red: 0, green: 0.47, blue: 0.84)

        func date(_ dayOffset: Int, hour: Int, minute: Int = 0) -> Date {
            cal.date(bySettingHour: hour, minute: minute, second: 0,
                     of: cal.date(byAdding: .day, value: dayOffset, to: now)!)!
        }
        func allDay(_ dayOffset: Int) -> Date {
            cal.startOfDay(for: cal.date(byAdding: .day, value: dayOffset, to: now)!)
        }

        unifiedService.injectMockEvents([

            // ── Today ────────────────────────────────────────────────────
            CalendarEvent(id: "m-1",  title: "Team standup",          startDate: date(0, hour: 9),       endDate: date(0, hour: 9, minute: 30),  isAllDay: false, source: .apple,   calendarName: "Work",        color: .red),
            CalendarEvent(id: "m-2",  title: "1:1 with manager",      startDate: date(0, hour: 10),      endDate: date(0, hour: 10, minute: 45), isAllDay: false, source: .outlook, calendarName: "Work",        color: outlook),
            CalendarEvent(id: "m-3",  title: "Lunch with Sarah",      startDate: date(0, hour: 12, minute: 30), endDate: date(0, hour: 13, minute: 30), isAllDay: false, source: .google, calendarName: "Personal", color: .blue),
            CalendarEvent(id: "m-4",  title: "Product review",        startDate: date(0, hour: 15),      endDate: date(0, hour: 16),             isAllDay: false, source: .outlook, calendarName: "Work",        color: outlook),
            CalendarEvent(id: "m-5",  title: "Call with client",      startDate: date(0, hour: 16, minute: 30), endDate: date(0, hour: 17),      isAllDay: false, source: .apple,   calendarName: "Work",        color: .red),

            // ── Tomorrow ─────────────────────────────────────────────────
            CalendarEvent(id: "m-6",  title: "Gym",                   startDate: date(1, hour: 7),       endDate: date(1, hour: 8),              isAllDay: false, source: .apple,   calendarName: "Personal",    color: .green),
            CalendarEvent(id: "m-7",  title: "Team standup",          startDate: date(1, hour: 9),       endDate: date(1, hour: 9, minute: 30),  isAllDay: false, source: .apple,   calendarName: "Work",        color: .red),
            CalendarEvent(id: "m-8",  title: "Design sync",           startDate: date(1, hour: 11),      endDate: date(1, hour: 11, minute: 45), isAllDay: false, source: .google,  calendarName: "Work",        color: .blue),
            CalendarEvent(id: "m-9",  title: "Lunch break",           startDate: date(1, hour: 12, minute: 30), endDate: date(1, hour: 13, minute: 30), isAllDay: false, source: .apple, calendarName: "Personal", color: .green),
            CalendarEvent(id: "m-10", title: "Sprint planning",       startDate: date(1, hour: 14),      endDate: date(1, hour: 16),             isAllDay: false, source: .outlook, calendarName: "Work",        color: outlook),
            CalendarEvent(id: "m-11", title: "Drinks with Tom",       startDate: date(1, hour: 18, minute: 30), endDate: date(1, hour: 20),     isAllDay: false, source: .apple,   calendarName: "Personal",    color: .pink),

            // ── Day +2 (all-day + events) ─────────────────────────────────
            CalendarEvent(id: "m-12", title: "Conference Day 1",      startDate: allDay(2),              endDate: allDay(2),                     isAllDay: true,  source: .google,  calendarName: "Work",        color: .orange),
            CalendarEvent(id: "m-13", title: "Keynote",               startDate: date(2, hour: 9),       endDate: date(2, hour: 11),             isAllDay: false, source: .google,  calendarName: "Work",        color: .blue),
            CalendarEvent(id: "m-14", title: "Workshop: SwiftUI",     startDate: date(2, hour: 13),      endDate: date(2, hour: 17),             isAllDay: false, source: .google,  calendarName: "Work",        color: .blue),
            CalendarEvent(id: "m-15", title: "Conference dinner",     startDate: date(2, hour: 19),      endDate: date(2, hour: 22),             isAllDay: false, source: .google,  calendarName: "Work",        color: .blue),

            // ── Day +3 ────────────────────────────────────────────────────
            CalendarEvent(id: "m-16", title: "Conference Day 2",      startDate: allDay(3),              endDate: allDay(3),                     isAllDay: true,  source: .google,  calendarName: "Work",        color: .orange),
            CalendarEvent(id: "m-17", title: "Team standup",          startDate: date(3, hour: 9),       endDate: date(3, hour: 9, minute: 30),  isAllDay: false, source: .apple,   calendarName: "Work",        color: .red),
            CalendarEvent(id: "m-18", title: "Dentist",               startDate: date(3, hour: 10),      endDate: date(3, hour: 10, minute: 30), isAllDay: false, source: .apple,   calendarName: "Personal",    color: .red),
            CalendarEvent(id: "m-19", title: "Panel discussion",      startDate: date(3, hour: 14),      endDate: date(3, hour: 15, minute: 30), isAllDay: false, source: .google,  calendarName: "Work",        color: .blue),

            // ── Day +4 ────────────────────────────────────────────────────
            CalendarEvent(id: "m-20", title: "Gym",                   startDate: date(4, hour: 7),       endDate: date(4, hour: 8),              isAllDay: false, source: .apple,   calendarName: "Personal",    color: .green),
            CalendarEvent(id: "m-21", title: "Team standup",          startDate: date(4, hour: 9),       endDate: date(4, hour: 9, minute: 30),  isAllDay: false, source: .apple,   calendarName: "Work",        color: .red),
            CalendarEvent(id: "m-22", title: "Weekly review",         startDate: date(4, hour: 17),      endDate: date(4, hour: 18),             isAllDay: false, source: .outlook, calendarName: "Work",        color: outlook),
            CalendarEvent(id: "m-23", title: "Dinner with parents",   startDate: date(4, hour: 19),      endDate: date(4, hour: 21),             isAllDay: false, source: .apple,   calendarName: "Personal",    color: .pink),

            // ── Day +5 ────────────────────────────────────────────────────
            CalendarEvent(id: "m-24", title: "Birthday dinner 🎂",    startDate: date(5, hour: 19),      endDate: date(5, hour: 22),             isAllDay: false, source: .apple,   calendarName: "Personal",    color: .pink),
            CalendarEvent(id: "m-25", title: "Hair cut",              startDate: date(5, hour: 11),      endDate: date(5, hour: 11, minute: 45), isAllDay: false, source: .apple,   calendarName: "Personal",    color: .green),

            // ── Day +6 ────────────────────────────────────────────────────
            CalendarEvent(id: "m-26", title: "Brunch with friends",   startDate: date(6, hour: 11),      endDate: date(6, hour: 13),             isAllDay: false, source: .apple,   calendarName: "Personal",    color: .pink),
            CalendarEvent(id: "m-27", title: "Grocery shopping",      startDate: date(6, hour: 15),      endDate: date(6, hour: 16),             isAllDay: false, source: .apple,   calendarName: "Personal",    color: .green),

            // ── Next week ─────────────────────────────────────────────────
            CalendarEvent(id: "m-28", title: "Flight to Madrid ✈️",   startDate: date(7, hour: 6, minute: 45), endDate: date(7, hour: 10),      isAllDay: false, source: .google,  calendarName: "Travel",      color: .purple),
            CalendarEvent(id: "m-29", title: "Madrid trip",           startDate: allDay(7),              endDate: allDay(7),                     isAllDay: true,  source: .apple,   calendarName: "Personal",    color: .purple),
            CalendarEvent(id: "m-30", title: "Madrid trip",           startDate: allDay(8),              endDate: allDay(8),                     isAllDay: true,  source: .apple,   calendarName: "Personal",    color: .purple),
            CalendarEvent(id: "m-31", title: "Madrid trip",           startDate: allDay(9),              endDate: allDay(9),                     isAllDay: true,  source: .apple,   calendarName: "Personal",    color: .purple),
            CalendarEvent(id: "m-32", title: "Hotel check-in",        startDate: date(7, hour: 14),      endDate: date(7, hour: 14, minute: 30), isAllDay: false, source: .google,  calendarName: "Travel",      color: .purple),
            CalendarEvent(id: "m-33", title: "Team standup",          startDate: date(7, hour: 9),       endDate: date(7, hour: 9, minute: 30),  isAllDay: false, source: .apple,   calendarName: "Work",        color: .red),
            CalendarEvent(id: "m-34", title: "Client dinner",         startDate: date(8, hour: 20),      endDate: date(8, hour: 22, minute: 30), isAllDay: false, source: .outlook, calendarName: "Work",        color: outlook),
            CalendarEvent(id: "m-35", title: "Museum visit",          startDate: date(9, hour: 10),      endDate: date(9, hour: 13),             isAllDay: false, source: .apple,   calendarName: "Personal",    color: .purple),
            CalendarEvent(id: "m-36", title: "Flight home ✈️",        startDate: date(10, hour: 16),     endDate: date(10, hour: 19, minute: 30),isAllDay: false, source: .google,  calendarName: "Travel",      color: .purple),

            // ── Two weeks out ─────────────────────────────────────────────
            CalendarEvent(id: "m-37", title: "Quarterly review",      startDate: date(14, hour: 10),     endDate: date(14, hour: 12),            isAllDay: false, source: .outlook, calendarName: "Work",        color: outlook),
            CalendarEvent(id: "m-38", title: "Team offsite",          startDate: allDay(15),             endDate: allDay(15),                    isAllDay: true,  source: .google,  calendarName: "Work",        color: .orange),
            CalendarEvent(id: "m-39", title: "Team offsite",          startDate: allDay(16),             endDate: allDay(16),                    isAllDay: true,  source: .google,  calendarName: "Work",        color: .orange),
            CalendarEvent(id: "m-40", title: "Dentist follow-up",     startDate: date(17, hour: 9),      endDate: date(17, hour: 9, minute: 30), isAllDay: false, source: .apple,   calendarName: "Personal",    color: .red),
        ])
    }
    #endif

    func fetchEvents() async {
        let cal = Calendar.current
        let start = cal.date(byAdding: .month, value: -2, to: selectedDate) ?? selectedDate
        let end   = cal.date(byAdding: .month, value: +3, to: selectedDate) ?? selectedDate
        await unifiedService.fetchEvents(from: start, to: end)
    }

    func eventsForSelectedDate() -> [CalendarEvent] {
        unifiedService.events(on: selectedDate)
    }

    func eventsForWeek(containing date: Date) -> [Date: [CalendarEvent]] {
        let cal = Calendar.current
        guard let weekStart = cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)) else { return [:] }
        var result: [Date: [CalendarEvent]] = [:]
        for offset in 0..<7 {
            if let day = cal.date(byAdding: .day, value: offset, to: weekStart) {
                result[day] = unifiedService.events(on: day)
            }
        }
        return result
    }

    func toggleShareEvent(_ event: CalendarEvent, groupID: String, ownerID: String, showDetails: Bool) async throws {
        let isCurrentlyShared = eventShares.contains { $0.eventID == event.id && $0.groupID == groupID }
        try await supabaseService.setEventSharing(
            event: event,
            groupID: groupID,
            ownerID: ownerID,
            share: !isCurrentlyShared,
            showDetails: showDetails
        )
        await loadShareSettings(ownerID: ownerID)
    }

    func loadShareSettings(ownerID: String) async {
        eventShares = (try? await supabaseService.fetchSharedEvents(ownerID: ownerID)) ?? []
    }

    func isEventShared(_ event: CalendarEvent, withGroup groupID: String) -> Bool {
        eventShares.contains { $0.eventID == event.id && $0.groupID == groupID }
    }
}
