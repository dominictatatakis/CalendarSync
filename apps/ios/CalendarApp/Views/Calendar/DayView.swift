import SwiftUI

struct DayView: View {
    @EnvironmentObject var vm: CalendarViewModel
    @State private var pageIndex = 1
    private let cal = Calendar.current

    var body: some View {
        TabView(selection: $pageIndex) {
            DayPageContent(date: dayDate(offset: -1)).tag(0)
            DayPageContent(date: dayDate(offset:  0)).tag(1)
            DayPageContent(date: dayDate(offset: +1)).tag(2)
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .onChange(of: pageIndex) { _, new in
            guard new != 1 else { return }
            let delta = new == 0 ? -1 : 1
            vm.selectedDate = cal.date(byAdding: .day, value: delta, to: vm.selectedDate) ?? vm.selectedDate
            var t = Transaction()
            t.disablesAnimations = true
            withTransaction(t) { pageIndex = 1 }
        }
    }

    private func dayDate(offset: Int) -> Date {
        cal.date(byAdding: .day, value: offset, to: vm.selectedDate) ?? vm.selectedDate
    }
}

// MARK: - Single day page

struct DayPageContent: View {
    let date: Date
    @EnvironmentObject var vm: CalendarViewModel
    @EnvironmentObject var friendsVM: FriendsViewModel
    private let cal = Calendar.current
    private let hourHeight: CGFloat = 64

    private var allDayEvents: [CalendarEvent] {
        vm.unifiedService.events(on: date).filter(\.isAllDay)
    }
    private var timedEvents: [CalendarEvent] {
        vm.unifiedService.events(on: date).filter { !$0.isAllDay }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Date header
            Text(date.formatted(.dateTime.weekday(.wide).month(.wide).day()))
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
                .padding(.vertical, 10)

            // All-day events
            if !allDayEvents.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("ALL DAY")
                        .font(.caption2.bold())
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)
                    ForEach(allDayEvents) { event in
                        NavigationLink(destination: EventDetailView(event: event)) {
                            HStack {
                                RoundedRectangle(cornerRadius: 3).fill(event.color).frame(width: 4, height: 20)
                                Text(event.title).font(.subheadline)
                                Spacer()
                            }
                            .padding(.horizontal)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 8)
                Divider()
            }

            ScrollViewReader { proxy in
                ScrollView {
                    ZStack(alignment: .topLeading) {
                        // Hour grid
                        VStack(spacing: 0) {
                            ForEach(0..<24, id: \.self) { hour in
                                HStack(alignment: .top, spacing: 8) {
                                    Text(hourLabel(hour))
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                        .frame(width: 40, alignment: .trailing)
                                    Divider()
                                }
                                .frame(height: hourHeight)
                                .id(hour)
                            }
                        }

                        // Current time indicator
                        if cal.isDateInToday(date) {
                            CurrentTimeIndicator(hourHeight: hourHeight)
                        }

                        // Friend overlay slots
                        ForEach(friendsVM.calendarOverlayFriendIDs.sorted(), id: \.self) { fid in
                            let color = friendsVM.overlayColor(for: fid)
                            ForEach(friendsVM.availabilitySlots(for: fid, on: date)) { slot in
                                DayOverlayBlock(slot: slot, color: color, hourHeight: hourHeight)
                                    .padding(.leading, 52)
                                    .padding(.trailing, 8)
                            }
                        }

                        // Timed events — each spans full width independently
                        ForEach(timedEvents) { event in
                            NavigationLink(destination: EventDetailView(event: event)) {
                                DayEventBlock(event: event, hourHeight: hourHeight)
                            }
                            .buttonStyle(.plain)
                            .padding(.leading, 52)
                            .padding(.trailing, 8)
                        }
                    }
                }
                .onAppear {
                    let hour = cal.component(.hour, from: cal.isDateInToday(date) ? .now : date)
                    proxy.scrollTo(max(hour - 2, 0), anchor: .top)
                }
            }
        }
    }

    private func hourLabel(_ hour: Int) -> String {
        hour == 0 ? "12a" : "\(hour % 12 == 0 ? 12 : hour % 12)\(hour < 12 ? "a" : "p")"
    }
}

// MARK: - Event block

struct DayEventBlock: View {
    let event: CalendarEvent
    let hourHeight: CGFloat
    private let cal = Calendar.current

    private var yOffset: CGFloat {
        let startOfDay = cal.startOfDay(for: event.startDate)
        return (event.startDate.timeIntervalSince(startOfDay) / 3600) * hourHeight
    }
    private var blockHeight: CGFloat { max(hourHeight * CGFloat(event.duration / 3600), 32) }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(event.title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .lineLimit(2)
            Text("\(event.startDate.formatted(date: .omitted, time: .shortened)) – \(event.endDate.formatted(date: .omitted, time: .shortened))")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.85))
            if blockHeight > 52 {
                Label(event.calendarName, systemImage: event.source.icon)
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.70))
                    .lineLimit(1)
            }
        }
        .padding(6)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .frame(height: blockHeight)
        .background(event.color.opacity(0.9), in: RoundedRectangle(cornerRadius: 6))
        .offset(y: yOffset)
    }
}

// MARK: - Friend overlay block

struct DayOverlayBlock: View {
    let slot: AvailabilitySlot
    let color: Color
    let hourHeight: CGFloat
    private let cal = Calendar.current

    private var yOffset: CGFloat {
        let startOfDay = cal.startOfDay(for: slot.startDate)
        return CGFloat(slot.startDate.timeIntervalSince(startOfDay) / 3600) * hourHeight
    }
    private var blockHeight: CGFloat {
        max(CGFloat(slot.endDate.timeIntervalSince(slot.startDate) / 3600) * hourHeight, 32)
    }

    var body: some View {
        RoundedRectangle(cornerRadius: 6)
            .fill(color.opacity(0.25))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(color.opacity(0.6), lineWidth: 1.5)
            )
            .frame(maxWidth: .infinity)
            .frame(height: blockHeight)
            .offset(y: yOffset)
    }
}

// MARK: - Current time indicator

struct CurrentTimeIndicator: View {
    let hourHeight: CGFloat
    @State private var now = Date.now
    private let cal = Calendar.current

    private var yOffset: CGFloat {
        (now.timeIntervalSince(cal.startOfDay(for: now)) / 3600) * hourHeight
    }

    var body: some View {
        HStack(spacing: 0) {
            Color.clear.frame(width: 48)
            HStack(spacing: 0) {
                Circle().fill(Color.red).frame(width: 8, height: 8)
                Rectangle().fill(Color.red).frame(height: 1)
            }
        }
        .offset(y: yOffset)
        .onAppear {
            Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { _ in now = .now }
        }
    }
}
