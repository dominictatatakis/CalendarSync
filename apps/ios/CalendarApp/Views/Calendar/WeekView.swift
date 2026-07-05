import SwiftUI

struct WeekView: View {
    @EnvironmentObject var vm: CalendarViewModel
    @State private var pageIndex = 1
    private let cal = Calendar.current

    var body: some View {
        TabView(selection: $pageIndex) {
            WeekPageContent(weekBase: weekDate(offset: -1)).tag(0)
            WeekPageContent(weekBase: weekDate(offset:  0)).tag(1)
            WeekPageContent(weekBase: weekDate(offset: +1)).tag(2)
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .onChange(of: pageIndex) { _, new in
            guard new != 1 else { return }
            let delta = new == 0 ? -1 : 1
            vm.selectedDate = cal.date(byAdding: .weekOfYear, value: delta, to: vm.selectedDate) ?? vm.selectedDate
            var t = Transaction()
            t.disablesAnimations = true
            withTransaction(t) { pageIndex = 1 }
        }
    }

    private func weekDate(offset: Int) -> Date {
        cal.date(byAdding: .weekOfYear, value: offset, to: vm.selectedDate) ?? vm.selectedDate
    }
}

// MARK: - Single week page

struct WeekPageContent: View {
    let weekBase: Date
    @EnvironmentObject var vm: CalendarViewModel
    @EnvironmentObject var friendsVM: FriendsViewModel
    private let cal = Calendar.current
    private let hourHeight: CGFloat = 56
    private let gutterWidth: CGFloat = 44

    private var weekDates: [Date] {
        guard let weekStart = cal.date(from: cal.dateComponents(
            [.yearForWeekOfYear, .weekOfYear], from: weekBase)
        ) else { return [] }
        return (0..<7).compactMap { cal.date(byAdding: .day, value: $0, to: weekStart) }
    }

    var body: some View {
        GeometryReader { geo in
            let colWidth = (geo.size.width - gutterWidth) / 7

            VStack(spacing: 0) {
                // ── Narrow day header strip ──────────────────────────────
                HStack(spacing: 0) {
                    Color.clear.frame(width: gutterWidth)
                    ForEach(weekDates, id: \.self) { date in
                        CompactDayHeader(date: date, selectedDate: $vm.selectedDate)
                            .frame(width: colWidth)
                    }
                }
                .frame(height: 48)
                .background(Color(UIColor.systemBackground))

                // ── All-day row ──────────────────────────────────────────
                let allDayEvents = weekDates.map { date in
                    vm.unifiedService.events(on: date).filter(\.isAllDay)
                }
                let hasAnyAllDay = allDayEvents.contains { !$0.isEmpty }
                if hasAnyAllDay {
                    HStack(spacing: 0) {
                        Text("all-day")
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                            .frame(width: gutterWidth, alignment: .trailing)
                            .padding(.trailing, 4)
                        ForEach(Array(weekDates.enumerated()), id: \.offset) { idx, date in
                            VStack(spacing: 2) {
                                ForEach(allDayEvents[idx]) { event in
                                    NavigationLink(destination: EventDetailView(event: event)) {
                                        Text(event.title)
                                            .font(.system(size: 9, weight: .medium))
                                            .foregroundStyle(.white)
                                            .lineLimit(1)
                                            .padding(.horizontal, 3)
                                            .padding(.vertical, 2)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .background(event.color.opacity(0.88), in: RoundedRectangle(cornerRadius: 3))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.vertical, 3)
                            .frame(width: colWidth)
                        }
                    }
                    .padding(.vertical, 2)
                    .background(Color(UIColor.systemBackground))
                }

                Divider()

                // ── Scrollable time grid ─────────────────────────────────
                ScrollViewReader { proxy in
                    ScrollView(.vertical, showsIndicators: false) {
                        ZStack(alignment: .topLeading) {
                            // Grid drawn with Canvas for crisp lines
                            Canvas { ctx, size in
                                for hour in 0..<24 {
                                    let y = CGFloat(hour) * hourHeight + 0.5
                                    var path = Path()
                                    path.move(to: .init(x: 0, y: y))
                                    path.addLine(to: .init(x: size.width, y: y))
                                    ctx.stroke(path, with: .color(.secondary.opacity(hour == 0 ? 0 : 0.18)), lineWidth: 0.5)
                                }
                                for col in 1..<7 {
                                    let x = gutterWidth + CGFloat(col) * colWidth
                                    var path = Path()
                                    path.move(to: .init(x: x, y: 0))
                                    path.addLine(to: .init(x: x, y: size.height))
                                    ctx.stroke(path, with: .color(.secondary.opacity(0.18)), lineWidth: 0.5)
                                }
                            }
                            .frame(width: geo.size.width, height: hourHeight * 24)

                            // Time labels in the gutter
                            VStack(spacing: 0) {
                                ForEach(0..<24, id: \.self) { hour in
                                    Text(hour == 0 ? "" : hourLabel(hour))
                                        .font(.system(size: 10))
                                        .foregroundStyle(.secondary)
                                        .frame(width: gutterWidth, height: hourHeight, alignment: .topTrailing)
                                        .padding(.trailing, 6)
                                        .id(hour)
                                }
                            }

                            // Events for every day
                            ForEach(Array(weekDates.enumerated()), id: \.offset) { idx, date in
                                let xBase = gutterWidth + CGFloat(idx) * colWidth
                                ForEach(vm.unifiedService.events(on: date).filter { !$0.isAllDay }) { event in
                                    let yTop = yOffset(event)
                                    let h = blockHeight(event)
                                    NavigationLink(destination: EventDetailView(event: event)) {
                                        VStack(alignment: .leading, spacing: 1) {
                                            Text(event.title)
                                                .font(.system(size: 9, weight: .semibold))
                                                .lineLimit(h > 28 ? 2 : 1)
                                                .foregroundStyle(.white)
                                            if h > 32 {
                                                Text(event.startDate.formatted(date: .omitted, time: .shortened))
                                                    .font(.system(size: 8))
                                                    .foregroundStyle(.white.opacity(0.85))
                                            }
                                        }
                                        .padding(.horizontal, 3)
                                        .padding(.vertical, 2)
                                        .frame(width: colWidth - 3, height: h, alignment: .topLeading)
                                        .background(event.color.opacity(0.88), in: RoundedRectangle(cornerRadius: 3))
                                    }
                                    .buttonStyle(.plain)
                                    .offset(x: xBase + 1.5, y: yTop)
                                }
                            }

                            // Friend overlay slots
                            ForEach(Array(weekDates.enumerated()), id: \.offset) { idx, date in
                                let xBase = gutterWidth + CGFloat(idx) * colWidth
                                ForEach(friendsVM.calendarOverlayFriendIDs.sorted(), id: \.self) { fid in
                                    let color = friendsVM.overlayColor(for: fid)
                                    ForEach(friendsVM.availabilitySlots(for: fid, on: date)) { slot in
                                        let yTop = yOffset(slot.startDate)
                                        let h    = slotHeight(slot)
                                        RoundedRectangle(cornerRadius: 3)
                                            .fill(color.opacity(0.3))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 3)
                                                    .strokeBorder(color.opacity(0.7), lineWidth: 1)
                                            )
                                            .frame(width: colWidth - 3, height: h)
                                            .offset(x: xBase + 1.5, y: yTop)
                                    }
                                }
                            }

                            // Current time red line
                            TodayLine(weekDates: weekDates, gutterWidth: gutterWidth,
                                      colWidth: colWidth, hourHeight: hourHeight)
                        }
                        .frame(width: geo.size.width, height: hourHeight * 24)
                    }
                    .onAppear {
                        proxy.scrollTo(max(cal.component(.hour, from: .now) - 2, 0), anchor: .top)
                    }
                }
            }
        }
    }

