import Foundation

/// Bridge between the main app and its widget / watch extensions.
///
/// The main app writes a precomputed 14-day "Word of the Day" timeline plus a tiny
/// snapshot of user progress (streak, daily-goal pulse) into a shared UserDefaults
/// suite. Extensions read from the same suite — no network, no XPC, no IPC dance.
///
/// **Requires** an App Group capability with identifier `group.com.verbum.app`
/// added to the main app + every extension target. See `WIDGET_AND_WATCH_SETUP.md`.
enum SharedWordStore {
    /// Bundle/group identifier. Must match the App Group set in every target's
    /// Signing & Capabilities pane.
    static let appGroupID = "group.com.verbum.app"

    private static var store: UserDefaults? {
        UserDefaults(suiteName: appGroupID)
    }

    // MARK: - Keys

    private enum Keys {
        static let timeline   = "timeline_v1"
        static let snapshot   = "snapshot_v1"
        static let writtenAt  = "writtenAt_v1"
    }

    // MARK: - Models written to the shared store

    /// One day's worth of word + native-language translation for the widget / watch.
    /// Stripped to a small inline blob so we don't re-encode the entire 1000-word catalog.
    struct DailyWord: Codable, Equatable {
        let date: Date            // start-of-day in user's timezone
        let id: UUID
        let text: String
        let phonetic: String
        let partOfSpeech: String
        let definition: String
        let translation: String?  // L1 — may be nil for languages w/o a bundle
    }

    /// User progress glanced at by the widget and watch — cheap stuff only.
    struct Snapshot: Codable, Equatable {
        let currentStreak: Int
        let longestStreak: Int
        let wordsLearnedToday: Int
        let dailyGoal: Int
        let isPro: Bool
        /// Free pool size remaining at user's level — for the "N free words left" pill.
        /// nil for pro users.
        let freeRemaining: Int?
    }

    // MARK: - Write (main app side)

    static func writeTimeline(_ days: [DailyWord]) {
        guard let store, let data = try? JSONEncoder().encode(days) else { return }
        store.set(data, forKey: Keys.timeline)
        store.set(Date(), forKey: Keys.writtenAt)
    }

    static func writeSnapshot(_ snapshot: Snapshot) {
        guard let store, let data = try? JSONEncoder().encode(snapshot) else { return }
        store.set(data, forKey: Keys.snapshot)
    }

    // MARK: - Read (widget / watch side)

    static func readTimeline() -> [DailyWord] {
        guard let store, let data = store.data(forKey: Keys.timeline),
              let days = try? JSONDecoder().decode([DailyWord].self, from: data)
        else { return [] }
        return days
    }

    static func readSnapshot() -> Snapshot? {
        guard let store, let data = store.data(forKey: Keys.snapshot) else { return nil }
        return try? JSONDecoder().decode(Snapshot.self, from: data)
    }

    /// When the main app last published — extensions can show a "stale" badge if older than ~48h.
    static var lastWrittenAt: Date? {
        store?.object(forKey: Keys.writtenAt) as? Date
    }
}
