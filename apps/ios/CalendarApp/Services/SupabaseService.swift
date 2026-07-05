import Foundation
import Supabase

// MARK: - Supabase client singleton
let supabase = SupabaseClient(
    supabaseURL: URL(string: Secrets.supabaseURL)!,
    supabaseKey: Secrets.supabaseAnonKey
)

// MARK: - Database row types (snake_case to match Postgres columns)

struct ProfileRow: Codable {
    let id: String
    var email: String
    var displayName: String
    var avatarURL: String?

    enum CodingKeys: String, CodingKey {
        case id, email
        case displayName = "display_name"
        case avatarURL   = "avatar_url"
    }
}

struct FriendshipRow: Codable, Identifiable {
    let id: String
    let requesterID: String
    let addresseeID: String
    let status: String

    enum CodingKeys: String, CodingKey {
        case id
        case requesterID = "requester_id"
        case addresseeID = "addressee_id"
        case status
    }
}

struct GroupRow: Codable, Identifiable {
    let id: String
    let ownerID: String
    var name: String

    enum CodingKeys: String, CodingKey {
        case id
        case ownerID = "owner_id"
        case name
    }
}

struct GroupMemberRow: Codable {
    let groupID: String
    let userID: String

    enum CodingKeys: String, CodingKey {
        case groupID = "group_id"
        case userID  = "user_id"
    }
}

struct EventShareRow: Codable, Identifiable {
    let id: String
    let ownerID: String
    let eventID: String
    let source: String
    let groupID: String
    let isDetailsVisible: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case ownerID         = "owner_id"
        case eventID         = "event_id"
        case source
        case groupID         = "group_id"
        case isDetailsVisible = "is_details_visible"
    }
}

// MARK: - SupabaseService

@MainActor
final class SupabaseService: ObservableObject {

    // MARK: Auth

    func sendOTP(email: String) async throws {
        try await supabase.auth.signInWithOTP(email: email)
    }

    func verifyOTP(email: String, token: String) async throws -> AppUser {
        let session = try await supabase.auth.verifyOTP(
            email: email,
            token: token,
            type: .email
        )
        let uid = session.user.id.uuidString
        let userEmail = session.user.email ?? email
        return try await upsertProfile(id: uid, email: userEmail)
    }

    func currentUser() async -> AppUser? {
        guard let session = try? await supabase.auth.session else { return nil }
        let uid = session.user.id.uuidString
        return try? await fetchProfile(id: uid)
    }

    func signOut() async throws {
        try await supabase.auth.signOut()
    }

    func signInWithAppleToken(idToken: String, nonce: String) async throws -> AppUser {
        let session = try await supabase.auth.signInWithIdToken(
            credentials: OpenIDConnectCredentials(provider: .apple, idToken: idToken, nonce: nonce)
        )
        let uid = session.user.id.uuidString
        let email = session.user.email ?? uid
        return try await upsertProfile(id: uid, email: email)
    }

    func signInWithGoogleToken(idToken: String, accessToken: String) async throws -> AppUser {
        let session = try await supabase.auth.signInWithIdToken(
            credentials: OpenIDConnectCredentials(provider: .google, idToken: idToken, accessToken: accessToken)
        )
        let uid = session.user.id.uuidString
        let email = session.user.email ?? uid
        return try await upsertProfile(id: uid, email: email)
    }

    // MARK: Profiles

    private func upsertProfile(id: String, email: String) async throws -> AppUser {
        let row = ProfileRow(id: id, email: email, displayName: email, avatarURL: nil)
        try await supabase
            .from("profiles")
            .upsert(row, onConflict: "id")
            .execute()
        return AppUser(id: id, email: email, displayName: email, avatarURL: nil)
    }

    func updateDisplayName(_ name: String, userID: String) async throws {
        try await supabase
            .from("profiles")
            .update(["display_name": name])
            .eq("id", value: userID)
            .execute()
    }

