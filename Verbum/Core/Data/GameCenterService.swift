import Foundation
import UIKit
import os

// ⚠️ LOCAL-DEV STUB — Game Center disabled for Personal Team builds (no paid Developer Program).
// Original full implementation preserved at: _LocalDev-Disabled/GameCenterService.swift.original
// Restore before release: replace this file with the original and re-enable Game Center capability.

@MainActor
final class GameCenterService: ObservableObject {
    static let shared = GameCenterService()

    private let logger = Logger(subsystem: "com.verbum.app", category: "GameCenter")

    enum LeaderboardID {
        static let quarterlyPoints = "com.verbum.app.quarterly_points"
        static let allTimePoints   = "com.verbum.app.all_time_points"
    }

    @Published private(set) var isAuthenticated = false
    @Published private(set) var displayName: String?

    private init() {}

    func authenticate() {
        logger.debug("[GameCenter] authenticate() stubbed — local-dev build")
    }

    func submitScore(_ score: Int, to leaderboardID: String) {
        logger.debug("[GameCenter] submitScore() stubbed — local-dev build")
    }

    func showLeaderboard(_ leaderboardID: String = LeaderboardID.quarterlyPoints) {
        logger.debug("[GameCenter] showLeaderboard() stubbed — local-dev build")
    }

    func showFriends() {
        logger.debug("[GameCenter] showFriends() stubbed — local-dev build")
    }
}
