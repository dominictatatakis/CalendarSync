import SwiftUI

struct MonthView: View {
    @EnvironmentObject var vm: CalendarViewModel
    private let cal = Calendar.current
    private let dayLetters = ["S","M","T","W","T","F","S"]

    var body: some View {
        VStack(spacing: 0) {
            // Fixed day-of-week headers
            HStack(spacing: 0) {
                ForEach(dayLetters, id: \.self) { letter in
                    Text(letter)
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.vertical, 8)

            Divider()

            // Vertically swipeable month grid
            MonthGrid(month: vm.selectedDate)
                .gesture(
                    DragGesture(minimumDistance: 40)
                        .onEnded { value in
                            // Vertical: swipe up = next month, swipe down = previous month
                            let vertical = value.translation.height
                            if abs(vertical) > abs(value.translation.width) {
                                let delta = vertical < 0 ? 1 : -1
                                withAnimation(.easeInOut(duration: 0.25)) {
                                    vm.selectedDate = cal.date(byAdding: .month, value: delta, to: vm.selectedDate) ?? vm.selectedDate
                                }
                            }
                        }
                )

            Divider()

            // Event list for selected day
            if !vm.eventsForSelectedDate().isEmpty {
                EventListForDay(events: vm.eventsForSelectedDate())
            } else {
                ContentUnavailableView("No events", systemImage: "calendar")
                    .frame(maxHeight: .infinity)
            }
        }
    }
}

// MARK: - Single month grid page

struct MonthGrid: View {
    let month: Date
    @EnvironmentObject var vm: CalendarViewModel
    private let cal = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)

    private var dates: [Date] {
        guard let interval = cal.dateInterval(of: .month, for: month),
              let weekStart = cal.dateInterval(of: .weekOfYear, for: interval.start)
        else { return [] }
        var result: [Date] = []
        var current = weekStart.start
        while current < interval.end || result.count % 7 != 0 {
            result.append(current)
            current = cal.date(byAdding: .day, value: 1, to: current) ?? current
            if result.count > 42 { break }
        }
        return result
    }

    var body: some View {
        LazyVGrid(columns: columns, spacing: 0) {
            ForEach(dates, id: \.self) { date in
                DayCell(date: date, displayMonth: month, selectedDate: $vm.selectedDate)
                    .onTapGesture { vm.selectedDate = date }
            }
        }
    }
}

// MARK: - Day cell

struct DayCell: View {
    let date: Date
    let displayMonth: Date
    @Binding var selectedDate: Date
    @EnvironmentObject var vm: CalendarViewModel
    private let cal = Calendar.current

    private var isSelected:     Bool { cal.isDate(date, inSameDayAs: selectedDate) }
    private var isToday:        Bool { cal.isDateInToday(date) }
    private var isCurrentMonth: Bool { cal.component(.month, from: date) == cal.component(.month, from: displayMonth) }
    private var events: [CalendarEvent] { vm.unifiedService.events(on: date) }

    var body: some View {
        VStack(spacing: 2) {
            ZStack {
                if isSelected {
                    Circle()
                        .fill(isToday ? Color.accentColor : Color.secondary)
                        .frame(width: 32, height: 32)
                } else if isToday {
                    Circle()
                        .strokeBorder(Color.accentColor, lineWidth: 1.5)
                        .frame(width: 32, height: 32)
                }
                Text("\(cal.component(.day, from: date))")
                    .font(.system(size: 14, weight: isToday ? .bold : .regular))
                    .foregroundStyle(
                        isSelected      ? Color.white :
                        isCurrentMonth  ? Color.primary :
                                          Color.secondary.opacity(0.35)
                    )
            }

            HStack(spacing: 2) {
                ForEach(events.prefix(3)) { event in
                    Circle().fill(event.color).frame(width: 5, height: 5)
                }
                if events.count > 3 {
                    Text("+\(events.count - 3)")
                        .font(.system(size: 7))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(height: 8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}

// MARK: - Event list

struct EventListForDay: View {
    let events: [CalendarEvent]

    var body: some View {
        List(events) { event in
            NavigationLink(destination: EventDetailView(event: event)) {
                EventRow(event: event)
            }
        }
        .listStyle(.plain)
    }
}

struct EventRow: View {
    let event: CalendarEvent

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 3)
                .fill(event.color)
                .frame(width: 4, height: 40)

            VStack(alignment: .leading, spacing: 2) {
                Text(event.title)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
                if event.isAllDay {
                    Text("All day · \(event.calendarName)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("\(event.startDate.formatted(date: .omitted, time: .shortened)) – \(event.endDate.formatted(date: .omitted, time: .shortened)) · \(event.calendarName)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Image(systemName: event.source.icon)
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 2)
    }
}
