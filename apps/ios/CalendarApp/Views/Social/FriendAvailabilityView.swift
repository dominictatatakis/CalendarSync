import SwiftUI

struct FriendAvailabilityView: View {
    let friend: Friend
    @EnvironmentObject var friends: FriendsViewModel
    @State private var selectedDate = Date.now
    private let cal = Calendar.current

    private var slots: [AvailabilitySlot] {
        friends.availabilitySlots(for: friend.user.id, on: selectedDate)
    }

    private var overlayEnabled: Bool {
        friends.calendarOverlayFriendIDs.contains(friend.user.id)
    }

    var body: some View {
        List {
            // Week strip
            Section {
                WeekStrip(selectedDate: $selectedDate)
                    .listRowInsets(EdgeInsets())
            }

            // Calendar overlay toggle
            Section {
                Toggle(isOn: Binding(
                    get: { overlayEnabled },
                    set: { _ in HapticFeedback.light(); friends.toggleOverlay(for: friend.user.id) }
                )) {
                    HStack(spacing: 10) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(friends.overlayColor(for: friend.user.id))
                            .frame(width: 16, height: 16)
                        VStack(alignment: .leading, spacing: 1) {
                            Text("Show on my calendar")
                                .font(.subheadline)
                            Text("Overlay their busy slots in Week & Day views")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            // Availability slots
            if slots.isEmpty {
                Section {
                    ContentUnavailableView(
                        "\(friend.user.displayName) looks free",
                        systemImage: "checkmark.circle",
                        description: Text("No busy slots shared for this day.")
                    )
                }
            } else {
                Section("Busy slots") {
                    ForEach(slots) { slot in
                        AvailabilitySlotRow(slot: slot,
                                            color: friends.overlayColor(for: friend.user.id))
                    }
                }
            }

            // Groups membership
            Section("Groups") {
                ForEach(friends.groups) { group in
                    let isMember = group.memberIDs.contains(friend.user.id)
                    HStack {
                        Text(group.name)
                        Spacer()
                        if isMember {
                            Image(systemName: "checkmark").foregroundStyle(.tint)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        HapticFeedback.light()
                        Task { try? await friends.toggleMembership(friend: friend, group: group) }
                    }
                    .accessibilityLabel("\(group.name), \(isMember ? "member" : "not a member")")
                    .accessibilityHint("Tap to \(isMember ? "remove from" : "add to") \(group.name)")
                }
            }
        }
        .navigationTitle(friend.user.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .task { await friends.loadAvailability(for: friend.user.id, on: selectedDate) }
        .onChange(of: selectedDate) { _, newDate in
            Task { await friends.loadAvailability(for: friend.user.id, on: newDate) }
        }
    }
}

// MARK: - Week strip

struct WeekStrip: View {
    @Binding var selectedDate: Date
    private let cal = Calendar.current

    private var weekDates: [Date] {
        guard let weekStart = cal.date(from: cal.dateComponents(
            [.yearForWeekOfYear, .weekOfYear], from: selectedDate)
        ) else { return [] }
        return (0..<7).compactMap { cal.date(byAdding: .day, value: $0, to: weekStart) }
    }

    var body: some View {
        HStack(spacing: 0) {
            Button { shiftWeek(by: -1) } label: {
                Image(systemName: "chevron.left").padding()
            }
            ForEach(weekDates, id: \.self) { date in
                VStack(spacing: 4) {
                    Text(date.formatted(.dateTime.weekday(.abbreviated)).uppercased())
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    ZStack {
                        let isSelected = cal.isDate(date, inSameDayAs: selectedDate)
                        let isToday    = cal.isDateInToday(date)
                        if isSelected {
                            Circle().fill(isToday ? Color.accentColor : .secondary)
                                .frame(width: 28, height: 28)
                        }
                        Text("\(cal.component(.day, from: date))")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(isSelected ? .white : .primary)
                    }
                }
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
                .onTapGesture { selectedDate = date }
                .accessibilityLabel(date.formatted(.dateTime.weekday(.wide).month().day()))
                .accessibilityAddTraits(cal.isDate(date, inSameDayAs: selectedDate) ? .isSelected : [])
            }
            Button { shiftWeek(by: 1) } label: {
                Image(systemName: "chevron.right").padding()
            }
        }
        .padding(.vertical, 8)
    }

    private func shiftWeek(by weeks: Int) {
        if let d = cal.date(byAdding: .weekOfYear, value: weeks, to: selectedDate) {
            selectedDate = d
        }
    }
}

// MARK: - Slot row

struct AvailabilitySlotRow: View {
    let slot: AvailabilitySlot
    let color: Color

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 3)
                .fill(color.opacity(0.8))
                .frame(width: 4, height: 36)

            VStack(alignment: .leading, spacing: 2) {
                Text(slot.title ?? "Busy")
                    .font(.subheadline)
                    .foregroundStyle(slot.title == nil ? .secondary : .primary)
                Text(timeRange)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var timeRange: String {
        "\(slot.startDate.formatted(date: .omitted, time: .shortened)) – \(slot.endDate.formatted(date: .omitted, time: .shortened))"
    }
}
