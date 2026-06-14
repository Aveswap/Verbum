import Foundation
import WidgetKit

/// Computes the rotating Word timeline + user snapshot and hands them to `SharedWordStore`
/// so the widget and Apple Watch can render without ever touching the main app's database.
///
/// The timeline rotates **intra-day**: it surfaces `dailyGoal` distinct words per day (so the
/// user's "3 / 4 / more new words a day" choice drives the cadence), advancing to a fresh word
/// every `24 / dailyGoal` hours. Each time the user glances at the widget after a while it shows
/// a new word; tapping any entry deep-links into that word (see the widget's `widgetURL`). New
/// (unseen) words lead the rotation, and the starting word advances each day.
///
/// (iOS widgets can't fire on unlock — WidgetKit only refreshes on a *timeline* — so a
/// time-sliced rotation is the App-Store-compliant way to approximate "a new word each time you
/// pick up the phone".)
///
/// Called on app launch and whenever profile-relevant state changes
/// (`isPro`, `dailyGoal`, `seenWordIds`, `currentStreak`).
@MainActor
enum SharedTimelinePublisher {
    /// Days of slots to pre-compute, so the timeline stays fresh between launches.
    static let horizonDays = 2

    /// Build + publish the timeline + snapshot, then nudge WidgetKit to reload.
    ///
    /// The timeline shows the SAME "words of the day" the notifications announce — both pull from
    /// `DailyWords.forToday` with `count = notificationCount`. There are `count` slots per day,
    /// one word each, rotating through the day; advancing to the next day's set automatically.
    static func refresh(profile: UserProfile, isPro: Bool) {
        let cal = dayCalendar(for: profile)
        let count = max(1, profile.notificationCount)
        let seen = Set(profile.seenWordIds)
        let startOfDay = cal.startOfDay(for: Date())
        let slotHours = max(1, 24 / count)

        var timeline: [SharedWordStore.DailyWord] = []
        for dayOffset in 0..<horizonDays {
            guard let dayStart = cal.date(byAdding: .day, value: dayOffset, to: startOfDay) else { continue }
            let words = DailyWords.forToday(count: count, seenIds: seen, calendar: cal, isPro: isPro, now: dayStart)
            for (i, word) in words.enumerated() {
                guard let date = cal.date(byAdding: .hour, value: i * slotHours, to: dayStart) else { continue }
                timeline.append(.init(
                    date: date, id: word.id, text: word.text, phonetic: word.phonetic,
                    partOfSpeech: word.partOfSpeech, definition: word.definition, translation: nil
                ))
            }
        }
        SharedWordStore.writeTimeline(timeline)
        publishSnapshot(profile: profile, isPro: isPro)

        // Ask WidgetKit to reload — cheap and idempotent.
        if #available(iOS 14.0, *) {
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    /// Updates only the lightweight counts/streak snapshot — NOT the rotating word timeline.
    /// Use on hot paths (e.g. the per-swipe daily counter) where the rotation can't have
    /// changed, so we skip rebuilding the whole slot timeline.
    static func refreshSnapshotOnly(profile: UserProfile, isPro: Bool) {
        publishSnapshot(profile: profile, isPro: isPro)
        if #available(iOS 14.0, *) {
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    /// Day-boundary calendar anchored to the user's locked streak timezone, so the widget's
    /// "today" agrees with the streak / daily-goal logic (which use UserProfileStore.dayCalendar).
    private static func dayCalendar(for profile: UserProfile) -> Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: profile.streakTimezone ?? "") ?? .current
        return cal
    }

    private static func publishSnapshot(profile: UserProfile, isPro: Bool) {
        let cal = dayCalendar(for: profile)
        let learnedToday = cal.isDateInToday(profile.wordsLearnedDate) ? profile.wordsLearnedToday : 0
        let free = isPro ? nil : WordAccess.remainingFreeCount(
            seenIds: Set(profile.seenWordIds))
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
