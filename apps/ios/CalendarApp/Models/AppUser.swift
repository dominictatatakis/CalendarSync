import Foundation

struct AppUser: Identifiable, Codable {
    let id: String
    var email: String
    var displayName: String
    var avatarURL: URL?

    enum CodingKeys: String, CodingKey {
        case id, email
        case displayName = "display_name"
        case avatarURL   = "avatar_url"
    }
}
