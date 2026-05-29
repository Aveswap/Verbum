import Foundation
import GameKit
import UIKit
import os

/// Thin wrapper around GameKit. Handles authentication and score submission
/// for the global quarterly-points leaderboard. Gracefully no-ops if Game Center
/// is unavailable or unauthenticated — UI stays usable.
///
/// Setup checklist (must be done in Xcode + App Store Connect before this works):
/// - Enable Game Center capability in the Verbum target
/// - Create a classic leaderboard in App Store Connect with ID matching
///   `LeaderboardID.quarterlyPoints` below
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

    /// Triggers GameKit authentication. Apple presents a system sheet if needed;
    /// returns silently if the user has already authenticated this session.
    func authenticate() {
        let local = GKLocalPlayer.local
        local.authenticateHandler = { [weak self] vc, error in
            guard let self else { return }
            if let vc {
                // Present the Game Center sign-in sheet on the active scene
                Self.presentOnActiveScene(vc)
                return
            }
            if let error {
                self.logger.error("GameCenter auth failed: \(error.localizedDescription, privacy: .public)")
                self.isAuthenticated = false
                return
            }
            self.isAuthenticated = local.isAuthenticated
            self.displayName = local.isAuthenticated ? local.displayName : nil
        }
    }

    /// Submits a score to the given leaderboard. Silently ignored if not authenticated.
    func submitScore(_ score: Int, to leaderboardID: String) {
        guard isAuthenticated else { return }
        Task {
            do {
                try await GKLeaderboard.submitScore(
                    score,
                    context: 0,
                    player: GKLocalPlayer.local,
                    leaderboardIDs: [leaderboardID]
                )
            } catch {
                logger.error("Score submit failed: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    /// Shows Apple's native Game Center leaderboard UI. No-op if not authenticated.
    func showLeaderboard(_ leaderboardID: String = LeaderboardID.quarterlyPoints) {
        guard isAuthenticated else { authenticate(); return }
        let vc = GKGameCenterViewController(
            leaderboardID: leaderboardID,
            playerScope: .global,
            timeScope: .allTime
        )
        // Dismissal must be wired by a delegate
        vc.gameCenterDelegate = GameCenterCloseDelegate.shared
        Self.presentOnActiveScene(vc)
    }

    /// Shows Apple's native Game Center friends list, where the user can send/accept friend
    /// requests (GameKit has no public API to add friends programmatically, so this is the
    /// supported path). No-op if not authenticated — triggers auth instead.
    func showFriends() {
        guard isAuthenticated else { authenticate(); return }
        let vc = GKGameCenterViewController(state: .localPlayerFriendsList)
        vc.gameCenterDelegate = GameCenterCloseDelegate.shared
        Self.presentOnActiveScene(vc)
    }

    // MARK: - Presentation helper

    private static func presentOnActiveScene(_ vc: UIViewController) {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let root = scene.windows.first(where: { $0.isKeyWindow })?.rootViewController
        else { return }
        // Walk to the topmost presented controller so we don't try to present over a sheet
        var top: UIViewController = root
        while let presented = top.presentedViewController { top = presented }
        top.present(vc, animated: true)
    }
}

/// Apple's GKGameCenterViewController requires a non-nil delegate for dismissal.
private final class GameCenterCloseDelegate: NSObject, GKGameCenterControllerDelegate {
    static let shared = GameCenterCloseDelegate()
    func gameCenterViewControllerDidFinish(_ gameCenterViewController: GKGameCenterViewController) {
        gameCenterViewController.dismiss(animated: true)
    }
}
