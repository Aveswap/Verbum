import Foundation
import ActivityKit
import os

/// Starts / updates / ends the Rush-challenge Live Activity (Lock Screen + Dynamic Island).
/// No-ops gracefully on iOS < 16.2, on non–Dynamic-Island hardware (the Lock-Screen presentation
/// still shows), or when the user has Live Activities disabled in Settings.
@MainActor
enum LiveActivityManager {
    /// True when the device + user settings allow starting a Live Activity.
    static var isAvailable: Bool {
        guard #available(iOS 16.2, *) else { return false }
        return ActivityAuthorizationInfo().areActivitiesEnabled
    }

    /// Is a Rush activity currently running?
    static var isActive: Bool {
        guard #available(iOS 16.2, *) else { return false }
        return !Activity<RushActivityAttributes>.activities.isEmpty
    }

    /// Starts a Rush Live Activity that counts down to `endDate`. Ends any previous Rush activity
    /// first so only one is shown. Returns false if Live Activities aren't available.
    @discardableResult
    static func startRush(endDate: Date) -> Bool {
        guard #available(iOS 16.2, *), ActivityAuthorizationInfo().areActivitiesEnabled else { return false }
        endAll()
        let state = RushActivityAttributes.ContentState(score: 0, endDate: endDate)
        let content = ActivityContent(state: state, staleDate: endDate)
        do {
            _ = try Activity.request(
                attributes: RushActivityAttributes(),
                content: content,
                pushType: nil)
            Logger.liveActivity.info("rush started: endDate=\(endDate, privacy: .public)")
            return true
        } catch {
            Logger.liveActivity.error("rush start failed: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }

    /// Pushes a new score (and the unchanged `endDate`) to any running Rush activity.
    static func updateRush(score: Int, endDate: Date) {
        guard #available(iOS 16.2, *) else { return }
        let state = RushActivityAttributes.ContentState(score: score, endDate: endDate)
        let content = ActivityContent(state: state, staleDate: endDate)
        Task { @MainActor in
            for activity in Activity<RushActivityAttributes>.activities {
                await activity.update(content)
            }
        }
    }

    /// Ends every active Rush Live Activity immediately.
    static func endAll() {
        guard #available(iOS 16.2, *) else { return }
        Task { @MainActor in
            for activity in Activity<RushActivityAttributes>.activities {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
    }
}
