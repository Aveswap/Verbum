import Foundation
import os

// ⚠️ LOCAL-DEV STUB — CloudKit calls disabled for Personal Team builds (no paid Developer Program).
// Original full implementation preserved at: _LocalDev-Disabled/CloudKitSyncManager.swift.original
// Restore before release: replace this file with the original and re-enable iCloud capability.
// The static `merge(...)` logic is preserved verbatim below so CloudKitMergeTests keeps passing.

@MainActor
final class CloudKitSyncManager {

    private let logger = Logger(subsystem: "com.verbum.app", category: "CloudKit")

    // MARK: - Stubbed sync API (no-ops in local dev)

    func push(_ profile: UserProfile) async {
        logger.debug("[CloudKit] push() stubbed — local-dev build")
    }

    func pull(into store: UserProfileStore) async {
        logger.debug("[CloudKit] pull() stubbed — local-dev build")
        // No remote merge to wait for: unblock the deferred daily-open immediately so
        // the streak still updates on app open.
        store.markInitialPullComplete()
        store.runPendingDailyOpen()
    }

    func deleteZone() async throws {
        logger.debug("[CloudKit] deleteZone() stubbed — local-dev build")
    }

    // MARK: - Merge (kept intact — pure logic, unit-tested)

    static func merge(local: UserProfile, remote: UserProfile) -> UserProfile {
        var merged = local

        let useRemoteScalars = remote.settingsUpdatedAt > local.settingsUpdatedAt
        if useRemoteScalars {
            if !remote.name.isEmpty         { merged.name = remote.name }
            if remote.age != nil            { merged.age = remote.age }
            if remote.gender != nil         { merged.gender = remote.gender }
            if remote.nativeLanguage != nil { merged.nativeLanguage = remote.nativeLanguage }
            merged.wordsPerWeek         = remote.wordsPerWeek
            merged.notificationsEnabled = remote.notificationsEnabled
            merged.notificationCount    = remote.notificationCount
            merged.notificationStart    = remote.notificationStart
            merged.notificationEnd      = remote.notificationEnd
            merged.selectedTheme        = remote.selectedTheme
            merged.dailyGoal            = remote.dailyGoal
            merged.onboardingCompleted  = remote.onboardingCompleted
        }
        merged.profileUpdatedAt  = max(local.profileUpdatedAt, remote.profileUpdatedAt)
        merged.settingsUpdatedAt = max(local.settingsUpdatedAt, remote.settingsUpdatedAt)

        merged.longestStreak   = max(local.longestStreak, remote.longestStreak)
        switch (local.lastOpenedDate, remote.lastOpenedDate) {
        case let (l?, r?): merged.currentStreak = (r > l) ? remote.currentStreak : local.currentStreak
        case (nil, _?):    merged.currentStreak = remote.currentStreak
        default:           merged.currentStreak = local.currentStreak
        }
        merged.totalPoints     = max(local.totalPoints, remote.totalPoints)
        merged.quarterlyPoints = max(local.quarterlyPoints, remote.quarterlyPoints)
        merged.streakFreezes = min(3, (remote.profileUpdatedAt > local.profileUpdatedAt)
            ? remote.streakFreezes : local.streakFreezes)
        merged.streakTimezone  = local.streakTimezone ?? remote.streakTimezone
        merged.quarterlyResetDate = max(local.quarterlyResetDate, remote.quarterlyResetDate)

        if let rl = remote.lastOpenedDate, let ll = local.lastOpenedDate {
            merged.lastOpenedDate = max(rl, ll)
        } else {
            merged.lastOpenedDate = remote.lastOpenedDate ?? local.lastOpenedDate
        }

        // Day-boundary calendar locked to the streak timezone (not Calendar.current) so the
        // daily-counter and dailyOpens windows agree across devices in different timezones —
        // matching UserProfileStore.dayCalendar used everywhere else.
        var dayCal = Calendar(identifier: .gregorian)
        dayCal.timeZone = TimeZone(identifier: merged.streakTimezone ?? "") ?? .current

        (merged.wordsLearnedToday, merged.wordsLearnedDate) = Self.mergeDailyCounter(
            (local.wordsLearnedToday, local.wordsLearnedDate),
            (remote.wordsLearnedToday, remote.wordsLearnedDate), calendar: dayCal)
        (merged.practiceGamesPlayedToday, merged.practiceGamesDate) = Self.mergeDailyCounter(
            (local.practiceGamesPlayedToday, local.practiceGamesDate),
            (remote.practiceGamesPlayedToday, remote.practiceGamesDate), calendar: dayCal)

        (merged.likedWordIds, merged.likeChangedAt) = Self.mergeToggleSet(
            localIds: local.likedWordIds, localTs: local.likeChangedAt,
            remoteIds: remote.likedWordIds, remoteTs: remote.likeChangedAt)
        (merged.bookmarkedWordIds, merged.bookmarkChangedAt) = Self.mergeToggleSet(
            localIds: local.bookmarkedWordIds, localTs: local.bookmarkChangedAt,
            remoteIds: remote.bookmarkedWordIds, remoteTs: remote.bookmarkChangedAt)
        merged.seenWordIds       = Array(Set(local.seenWordIds).union(remote.seenWordIds))
        merged.streakFreezeUsedDates = Array(Set(local.streakFreezeUsedDates).union(remote.streakFreezeUsedDates))
        let unionOpens = Set(local.dailyOpens).union(remote.dailyOpens)
        if let newest = unionOpens.max() {
            let cutoff = dayCal.date(byAdding: .day, value: -6, to: dayCal.startOfDay(for: newest)) ?? .distantPast
            merged.dailyOpens = unionOpens.filter { $0 >= cutoff }.sorted()
        } else {
            merged.dailyOpens = []
        }

        var seenKeys = Set<String>()
        merged.earnedBadges = (local.earnedBadges + remote.earnedBadges).filter { b in
            seenKeys.insert("\(b.tier.rawValue)-\(b.period)").inserted
        }

        var mergedReviews = local.reviews
        for (key, rv) in remote.reviews {
            if let cur = mergedReviews[key] {
                if (rv.lastReview ?? .distantPast) > (cur.lastReview ?? .distantPast) { mergedReviews[key] = rv }
            } else {
                mergedReviews[key] = rv
            }
        }
        merged.reviews = mergedReviews

        merged.wordMastery = Self.mergeMaxByKey(local.wordMastery, remote.wordMastery)
        merged.challengeHighScores = Self.mergeMaxByKey(local.challengeHighScores, remote.challengeHighScores)

        (merged.wordNotes, merged.noteChangedAt) = Self.mergeNotesByRecency(
            localVals: local.wordNotes, localTs: local.noteChangedAt,
            remoteVals: remote.wordNotes, remoteTs: remote.noteChangedAt)

        // Trial anchor: take the earliest real first-launch so the 7-day games trial can't be
        // reset by reinstalling on a new device.
        merged.firstLaunchDate = [local.firstLaunchDate, remote.firstLaunchDate].compactMap { $0 }.min()

        let deletedIds = Set(local.deletedDeckIds).union(remote.deletedDeckIds)
        merged.deletedDeckIds = Array(deletedIds)

        var decksById: [UUID: WordDeck] = [:]
        for d in local.decks where !deletedIds.contains(d.id) { decksById[d.id] = d }
        for d in remote.decks where !deletedIds.contains(d.id) {
            if let existing = decksById[d.id] {
                if d.wordIds.count > existing.wordIds.count { decksById[d.id] = d }
            } else {
                decksById[d.id] = d
            }
        }
        merged.decks = decksById.values.sorted { $0.createdAt < $1.createdAt }

        return merged
    }

