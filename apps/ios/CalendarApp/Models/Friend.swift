import Foundation

struct Friend: Identifiable, Codable {
    let id: String        // friendship row id
    let user: AppUser
    var groups: [String]  // group IDs this friend belongs to

    enum CodingKeys: String, CodingKey {
        case id, user, groups
    }
}

enum FriendshipStatus: String, Codable {
    case pending  = "pending"
    case accepted = "accepted"
}
