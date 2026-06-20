import Foundation

/// Central config for the OPTIONAL cross-user backend:
///   • GameCenter leaderboards + medals (Perfection / Rush / Sprint)
///   • CloudKit public-database "likes" (how many other people loved a word)
///
/// Everything is DORMANT by default. The app ships with no-op services and compiles WITHOUT any
/// GameKit/CloudKit code. To turn it on:
///   1. Do the provisioning in docs/BACKEND.md (GameCenter leaderboards, iCloud public DB schema,
///      entitlements).
///   2. Add the `VERBUM_BACKEND` Swift compilation flag (project.yml → SWIFT_ACTIVE_COMPILATION_
///      CONDITIONS) so the real GameKit/CloudKit implementations link in.
/// Until then the seams return nil/no-op and the UI simply hides cross-user counts and medals.
enum Backend {
    /// GameCenter leaderboard ID for a challenge — create one per challenge in App Store Connect.
    static func leaderboardID(for kind: ChallengeKind) -> String {
        "com.verbum.app.\(kind.rawValue)"   // e.g. com.verbum.app.sprint
    }
    /// CloudKit public-DB record type for one user's like of one word.
    static let likeRecordType = "WordLike"
}

/// Olympic-style placement on a challenge leaderboard.
enum Medal {
    case gold, silver, bronze

    init?(rank: Int) {
        switch rank {
        case 1: self = .gold
        case 2: self = .silver
        case 3: self = .bronze
        default: return nil
        }
    }

    var symbol: String {
        switch self {
        case .gold:   return "🥇"
        case .silver: return "🥈"
        case .bronze: return "🥉"
        }
    }

    var hex: String {
        switch self {
        case .gold:   return "#FFD700"
        case .silver: return "#C0C0C0"
        case .bronze: return "#CD7F32"
        }
    }
}
