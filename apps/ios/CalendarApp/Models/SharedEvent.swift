import Foundation

struct SharedEvent: Identifiable, Codable {
    let id: String
    let title: String
    let startDate: Date
    let endDate: Date
    let location: String?
    let notes: String?
    let organizerID: String
    let organizerName: String
    var invites: [EventInvite]
}

struct EventInvite: Identifiable, Codable {
    let id: String
    let eventID: String
    let eventTitle: String
    let startDate: Date
    let endDate: Date
    let location: String?
    let organizerName: String
    let organizerID: String
    let inviteeID: String
    let inviteeEmail: String
    var status: InviteStatus

    enum InviteStatus: String, Codable {
        case pending, accepted, declined
    }
}
