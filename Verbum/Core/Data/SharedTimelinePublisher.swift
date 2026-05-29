import Foundation
import WidgetKit

/// Computes the 14-day Word of the Day timeline + user snapshot and hands them
/// to `SharedWordStore` so the widget and Apple Watch can render without ever
/// touching the main app's database.
///
/// Called on app launch and whenever profile-relevant state changes
/// (`isPro`, `level`, `dailyGoal`, `seenWordIds`, `currentStreak`).
@MainActor
enum SharedTimelinePublisher {
    static let horizonDays = 14

    /// Build + publish the timeline + snapshot, then nudge WidgetKit to reload.
    static func refresh(profile: UserProfile, isPro: Bool) {
        let pool: [Word] = isPro
            ? WordRepository.shared.all.filter { $0.level == profile.level }
            : WordAccess.freePool(level: profile.level)

        guard !pool.isEmpty else {
            SharedWordStore.writeTimeline([])
            publishSnapshot(profile: profile, isPro: isPro)
            return
        }

        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let yearDay = cal.ordinality(of: .day, in: .year, for: today) ?? 1

        var timeline: [SharedWordStore.DailyWord] = []
        for offset in 0..<horizonDays {
            guard let date = cal.date(byAdding: .day, value: offset, to: today) else { continue }
            let index = (yearDay - 1 + offset) % pool.count
            let word = pool[index]
            timeline.append(.init(
                date: date,
                id: word.id,
                text: word.text,
                phonetic: word.phonetic,
                partOfSpeech: word.partOfSpeech,
                definition: word.definition,
                translation: nil,
                level: word.level.rawValue
            ))
        }
        SharedWordStore.writeTimeline(timeline)
        publishSnapshot(profile: profile, isPro: isPro)

        // Ask WidgetKit to reload — cheap and idempotent.
        if #available(iOS 14.0, *) {
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    /// Updates only the lightweight counts/streak snapshot — NOT the 14-day word timeline.
    /// Use on hot paths (e.g. the per-swipe daily counter) where the timeline can't have
    /// changed: the full refresh() does 14 synchronous translation DB reads, which is pure
    /// waste when only `wordsLearnedToday`/`currentStreak` ticked.
    static func refreshSnapshotOnly(profile: UserProfile, isPro: Bool) {
        publishSnapshot(profile: profile, isPro: isPro)
        if #available(iOS 14.0, *) {
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    private static func publishSnapshot(profile: UserProfile, isPro: Bool) {
        let cal = Calendar.current
        let learnedToday = cal.isDateInToday(profile.wordsLearnedDate) ? profile.wordsLearnedToday : 0
        let free = isPro ? nil : WordAccess.remainingFreeCount(
            seenIds: Set(profile.seenWordIds),
            userLevel: profile.level
        )
        SharedWordStore.writeSnapshot(.init(
            currentStreak: profile.currentStreak,
            longestStreak: profile.longestStreak,
            wordsLearnedToday: learnedToday,
            dailyGoal: profile.dailyGoal,
            isPro: isPro,
            freeRemaining: free
        ))
    }
}
