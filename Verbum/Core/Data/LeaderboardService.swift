import Foundation

/// Cross-user challenge leaderboard + medals. Dormant by default (no-op); the real GameCenter
/// implementation links in only under the `VERBUM_BACKEND` compilation flag.
@MainActor
protocol LeaderboardService: AnyObject {
    /// Submit a finished challenge score to the global leaderboard.
    func submit(score: Int, for kind: ChallengeKind)
    /// The local player's current global rank for a challenge (nil = unranked / backend off).
    func rank(for kind: ChallengeKind) async -> Int?
}

/// Dormant default — no cross-user leaderboard. Always compiled.
@MainActor
final class NoLeaderboardService: LeaderboardService {
    func submit(score: Int, for kind: ChallengeKind) {}
    func rank(for kind: ChallengeKind) async -> Int? { nil }
}

@MainActor
enum Leaderboards {
    static let service: LeaderboardService = {
        #if VERBUM_BACKEND
        return GameCenterLeaderboardService()
        #else
        return NoLeaderboardService()
        #endif
    }()

    /// The player's medal for a challenge, if they're currently top-3 globally.
    static func medal(for kind: ChallengeKind) async -> Medal? {
        guard let r = await service.rank(for: kind) else { return nil }
        return Medal(rank: r)
    }
}

#if VERBUM_BACKEND
import GameKit

/// GameCenter-backed leaderboard. Apple hosts the global ranking; medals derive from the top-3.
/// Requires: GameCenter capability + a leaderboard per challenge in App Store Connect
/// (IDs from `Backend.leaderboardID(for:)`). Verify API details on first real build.
@MainActor
final class GameCenterLeaderboardService: LeaderboardService {
    func submit(score: Int, for kind: ChallengeKind) {
        guard GKLocalPlayer.local.isAuthenticated else { return }
        let id = Backend.leaderboardID(for: kind)
        Task {
            try? await GKLeaderboard.submitScore(score, context: 0,
                                                 player: GKLocalPlayer.local,
                                                 leaderboardIDs: [id])
        }
    }

    func rank(for kind: ChallengeKind) async -> Int? {
        guard GKLocalPlayer.local.isAuthenticated else { return nil }
        let id = Backend.leaderboardID(for: kind)
        guard let board = try? await GKLeaderboard.loadLeaderboards(IDs: [id]).first else { return nil }
        // The first tuple element is the local player's entry.
        let result = try? await board.loadEntries(for: .global, timeScope: .allTime,
                                                   range: NSRange(location: 1, length: 1))
        return result?.0?.rank
    }
}
#endif
