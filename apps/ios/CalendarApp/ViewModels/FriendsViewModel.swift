import Foundation
import SwiftUI

@MainActor
final class FriendsViewModel: ObservableObject {
    @Published var friends: [Friend] = []
    @Published var groups: [FriendGroup] = []
    @Published var pendingRequests: [FriendshipRow] = []
    @Published var incomingInvites: [EventInvite] = []
    @Published var outgoingEvents: [SharedEvent] = []
    @Published var pendingNotificationInviteID: String?
    @Published var calendarOverlayFriendIDs: Set<String> = {
        let saved = UserDefaults.standard.stringArray(forKey: "overlayFriendIDs") ?? []
        return Set(saved)
    }()
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let service = SupabaseService()

    var inviteBadgeCount: Int { incomingInvites.filter { $0.status == .pending }.count }

    func load() async {
        #if DEBUG
        loadMockData()
        return
        #endif
        guard let uid = await service.currentUser()?.id else { return }
        isLoading = true
        defer { isLoading = false }
        async let f = try? service.fetchFriends(userID: uid)
        async let g = try? service.fetchGroups(ownerID: uid)
        async let p = try? service.fetchPendingRequests(userID: uid)
        async let i = try? service.fetchIncomingInvites(userID: uid)
        friends         = await f ?? []
        groups          = await g ?? []
        pendingRequests = await p ?? []
        incomingInvites = await i ?? []

        if !groups.contains(where: { $0.name == FriendGroup.closeFriendsName }) {
            if let group = try? await service.createGroup(ownerID: uid, name: FriendGroup.closeFriendsName) {
                groups.append(group)
            }
        }
    }

    func addFriend(email: String) async throws {
        guard let currentUID = await service.currentUser()?.id else { return }
        guard let targetUser = try await service.findUser(byEmail: email) else {
            throw FriendsError.userNotFound
        }
        try await service.sendFriendRequest(fromID: currentUID, toID: targetUser.id)
    }

    func acceptRequest(_ row: FriendshipRow) async throws {
        #if DEBUG
        pendingRequests.removeAll { $0.id == row.id }
        // Add Alex as a real friend in the friends list
        if row.requesterID == Self.mockFriendIDs.alex {
            let alex = Friend(id: "mock-friendship-alex",
                              user: AppUser(id: Self.mockFriendIDs.alex,
                                            email: "alex@example.com",
                                            displayName: "Alex Johnson"),
                              groups: [])
            if !friends.contains(where: { $0.user.id == Self.mockFriendIDs.alex }) {
                friends.append(alex)
            }
        }
        return
        #endif
        try await service.acceptFriendRequest(friendshipID: row.id)
        await load()
    }

    func toggleMembership(friend: Friend, group: FriendGroup) async throws {
        #if DEBUG
        guard let idx = groups.firstIndex(where: { $0.id == group.id }) else { return }
        if groups[idx].memberIDs.contains(friend.user.id) {
            groups[idx].memberIDs.removeAll { $0 == friend.user.id }
        } else {
            groups[idx].memberIDs.append(friend.user.id)
        }
        // Also keep friend.groups in sync
        guard let fi = friends.firstIndex(where: { $0.id == friend.id }) else { return }
        if friends[fi].groups.contains(group.id) {
            friends[fi].groups.removeAll { $0 == group.id }
        } else {
            friends[fi].groups.append(group.id)
        }
        return
        #endif
        if group.memberIDs.contains(friend.user.id) {
            try await service.removeMemberFromGroup(groupID: group.id, userID: friend.user.id)
        } else {
            try await service.addMemberToGroup(groupID: group.id, userID: friend.user.id)
        }
        await load()
    }

    func closeFriendsGroup() -> FriendGroup? {
        groups.first { $0.name == FriendGroup.closeFriendsName }
    }

    // MARK: - Calendar Overlay

    static let overlayColors: [Color] = [.purple, .teal, .orange, .indigo, .mint]

    func overlayColor(for friendID: String) -> Color {
        let idx = friends.firstIndex(where: { $0.user.id == friendID }) ?? 0
        return Self.overlayColors[idx % Self.overlayColors.count]
    }

    func toggleOverlay(for friendID: String) {
        if calendarOverlayFriendIDs.contains(friendID) {
            calendarOverlayFriendIDs.remove(friendID)
        } else {
            calendarOverlayFriendIDs.insert(friendID)
        }
        UserDefaults.standard.set(Array(calendarOverlayFriendIDs), forKey: "overlayFriendIDs")
    }

    // MARK: - Availability (centralised, used by overlay + FriendAvailabilityView)

    @Published private var cachedSlots: [String: [AvailabilitySlot]] = [:]

