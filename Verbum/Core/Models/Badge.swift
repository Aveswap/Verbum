import Foundation
import SwiftUI

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

    var color: Color {
        switch self {
        case .gold:   return Color(red: 1.0, green: 0.84, blue: 0)
        case .silver: return Color(red: 0.75, green: 0.75, blue: 0.75)
        case .bronze: return Color(red: 0.8, green: 0.5, blue: 0.2)
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
