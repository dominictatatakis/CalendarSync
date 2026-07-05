import SwiftUI
import EventKit

struct IncomingInviteView: View {
    let invite: EventInvite
    var onDismiss: () -> Void = {}
    @EnvironmentObject var friends: FriendsViewModel

    @State private var showCalendarPicker = false
    @State private var selectedCalendarTitle = ""
    @State private var availableCalendars: [EKCalendar] = []
    @State private var didAddToCalendar = false
    @State private var calendarError: String?

    private let store = EKEventStore()

    var body: some View {
        List {
            // Event summary
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text(invite.eventTitle)
                        .font(.title3.bold())
                    Label(invite.organizerName, systemImage: "person.circle")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }

            Section("When") {
                LabeledContent("Date") {
                    Text(invite.startDate.formatted(.dateTime.weekday(.wide).month().day()))
                }
                LabeledContent("Time") {
                    Text("\(invite.startDate.formatted(date: .omitted, time: .shortened)) – \(invite.endDate.formatted(date: .omitted, time: .shortened))")
                }
            }

            if let location = invite.location {
                Section("Where") {
                    Label(location, systemImage: "mappin.circle")
                }
            }

            // Accept / Decline — pure status update, no EventKit
            Section {
                Button {
                    HapticFeedback.success()
                    friends.respondToInvite(id: invite.id, accept: true)
                    onDismiss()
                } label: {
                    Label("Accept", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderless)

                Button {
                    HapticFeedback.light()
                    friends.respondToInvite(id: invite.id, accept: false)
                    onDismiss()
                } label: {
                    Label("Decline", systemImage: "xmark.circle.fill")
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderless)
            }

            // Calendar add — separate, optional
            if !didAddToCalendar {
                Section {
                    Button {
                        requestCalendarAndAdd()
                    } label: {
                        Label("Add to my calendar", systemImage: "calendar.badge.plus")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderless)

                    if !availableCalendars.isEmpty {
                        Picker("Calendar", selection: $selectedCalendarTitle) {
                            ForEach(availableCalendars, id: \.title) { cal in
                                Text(cal.title).tag(cal.title)
                            }
                        }
                    }

                    if let err = calendarError {
                        Text(err).font(.caption).foregroundStyle(.red)
                    }
                }
            } else {
                Section {
                    Label("Added to \(selectedCalendarTitle)", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
            }
        }
        .navigationTitle("Invite")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { onDismiss() }
            }
        }
    }

    private func requestCalendarAndAdd() {
        Task {
            let status = EKEventStore.authorizationStatus(for: .event)
            if status == .notDetermined {
                let granted = (try? await store.requestFullAccessToEvents()) ?? false
                if !granted {
                    calendarError = "Calendar access denied."
                    return
                }
            }
            guard EKEventStore.authorizationStatus(for: .event) == .fullAccess else {
                calendarError = "Enable calendar access in Settings."
                return
            }
            let cals = store.calendars(for: .event).filter { $0.allowsContentModifications }
            availableCalendars = cals
            if selectedCalendarTitle.isEmpty {
                selectedCalendarTitle = cals.first?.title ?? store.defaultCalendarForNewEvents?.title ?? "Calendar"
            }
            let cal = cals.first(where: { $0.title == selectedCalendarTitle })
                   ?? cals.first
                   ?? store.defaultCalendarForNewEvents
            guard let cal else {
                calendarError = "No writable calendar found."
                return
            }
            let ekEvent = EKEvent(eventStore: store)
            ekEvent.title     = invite.eventTitle
            ekEvent.startDate = invite.startDate
            ekEvent.endDate   = invite.endDate
            ekEvent.location  = invite.location
            ekEvent.notes     = "Invited by \(invite.organizerName)"
            ekEvent.calendar  = cal
            do {
                try store.save(ekEvent, span: .thisEvent)
                didAddToCalendar = true
            } catch {
                calendarError = "Could not save: \(error.localizedDescription)"
            }
        }
    }
}