    private func fetchProfile(id: String) async throws -> AppUser {
        let row: ProfileRow = try await supabase
            .from("profiles")
            .select()
            .eq("id", value: id)
            .single()
            .execute()
            .value
        return AppUser(
            id: row.id,
            email: row.email,
            displayName: row.displayName,
            avatarURL: row.avatarURL.flatMap { URL(string: $0) }
        )
    }

    func findUser(byEmail email: String) async throws -> AppUser? {
        let rows: [ProfileRow] = try await supabase
            .from("profiles")
            .select()
            .eq("email", value: email)
            .execute()
            .value
        guard let row = rows.first else { return nil }
        return AppUser(
            id: row.id,
            email: row.email,
            displayName: row.displayName,
            avatarURL: row.avatarURL.flatMap { URL(string: $0) }
        )
    }

    func findUsers(byEmails emails: [String]) async throws -> [AppUser] {
        guard !emails.isEmpty else { return [] }
        let rows: [ProfileRow] = try await supabase
            .from("profiles")
            .select()
            .in("email", values: emails)
            .execute()
            .value
        return rows.map { AppUser(
            id: $0.id,
            email: $0.email,
            displayName: $0.displayName,
            avatarURL: $0.avatarURL.flatMap { URL(string: $0) }
        )}
    }

    // MARK: Friendships

    func sendFriendRequest(fromID: String, toID: String) async throws {
        let row: [String: String] = [
            "requester_id": fromID,
            "addressee_id": toID,
            "status": "pending"
        ]
        try await supabase.from("friendships").insert(row).execute()
    }

    func acceptFriendRequest(friendshipID: String) async throws {
        try await supabase
            .from("friendships")
            .update(["status": "accepted"])
            .eq("id", value: friendshipID)
            .execute()
    }

    func fetchFriends(userID: String) async throws -> [Friend] {
        // Fetch accepted friendships where user is requester or addressee
        let rows: [FriendshipRow] = try await supabase
            .from("friendships")
            .select()
            .eq("status", value: "accepted")
            .or("requester_id.eq.\(userID),addressee_id.eq.\(userID)")
            .execute()
            .value

        var friends: [Friend] = []
        for row in rows {
            let friendID = row.requesterID == userID ? row.addresseeID : row.requesterID
            if let user = try? await fetchProfile(id: friendID) {
                let groups = try await fetchGroupIDsForMember(userID: friendID, ownerID: userID)
                friends.append(Friend(id: row.id, user: user, groups: groups))
            }
        }
        return friends
    }

    func fetchPendingRequests(userID: String) async throws -> [FriendshipRow] {
        try await supabase
            .from("friendships")
            .select()
            .eq("addressee_id", value: userID)
            .eq("status", value: "pending")
            .execute()
            .value
    }

    // MARK: Groups

    func fetchGroups(ownerID: String) async throws -> [FriendGroup] {
        let rows: [GroupRow] = try await supabase
            .from("groups")
            .select()
            .eq("owner_id", value: ownerID)
            .execute()
            .value

        var groups: [FriendGroup] = []
        for row in rows {
            let members = try await fetchGroupMembers(groupID: row.id)
            groups.append(FriendGroup(id: row.id, name: row.name, memberIDs: members))
        }
        return groups
    }

    func createGroup(ownerID: String, name: String) async throws -> FriendGroup {
        let row: GroupRow = try await supabase
            .from("groups")
            .insert(["owner_id": ownerID, "name": name])
            .single()
            .execute()
            .value
        return FriendGroup(id: row.id, name: row.name, memberIDs: [])
    }

    func addMemberToGroup(groupID: String, userID: String) async throws {
        let row: [String: String] = ["group_id": groupID, "user_id": userID]
        try await supabase.from("group_members").insert(row).execute()
    }

    func removeMemberFromGroup(groupID: String, userID: String) async throws {
        try await supabase
            .from("group_members")
            .delete()
            .eq("group_id", value: groupID)
            .eq("user_id", value: userID)
            .execute()
    }