    private func yOffset(_ event: CalendarEvent) -> CGFloat {
        let start = cal.startOfDay(for: event.startDate)
        return CGFloat(event.startDate.timeIntervalSince(start) / 3600) * hourHeight
    }

    private func blockHeight(_ event: CalendarEvent) -> CGFloat {
        max(CGFloat(event.duration / 3600) * hourHeight, 16)
    }

    private func yOffset(_ date: Date) -> CGFloat {
        let start = cal.startOfDay(for: date)
        return CGFloat(date.timeIntervalSince(start) / 3600) * hourHeight
    }

    private func slotHeight(_ slot: AvailabilitySlot) -> CGFloat {
        let duration = slot.endDate.timeIntervalSince(slot.startDate)
        return max(CGFloat(duration / 3600) * hourHeight, 16)
    }

    private func hourLabel(_ h: Int) -> String {
        "\(h % 12 == 0 ? 12 : h % 12)\(h < 12 ? "a" : "p")"
    }
} // end WeekPageContent

// MARK: - Compact day header

struct CompactDayHeader: View {
    let date: Date
    @Binding var selectedDate: Date
    private let cal = Calendar.current

    private var isToday:    Bool { cal.isDateInToday(date) }
    private var isSelected: Bool { cal.isDate(date, inSameDayAs: selectedDate) }

    var body: some View {
        VStack(spacing: 2) {
            Text(date.formatted(.dateTime.weekday(.narrow)).uppercased())
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
            ZStack {
                if isToday {
                    Circle().fill(Color.accentColor).frame(width: 26, height: 26)
                } else if isSelected {
                    Circle().fill(Color.secondary.opacity(0.25)).frame(width: 26, height: 26)
                }
                Text("\(cal.component(.day, from: date))")
                    .font(.system(size: 13, weight: isToday ? .bold : .regular))
                    .foregroundStyle(isToday ? .white : .primary)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { selectedDate = date }
    }
}

// MARK: - Current time line

struct TodayLine: View {
    let weekDates: [Date]
    let gutterWidth: CGFloat
    let colWidth: CGFloat
    let hourHeight: CGFloat
    @State private var now = Date.now
    private let cal = Calendar.current

    var body: some View {
        if let idx = weekDates.firstIndex(where: { cal.isDateInToday($0) }) {
            let x = gutterWidth + CGFloat(idx) * colWidth
            let y = CGFloat(now.timeIntervalSince(cal.startOfDay(for: now)) / 3600) * hourHeight
            HStack(spacing: 0) {
                Circle().fill(Color.red).frame(width: 7, height: 7)
                Rectangle().fill(Color.red).frame(height: 1)
            }
            .frame(width: colWidth)
            .offset(x: x - 3, y: y - 0.5)
            .onAppear {
                Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { _ in now = .now }
            }
        }
    }
}
