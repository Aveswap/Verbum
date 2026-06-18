import Foundation

/// Pure streak / freeze math, extracted from `UserProfileStore.recordDailyOpen` so it can be
/// unit-tested without a `@MainActor` host, CloudKit, or a database boot. Deterministic given
/// `(profile, calendar, now)`.
///
/// Rules (unchanged from the shipped behaviour):
///   • open on the same calendar day as the last open → nothing to persist (returns `nil`)
///   • consecutive day → streak +1
///   • gap fully covered by freezes → streak survives (+1), burn one freeze per missed day
///   • partial / no coverage → streak resets to 1 (freezes left untouched)
///   • every 7th consecutive day → +1 freeze, capped at `freezeCap`
///   • `dailyOpens` deduplicated and trimmed to the last 7 days
///
/// The day boundary is whatever `calendar` encodes — callers pass the streak-locked
/// `dayCalendar` so travel / DST can't shift "today".
enum StreakEngine {
    static let freezeCap = 3
    static let milestoneInterval = 7
    private static let dailyOpensWindow = 7

    /// Applies an app-open at `now`. Returns the updated profile, or `nil` when the open falls on
    /// the same calendar day as the last open (so the caller can skip the save, exactly as the
    /// original early-return did).
    static func recordOpen(_ profile: UserProfile, calendar cal: Calendar, now: Date) -> UserProfile? {
        var profile = profile
        let today = cal.startOfDay(for: now)

        if let last = profile.lastOpenedDate {
            let lastDay = cal.startOfDay(for: last)
            if cal.isDate(lastDay, inSameDayAs: today) { return nil }
            let diff = cal.dateComponents([.day], from: lastDay, to: today).day ?? 0
            if diff == 1 {
                profile.currentStreak += 1
            } else if diff > 1, profile.streakFreezes >= (diff - 1) {
                // Only spend freezes when they fully cover the gap — a partial burn would
                // reset the streak AND consume the freezes for zero benefit.
                let missedDays = diff - 1
                profile.streakFreezes -= missedDays
                for _ in 0..<missedDays { profile.streakFreezeUsedDates.append(now) }
                profile.currentStreak += 1  // streak survives, continues
            } else {
                profile.currentStreak = 1
            }
        } else {
            profile.currentStreak = 1
        }

        profile.longestStreak = max(profile.longestStreak, profile.currentStreak)
        // Award a freeze for every 7-day streak milestone.
        if profile.currentStreak > 0, profile.currentStreak % milestoneInterval == 0 {
            profile.streakFreezes = min(profile.streakFreezes + 1, freezeCap)
        }
        profile.lastOpenedDate = now

        // Append today to daily opens (deduplicated, trimmed to last 7 days). date(byAdding:)
        // can return nil at calendar-range extremes; skip the prune rather than crash.
        if let windowStart = cal.date(byAdding: .day, value: -(dailyOpensWindow - 1), to: today) {
            profile.dailyOpens.removeAll { cal.startOfDay(for: $0) < windowStart }
        }
        if !profile.dailyOpens.contains(where: { cal.isDate($0, inSameDayAs: today) }) {
            profile.dailyOpens.append(today)
        }
        return profile
    }
}