    private func fetchGroupMembers(groupID: String) async throws -> [String] {
        let rows: [GroupMemberRow] = try await supabase
            .from("group_members")
            .select()
            .eq("group_id", value: groupID)
            .execute()
            .value
        return rows.map(\.userID)
    }

    private func fetchGroupIDsForMember(userID: String, ownerID: String) async throws -> [String] {
        let rows: [GroupMemberRow] = try await supabase
            .from("group_members")
            .select("group_id, groups!inner(owner_id)")
            .eq("user_id", value: userID)
            .execute()
            .value
        return rows.map(\.groupID)
    }

    // MARK: Event Sharing

    func setEventSharing(event: CalendarEvent, groupID: String, ownerID: String, share: Bool, showDetails: Bool) async throws {
        if share {
            struct EventShareInsert: Encodable {
                let ownerID: String
                let eventID: String
                let source: String
                let groupID: String
                let isDetailsVisible: Bool
                enum CodingKeys: String, CodingKey {
                    case ownerID = "owner_id"
                    case eventID = "event_id"
                    case source
                    case groupID = "group_id"
                    case isDetailsVisible = "is_details_visible"
                }
            }
            let row = EventShareInsert(
                ownerID: ownerID,
                eventID: event.id,
                source: event.source.rawValue,
                groupID: groupID,
                isDetailsVisible: showDetails
            )
            try await supabase
                .from("event_shares")
                .upsert(row, onConflict: "owner_id,event_id,group_id")
                .execute()
        } else {
            try await supabase
                .from("event_shares")
                .delete()
                .eq("owner_id", value: ownerID)
                .eq("event_id", value: event.id)
                .eq("group_id", value: groupID)
                .execute()
        }
    }

    func fetchSharedEvents(ownerID: String) async throws -> [EventShareRow] {
        try await supabase
            .from("event_shares")
            .select()
            .eq("owner_id", value: ownerID)
            .execute()
            .value
    }

    // MARK: Push Notifications

    func saveDeviceToken(_ token: String) async throws {
        guard let uid = await currentUser()?.id else { return }
        struct TokenRow: Encodable {
            let userID: String
            let token: String
            let platform: String
            enum CodingKeys: String, CodingKey {
                case userID   = "user_id"
                case token, platform
            }
        }
        try await supabase
            .from("device_tokens")
            .upsert(TokenRow(userID: uid, token: token, platform: "ios"),
                    onConflict: "user_id,token")
            .execute()
    }

    // MARK: Availability (friend's view)
    // Returns time slots for a friend that are visible to the current user
    func fetchAvailability(friendID: String, viewerID: String, from: Date, to: Date) async throws -> [AvailabilitySlot] {
        struct Params: Encodable {
            let friendID: String
            let viewerID: String
            let rangeStart: String
            let rangeEnd: String

            enum CodingKeys: String, CodingKey {
                case friendID  = "friend_id"
                case viewerID  = "viewer_id"
                case rangeStart = "range_start"
                case rangeEnd   = "range_end"
            }
        }

        struct SlotRow: Decodable {
            let id: String
            let ownerID: String
            let startDate: String
            let endDate: String
            let title: String?
            let isAllDay: Bool

            enum CodingKeys: String, CodingKey {
                case id
                case ownerID   = "owner_id"
                case startDate = "start_date"
                case endDate   = "end_date"
                case title
                case isAllDay  = "is_all_day"
            }
        }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let params = Params(
            friendID: friendID,
            viewerID: viewerID,
            rangeStart: formatter.string(from: from),
            rangeEnd: formatter.string(from: to)
        )

        let rows: [SlotRow] = try await supabase
            .rpc("get_availability", params: params)
            .execute()
            .value

        return rows.compactMap { row in
            guard let start = formatter.date(from: row.startDate),
                  let end = formatter.date(from: row.endDate) else { return nil }
            return AvailabilitySlot(
                id: row.id,
                ownerID: row.ownerID,
                startDate: start,
                endDate: end,
                title: row.title,
                isAllDay: row.isAllDay
            )
        }
    }

