import SwiftUI

enum CalendarSource: String, Codable, CaseIterable {
    case apple   = "Apple"
    case google  = "Google"
    case outlook = "Outlook"

    var icon: String {
        switch self {
        case .apple:   return "applelogo"
        case .google:  return "g.circle"
        case .outlook: return "envelope.circle"
        }
    }

    var color: Color {
        switch self {
        case .apple:   return .red
        case .google:  return .blue
        case .outlook: return Color(red: 0, green: 0.47, blue: 0.84)
        }
    }
}
