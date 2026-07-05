import SwiftUI

struct CalendarEvent: Identifiable, Hashable {
    let id: String
    let title: String
    let startDate: Date
    let endDate: Date
    let isAllDay: Bool
    let source: CalendarSource
    let calendarName: String
    let color: Color

    // Social sharing — controlled per event by the owner
    var isSharedWithCloseFriends: Bool = false

    var duration: TimeInterval { endDate.timeIntervalSince(startDate) }

    var displayTitle: String { isAllDay ? title : title }

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: CalendarEvent, rhs: CalendarEvent) -> Bool { lhs.id == rhs.id }
}

// MARK: - Availability (friend's view of an event)
struct AvailabilitySlot: Identifiable {
    let id: String
    let ownerID: String
    let startDate: Date
    let endDate: Date
    /// nil when details are hidden (default); populated when the friend has opted to share
    let title: String?
    let isAllDay: Bool
}