    private static func mergeDailyCounter(_ a: (Int, Date), _ b: (Int, Date), calendar cal: Calendar) -> (Int, Date) {
        if cal.isDate(a.1, inSameDayAs: b.1) {
            return (max(a.0, b.0), max(a.1, b.1))
        }
        return a.1 > b.1 ? a : b
    }

    private static func mergeToggleSet(
        localIds: [UUID], localTs: [String: Date],
        remoteIds: [UUID], remoteTs: [String: Date]
    ) -> ([UUID], [String: Date]) {
        let localSet = Set(localIds), remoteSet = Set(remoteIds)
        var mergedTs = localTs
        for (k, v) in remoteTs { mergedTs[k] = max(mergedTs[k] ?? .distantPast, v) }

        var result = Set<UUID>()
        for id in localSet.union(remoteSet) {
            let key = id.uuidString
            let lt = localTs[key], rt = remoteTs[key]
            if lt == nil && rt == nil {
                result.insert(id)
            } else if (rt ?? .distantPast) > (lt ?? .distantPast) {
                if remoteSet.contains(id) { result.insert(id) }
            } else if localSet.contains(id) {
                result.insert(id)
            }
        }
        return (Array(result), mergedTs)
    }

    private static func mergeMaxByKey(_ a: [String: Int], _ b: [String: Int]) -> [String: Int] {
        var out = a
        for (k, v) in b { out[k] = max(out[k] ?? Int.min, v) }
        return out
    }

    /// Per-key last-write-wins merge for the lexicon notes. The newest `noteChangedAt` wins the
    /// value; a cleared note (empty string) with a newer timestamp correctly removes it. Timestamps
    /// are unioned with max so a later edit always supersedes an earlier one.
    private static func mergeNotesByRecency(
        localVals: [String: String], localTs: [String: Date],
        remoteVals: [String: String], remoteTs: [String: Date]
    ) -> ([String: String], [String: Date]) {
        var ts = localTs
        for (k, v) in remoteTs { ts[k] = max(ts[k] ?? .distantPast, v) }
        var vals = localVals
        for k in Set(localVals.keys).union(remoteVals.keys) {
            let lt = localTs[k] ?? .distantPast
            let rt = remoteTs[k] ?? .distantPast
            if rt > lt { vals[k] = remoteVals[k] }
        }
        return (vals.filter { !$0.value.isEmpty }, ts)   // drop cleared notes
    }
}
