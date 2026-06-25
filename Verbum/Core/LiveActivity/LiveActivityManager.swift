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
        guard #available(iOS 16.2, *) else {
            Logger.liveActivity.error("rush start skipped: iOS < 16.2")
            return false
        }
        let info = ActivityAuthorizationInfo()
        Logger.liveActivity.info("rush start attempt: areActivitiesEnabled=\(info.areActivitiesEnabled, privacy: .public), frequentUpdatesEnabled=\(info.frequentPushesEnabled, privacy: .public)")
        guard info.areActivitiesEnabled else {
            Logger.liveActivity.error("rush start skipped: areActivitiesEnabled=false — user disabled Live Activities in Settings")
            return false
        }
        // Snapshot existing activity IDs BEFORE requesting the new one. If we used the
        // generic `endAll()` here, its async Task would read the activities list AFTER our
        // new request had already added itself to it — and end the new activity too.
        // We capture IDs (Sendable strings) rather than Activity objects to stay within
        // Swift 6 strict-concurrency rules.
        let staleIDs = Set(Activity<RushActivityAttributes>.activities.map(\.id))
        let state = RushActivityAttributes.ContentState(score: 0, endDate: endDate)
        let content = ActivityContent(state: state, staleDate: endDate, relevanceScore: 100)
        do {
            let activity = try Activity.request(
                attributes: RushActivityAttributes(),
                content: content,
                pushType: nil)
            // Now end the previously-running activities only (not the one we just started).
            if !staleIDs.isEmpty {
                Task { @MainActor in
                    for old in Activity<RushActivityAttributes>.activities where staleIDs.contains(old.id) {
                        await old.end(nil, dismissalPolicy: .immediate)
                    }
                }
            }
            Logger.liveActivity.info("rush started: id=\(activity.id, privacy: .public), state=\(String(describing: activity.activityState), privacy: .public), endDate=\(endDate, privacy: .public), totalActive=\(Activity<RushActivityAttributes>.activities.count, privacy: .public)")
            return true
        } catch {
            Logger.liveActivity.error("rush start failed: \(error.localizedDescription, privacy: .public) — \(String(describing: error), privacy: .public)")
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
