import Foundation

enum BadgeTier: String, Codable, CaseIterable {
    case gold, silver, bronze

    var emoji: String {
        switch self {
        case .gold:   return "🥇"
        case .silver: return "🥈"
        case .bronze: return "🥉"
        }
    }

    var label: String {
        switch self {
        case .gold:   return "Gold"
        case .silver: return "Silver"
        case .bronze: return "Bronze"
        }
    }

}

struct EarnedBadge: Codable, Identifiable {
    var id: UUID = UUID()
    let tier: BadgeTier
    let period: String   // e.g. "Q2 2026"
    let points: Int
    let date: Date
}
