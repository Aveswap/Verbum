import Foundation

/// Widget-side copy of SharedWordStore — reads the timeline and snapshot
/// written by the main app via the shared App Group UserDefaults suite.
enum SharedWordStore {
    static let appGroupID = "group.com.verbum.app"

    private static var store: UserDefaults? {
        UserDefaults(suiteName: appGroupID)
    }

    private enum Keys {
        static let timeline   = "timeline_v1"
        static let snapshot   = "snapshot_v1"
        static let writtenAt  = "writtenAt_v1"
    }

    // ⚠️ KEEP IN SYNC with Verbum/Core/Data/SharedWordStore.swift — these structs + the Keys/appGroupID
    // are duplicated across the widget and app targets. Any change there MUST be mirrored here, or
    // this widget silently fails to decode the App-Group payload and shows only a placeholder.
    struct DailyWord: Codable, Equatable {
        let date: Date
        let id: UUID
        let text: String
        let phonetic: String
        let partOfSpeech: String
        let definition: String
        let translation: String?
    }

    struct Snapshot: Codable, Equatable {
        let currentStreak: Int
        let longestStreak: Int
        let wordsLearnedToday: Int
        let dailyGoal: Int
        let isPro: Bool
        let freeRemaining: Int?
    }

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

    static var lastWrittenAt: Date? {
        store?.object(forKey: Keys.writtenAt) as? Date
    }
}
