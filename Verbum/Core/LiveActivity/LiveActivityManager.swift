import Foundation
import ActivityKit
import os

/// Starts / ends the "word spotlight" Live Activity (Lock Screen + Dynamic Island).
/// No-ops gracefully on iOS < 16.2, on non–Dynamic-Island hardware (the Lock-Screen presentation
/// still shows), or when the user has Live Activities disabled in Settings.
@MainActor
enum LiveActivityManager {
    /// True when the device + user settings allow starting a Live Activity.
    static var isAvailable: Bool {
        guard #available(iOS 16.2, *) else { return false }
        return ActivityAuthorizationInfo().areActivitiesEnabled
    }

    /// Is a word currently pinned?
    static var isActive: Bool {
        guard #available(iOS 16.2, *) else { return false }
        return !Activity<WordActivityAttributes>.activities.isEmpty
    }

    /// Pins `word` to the Lock Screen / Dynamic Island, ending any previously pinned word first so
    /// only one is shown. Returns false if Live Activities aren't available. Auto-expires in ~8h.
    @discardableResult
    static func pin(_ word: Word) -> Bool {
        guard #available(iOS 16.2, *), ActivityAuthorizationInfo().areActivitiesEnabled else { return false }
        endAll()
        let attributes = WordActivityAttributes(
            word: word.text,
            phonetic: word.phonetic,
            partOfSpeech: word.abbreviatedPartOfSpeech,
            definition: word.definition,
            wordID: word.id.uuidString)
        let content = ActivityContent(
            state: WordActivityAttributes.ContentState(revealed: true),
            staleDate: Date().addingTimeInterval(8 * 3600))
        do {
            _ = try Activity.request(attributes: attributes, content: content, pushType: nil)
            Logger.liveActivity.info("pinned: \(word.text, privacy: .public)")
            return true
        } catch {
            Logger.liveActivity.error("start failed: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }

    /// Ends every active word Live Activity immediately.
    static func endAll() {
        guard #available(iOS 16.2, *) else { return }
        for activity in Activity<WordActivityAttributes>.activities {
            Task { await activity.end(nil, dismissalPolicy: .immediate) }
        }
    }
}