    // MARK: Shared Events & Invites

    func createSharedEvent(_ event: SharedEvent) async throws -> String {
        struct SharedEventInsert: Encodable {
            let organizerID: String
            let organizerName: String
            let title: String
            let startDate: String
            let endDate: String
            let location: String?
            let notes: String?

            enum CodingKeys: String, CodingKey {
                case organizerID   = "organizer_id"
                case organizerName = "organizer_name"
                case title
                case startDate     = "start_date"
                case endDate       = "end_date"
                case location, notes
            }
        }

        struct InsertResult: Decodable {
            let id: String
        }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let row = SharedEventInsert(
            organizerID: event.organizerID,
            organizerName: event.organizerName,
            title: event.title,
            startDate: formatter.string(from: event.startDate),
            endDate: formatter.string(from: event.endDate),
            location: event.location,
            notes: event.notes
        )

        let result: InsertResult = try await supabase
            .from("shared_events")
            .insert(row)
            .select("id")
            .single()
            .execute()
            .value

        return result.id
    }

    func sendEventInvite(eventID: String, inviteeID: String, inviteeEmail: String) async throws {
        struct InviteInsert: Encodable {
            let eventID: String
            let inviteeID: String
            let inviteeEmail: String

            enum CodingKeys: String, CodingKey {
                case eventID      = "event_id"
                case inviteeID    = "invitee_id"
                case inviteeEmail = "invitee_email"
            }
        }

        let row = InviteInsert(eventID: eventID, inviteeID: inviteeID, inviteeEmail: inviteeEmail)
        try await supabase.from("event_invites").insert(row).execute()
    }

    func fetchIncomingInvites(userID: String) async throws -> [EventInvite] {
        struct InviteRow: Decodable {
            let id: String
            let eventID: String
            let inviteeID: String
            let inviteeEmail: String?
            let status: String
            let sharedEvent: SharedEventRow?

            enum CodingKeys: String, CodingKey {
                case id
                case eventID      = "event_id"
                case inviteeID    = "invitee_id"
                case inviteeEmail = "invitee_email"
                case status
                case sharedEvent  = "shared_events"
            }
        }

        struct SharedEventRow: Decodable {
            let id: String
            let organizerID: String
            let organizerName: String
            let title: String
            let startDate: String
            let endDate: String
            let location: String?
            let notes: String?

            enum CodingKeys: String, CodingKey {
                case id
                case organizerID   = "organizer_id"
                case organizerName = "organizer_name"
                case title
                case startDate     = "start_date"
                case endDate       = "end_date"
                case location, notes
            }
        }

        let rows: [InviteRow] = try await supabase
            .from("event_invites")
            .select("*, shared_events(*)")
            .eq("invitee_id", value: userID)
            .eq("status", value: "pending")
            .execute()
            .value

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        return rows.compactMap { row in
            guard let event = row.sharedEvent,
                  let start = formatter.date(from: event.startDate),
                  let end = formatter.date(from: event.endDate) else { return nil }
            return EventInvite(
                id: row.id,
                eventID: row.eventID,
                eventTitle: event.title,
                startDate: start,
                endDate: end,
                location: event.location,
                organizerName: event.organizerName,
                organizerID: event.organizerID,
                inviteeID: row.inviteeID,
                inviteeEmail: row.inviteeEmail ?? "",
                status: EventInvite.InviteStatus(rawValue: row.status) ?? .pending
            )
        }
    }

    func respondToInvite(inviteID: String, accept: Bool) async throws {
        try await supabase
            .from("event_invites")
            .update(["status": accept ? "accepted" : "declined"])
            .eq("id", value: inviteID)
            .execute()
    }
}
