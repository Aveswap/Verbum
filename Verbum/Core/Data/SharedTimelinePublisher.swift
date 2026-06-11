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
    static func refresh(profile: UserProfile, isPro: Bool) {
        let pool: [Word] = isPro ? WordRepository.shared.all : WordAccess.freePool()

        guard !pool.isEmpty else {
            SharedWordStore.writeTimeline([])
            publishSnapshot(profile: profile, isPro: isPro)
            return
        }

        // Unseen words lead, so the widget keeps offering words still to learn; once everything
        // has been seen we cycle the whole pool.
        let seen = Set(profile.seenWordIds)
        let unseen = pool.filter { !seen.contains($0.id) }
        let sequence = unseen.isEmpty ? pool : (unseen + pool.filter { seen.contains($0.id) })

        let cal = Calendar.current
        let now = Date()
        let startOfDay = cal.startOfDay(for: now)

        // Distinct words per day = the daily goal; rotate every 24/goal hours (clamped ≥1h).
        let perDay = max(1, profile.dailyGoal)
        let slotHours = max(1, Int((24.0 / Double(perDay)).rounded()))
        let slotsPerDay = max(1, 24 / slotHours)

        // Align to the current slot so the "now" word is stable until the slot ends.
        let hoursSinceMidnight = cal.dateComponents([.hour], from: startOfDay, to: now).hour ?? 0
        let currentSlot = hoursSinceMidnight / slotHours
        guard let slotStart = cal.date(byAdding: .hour, value: currentSlot * slotHours, to: startOfDay) else {
            SharedWordStore.writeTimeline([]); publishSnapshot(profile: profile, isPro: isPro); return
        }

        // Advance the starting word each day so it isn't always the same first word.
        let yearDay = cal.ordinality(of: .day, in: .year, for: startOfDay) ?? 1
        let dayBase = (yearDay - 1) * slotsPerDay

        var timeline: [SharedWordStore.DailyWord] = []
        for i in 0..<(slotsPerDay * horizonDays) {
            guard let date = cal.date(byAdding: .hour, value: i * slotHours, to: slotStart) else { continue }
            let word = sequence[(dayBase + currentSlot + i) % sequence.count]
            timeline.append(.init(
                date: date,
                id: word.id,
                text: word.text,
                phonetic: word.phonetic,
                partOfSpeech: word.partOfSpeech,
                definition: word.definition,
                translation: nil
            ))
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

    private static func publishSnapshot(profile: UserProfile, isPro: Bool) {
        let cal = Calendar.current
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
