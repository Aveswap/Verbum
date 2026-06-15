import Foundation

/// Single source of truth for "the words to learn today".
///
/// Both the daily word **notifications** and the **widget** timeline draw from this, so they show
/// the *same* set of `count` words for the day (count = the number the user picks in Notification
/// settings). The selection is deterministic for a given calendar day, unseen-words-first, and
/// advances each day — so it's stable within the day (notification #i and widget slot #i match)
/// yet fresh tomorrow.
@MainActor
enum DailyWords {
    /// The `count` words to learn on the day containing `now`.
    /// - Pool: the free pool for free users, the whole active-language catalogue for Pro.
    /// - Order: unseen words first (so it keeps surfacing words still to learn), by frequency rank.
    /// - `isPro` defaults to the last verified value so callers without live subscription state
    ///   (e.g. the notification scheduler) still pick the right pool.
    static func forToday(count: Int,
                         seenIds: Set<UUID>,
                         calendar: Calendar,
                         isPro: Bool = SubscriptionManager.lastKnownPro,
                         now: Date = Date()) -> [Word] {
        let pool = isPro ? WordRepository.shared.all : WordAccess.freePool()
        guard count > 0, !pool.isEmpty else { return [] }

        let unseen = pool.filter { !seenIds.contains($0.id) }
        let base = unseen.isEmpty ? pool : unseen
        let seq = base.sorted { a, b in
            let ra = a.frequencyRank ?? .max, rb = b.frequencyRank ?? .max
            return ra != rb ? ra < rb : a.text.lowercased() < b.text.lowercased()
        }

        let n = min(count, seq.count)
        // Advance the window by `n` each day so today's set differs from yesterday's. Use a
        // continuous day number from the start-of-day epoch — NOT day-of-year, which resets on
        // Jan 1 and would jump/duplicate the set at the year boundary.
        let dayNumber = Int(calendar.startOfDay(for: now).timeIntervalSince1970 / 86_400)
        let start = ((dayNumber * n) % seq.count + seq.count) % seq.count
        return (0..<n).map { seq[(start + $0) % seq.count] }
    }
}
