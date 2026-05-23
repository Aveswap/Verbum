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

    // Top 10% / 20% / 30% of ~1000 simulated users
    var rankThreshold: Int {
        switch self {
        case .gold:   return 100
        case .silver: return 200
        case .bronze: return 300
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