    func availabilitySlots(for friendID: String, on date: Date) -> [AvailabilitySlot] {
        #if DEBUG
        return mockSlots(for: friendID, on: date)
        #endif
        let cal = Calendar.current
        let key = "\(friendID)-\(cal.startOfDay(for: date).timeIntervalSince1970)"
        return cachedSlots[key] ?? []
    }

    func loadAvailability(for friendID: String, on date: Date) async {
        #if DEBUG
        return
        #endif
        guard let viewerID = await service.currentUser()?.id else { return }
        let cal = Calendar.current
        let dayStart = cal.startOfDay(for: date)
        let dayEnd = cal.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart
        let key = "\(friendID)-\(dayStart.timeIntervalSince1970)"
        let slots = (try? await service.fetchAvailability(
            friendID: friendID,
            viewerID: viewerID,
            from: dayStart,
            to: dayEnd
        )) ?? []
        cachedSlots[key] = slots
    }

    // MARK: - Shared Events

    func sendInvites(event: SharedEvent, to friendIDs: [String], emails: [String: String]) {
        #if DEBUG
        // Mock mode: inject invites locally
        var updatedEvent = event
        let newInvites: [EventInvite] = friendIDs.map { fid in
            let friend = friends.first(where: { $0.user.id == fid })
            return EventInvite(
                id: UUID().uuidString,
                eventID: event.id,
                eventTitle: event.title,
                startDate: event.startDate,
                endDate: event.endDate,
                location: event.location,
                organizerName: event.organizerName,
                organizerID: event.organizerID,
                inviteeID: fid,
                inviteeEmail: emails[fid] ?? friend?.user.email ?? "",
                status: .pending
            )
        }
        updatedEvent.invites = newInvites
        outgoingEvents.append(updatedEvent)
        incomingInvites.append(contentsOf: newInvites.filter { $0.inviteeID == "dev-user" })
        return
        #endif
        Task {
            do {
                let eventID = try await service.createSharedEvent(event)
                for fid in friendIDs {
                    let email = emails[fid] ?? friends.first(where: { $0.user.id == fid })?.user.email ?? ""
                    try await service.sendEventInvite(eventID: eventID, inviteeID: fid, inviteeEmail: email)
                }
                await load()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func respondToInvite(id: String, accept: Bool) {
        #if DEBUG
        guard let idx = incomingInvites.firstIndex(where: { $0.id == id }) else { return }
        incomingInvites[idx].status = accept ? .accepted : .declined
        return
        #endif
        Task {
            do {
                try await service.respondToInvite(inviteID: id, accept: accept)
                if let idx = incomingInvites.firstIndex(where: { $0.id == id }) {
                    incomingInvites[idx].status = accept ? .accepted : .declined
                }
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    // MARK: - Errors

    enum FriendsError: LocalizedError {
        case userNotFound
        var errorDescription: String? {
            switch self {
            case .userNotFound: return "No user found with that phone number."
            }
        }
    }

    // MARK: - Mock data

    #if DEBUG
    static let mockFriendIDs = (
        sarah: "mock-friend-sarah",
        james: "mock-friend-james",
        priya: "mock-friend-priya",
        alex:  "mock-stranger-alex"
    )

    private func loadMockData() {
        let closeFriendsGroupID = "mock-group-close"
        let workGroupID         = "mock-group-work"

        friends = [
            Friend(id: "mock-friendship-1",
                   user: AppUser(id: Self.mockFriendIDs.sarah, email: "sarah@example.com", displayName: "Sarah Chen"),
                   groups: [closeFriendsGroupID]),
            Friend(id: "mock-friendship-2",
                   user: AppUser(id: Self.mockFriendIDs.james, email: "james@example.com", displayName: "James Miller"),
                   groups: [closeFriendsGroupID, workGroupID]),
            Friend(id: "mock-friendship-3",
                   user: AppUser(id: Self.mockFriendIDs.priya, email: "priya@example.com", displayName: "Priya Patel"),
                   groups: [workGroupID]),
        ]
        groups = [
            FriendGroup(id: closeFriendsGroupID, name: "Close Friends",
                        memberIDs: [Self.mockFriendIDs.sarah, Self.mockFriendIDs.james]),
            FriendGroup(id: workGroupID, name: "Work",
                        memberIDs: [Self.mockFriendIDs.james, Self.mockFriendIDs.priya]),
        ]

        // Mock pending friend request
        pendingRequests = [
            FriendshipRow(id: "mock-req-1", requesterID: "mock-stranger-alex",
                          addresseeID: "dev-user", status: "pending"),
        ]

        // Mock incoming invite from Sarah
        incomingInvites = [
            EventInvite(
                id: "mock-invite-1",
                eventID: "mock-shared-1",
                eventTitle: "Catch up dinner",
                startDate: Calendar.current.date(byAdding: .day, value: 3,
                    to: Calendar.current.date(bySettingHour: 19, minute: 0, second: 0, of: .now)!)!,
                endDate: Calendar.current.date(byAdding: .day, value: 3,
                    to: Calendar.current.date(bySettingHour: 21, minute: 0, second: 0, of: .now)!)!,
                location: "Dishoom, Covent Garden",
                organizerName: "Sarah Chen",
                organizerID: Self.mockFriendIDs.sarah,
                inviteeID: "dev-user",
                inviteeEmail: "dominic@example.com",
                status: .pending
            ),
        ]
    }

    private func mockSlots(for friendID: String, on date: Date) -> [AvailabilitySlot] {
        let cal = Calendar.current
        func t(_ hour: Int, _ minute: Int = 0) -> Date {
            cal.date(bySettingHour: hour, minute: minute, second: 0, of: date)!
        }
        let dayOfWeek = cal.component(.weekday, from: date)
        let isWeekend = dayOfWeek == 1 || dayOfWeek == 7
        let offset = cal.dateComponents([.day], from: cal.startOfDay(for: .now),
                                         to: cal.startOfDay(for: date)).day ?? 0

        switch friendID {
        case Self.mockFriendIDs.sarah:
            if isWeekend { return [] }
            return [
                AvailabilitySlot(id: "s1-\(offset)", ownerID: friendID, startDate: t(9),      endDate: t(9, 30),  title: "Team standup",   isAllDay: false),
                AvailabilitySlot(id: "s2-\(offset)", ownerID: friendID, startDate: t(10),     endDate: t(11),     title: nil,              isAllDay: false),
                AvailabilitySlot(id: "s3-\(offset)", ownerID: friendID, startDate: t(12, 30), endDate: t(13, 30), title: "Lunch with Dom", isAllDay: false),
                AvailabilitySlot(id: "s4-\(offset)", ownerID: friendID, startDate: t(15),     endDate: t(16),     title: nil,              isAllDay: false),
            ]
        case Self.mockFriendIDs.james:
            if isWeekend {
                return [AvailabilitySlot(id: "j1-\(offset)", ownerID: friendID, startDate: t(11), endDate: t(13), title: nil, isAllDay: false)]
            }
            return [
                AvailabilitySlot(id: "j1-\(offset)", ownerID: friendID, startDate: t(8, 30), endDate: t(9),     title: "Gym",             isAllDay: false),
                AvailabilitySlot(id: "j2-\(offset)", ownerID: friendID, startDate: t(9),     endDate: t(9, 30), title: nil,               isAllDay: false),
                AvailabilitySlot(id: "j3-\(offset)", ownerID: friendID, startDate: t(10),    endDate: t(12),    title: nil,               isAllDay: false),
                AvailabilitySlot(id: "j4-\(offset)", ownerID: friendID, startDate: t(13),    endDate: t(14),    title: nil,               isAllDay: false),
                AvailabilitySlot(id: "j5-\(offset)", ownerID: friendID, startDate: t(14),    endDate: t(16),    title: "Sprint planning", isAllDay: false),
                AvailabilitySlot(id: "j6-\(offset)", ownerID: friendID, startDate: t(17),    endDate: t(18),    title: nil,               isAllDay: false),
            ]
        case Self.mockFriendIDs.priya:
            if isWeekend { return [] }
            return offset % 2 == 0 ? [
                AvailabilitySlot(id: "p1-\(offset)", ownerID: friendID, startDate: t(9),     endDate: t(10),    title: "Client call",   isAllDay: false),
                AvailabilitySlot(id: "p2-\(offset)", ownerID: friendID, startDate: t(14, 30),endDate: t(15, 30),title: "Design review", isAllDay: false),
            ] : [
                AvailabilitySlot(id: "p1-\(offset)", ownerID: friendID, startDate: t(11), endDate: t(12), title: "1:1", isAllDay: false),
            ]
        case Self.mockFriendIDs.alex:
            if isWeekend {
                return [
                    AvailabilitySlot(id: "a1-\(offset)", ownerID: friendID, startDate: t(10), endDate: t(12), title: nil, isAllDay: false),
                    AvailabilitySlot(id: "a2-\(offset)", ownerID: friendID, startDate: t(14), endDate: t(15), title: "Football", isAllDay: false),
                ]
            }
            return [
                AvailabilitySlot(id: "a1-\(offset)", ownerID: friendID, startDate: t(8),     endDate: t(9),     title: "Morning run",   isAllDay: false),
                AvailabilitySlot(id: "a2-\(offset)", ownerID: friendID, startDate: t(11),    endDate: t(12, 30),title: nil,             isAllDay: false),
                AvailabilitySlot(id: "a3-\(offset)", ownerID: friendID, startDate: t(13),    endDate: t(14),    title: "Lunch",         isAllDay: false),
                AvailabilitySlot(id: "a4-\(offset)", ownerID: friendID, startDate: t(16),    endDate: t(17, 30),title: nil,             isAllDay: false),
            ]
        default:
            return []
        }
    }
    #endif
}
