import Foundation

struct FriendGroup: Identifiable, Codable {
    let id: String
    var name: String
    var memberIDs: [String]

    static let closeFriendsName = "Close Friends"

    enum CodingKeys: String, CodingKey {
        case id, name
        case memberIDs = "member_ids"
    }
}
