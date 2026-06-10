import CloudKit
import Foundation
import os

/// Syncs UserProfile to the user's private CloudKit database.
/// One CKRecord per user, keyed by the stable Apple User ID.
///
/// Merge rules:
///   - Sets (bookmarks, likes, seen, badges, freeze-used dates, daily opens): union
///   - Counters (streak, points, freezes): take max
///   - User-editable scalars (name, level, dailyGoal, onboarding, …): Last-Write-Wins
///     keyed on `settingsUpdatedAt` (settings recency), not "anything changed"
///   - Daily counters (words/practice today): later date wins, same day takes max
///   - FSRS reviews: keep the entry with the latest `lastReview`
///   - Mastery / challenge high scores: max per key
///   - Decks: union by id (fuller deck wins an id collision)
///
/// Requires: iCloud + CloudKit capability in Xcode target.
@MainActor
final class CloudKitSyncManager {

    private let logger = Logger(subsystem: "com.verbum.app", category: "CloudKit")
    private let container = CKContainer.default()
    private var db: CKDatabase { container.privateCloudDatabase }

    private static let recordType = "UserProfile"
    private static let zoneID = CKRecordZone.ID(zoneName: "VerbumZone", ownerName: CKCurrentUserDefaultName)

    private var zoneCreated = false

    // MARK: - Push

    /// Pushes the profile by MERGING into the existing server record (never a blind overwrite),
    /// so two simultaneously-active devices can't clobber each other. Retries once on
    /// `serverRecordChanged` (a write landed between our fetch and save).
    func push(_ profile: UserProfile) async {
        guard let userID = profile.appleUserID else { return }
        do {
            try await ensureZoneExists()
            let recordID = CKRecord.ID(recordName: userID, zoneID: Self.zoneID)
            let record: CKRecord
            var base = profile
            if let existing = try? await db.record(for: recordID) {
                record = existing
                base = Self.merge(local: profile, remote: decode(from: existing))
            } else {
                record = CKRecord(recordType: Self.recordType, recordID: recordID)
            }
            encode(base, into: record)
            do {
                try await db.save(record)
            } catch let e as CKError where e.code == .serverRecordChanged {
                // Someone wrote between our fetch and save — re-fetch, re-merge, retry once.
                let fresh = try await db.record(for: recordID)
                let remerged = Self.merge(local: base, remote: decode(from: fresh))
                encode(remerged, into: fresh)
                try await db.save(fresh)
            }
        } catch {
            logger.error("[CloudKit] push failed: \(error, privacy: .public)")
        }
    }

    // MARK: - Pull & Merge

    func pull(into store: UserProfileStore) async {
        guard let userID = store.profile.appleUserID else { return }
        do {
            try await ensureZoneExists()
            let recordID = CKRecord.ID(recordName: userID, zoneID: Self.zoneID)
            let record = try await db.record(for: recordID)
            let remote = decode(from: record)
            store.applyMerged(Self.merge(local: store.profile, remote: remote))
            store.markInitialPullComplete()   // allow pushes now that the server state is merged in
            store.saveNow()
        } catch let ckErr as CKError where ckErr.code == .unknownItem {
            // No server record yet — this device's profile becomes the seed. Allow the push.
            store.markInitialPullComplete()
            await push(store.profile)
        } catch {
            logger.error("[CloudKit] pull failed: \(error, privacy: .public)")
        }
    }

    // MARK: - Zone

    private func ensureZoneExists() async throws {
        guard !zoneCreated else { return }
        let zone = CKRecordZone(zoneID: Self.zoneID)
        _ = try await db.modifyRecordZones(saving: [zone], deleting: [])
        zoneCreated = true
    }

    // MARK: - Delete zone (called on account deletion)

    func deleteZone() async {
        do {
            _ = try await db.modifyRecordZones(saving: [], deleting: [Self.zoneID])
        } catch {
            logger.error("[CloudKit] zone deletion failed: \(error, privacy: .public)")
        }
    }

    // MARK: - Encode / Decode

    private func encode(_ p: UserProfile, into r: CKRecord) {
        r["name"]                  = p.name as CKRecordValue
        r["age"]                   = p.age?.rawValue as? CKRecordValue
        r["gender"]                = p.gender?.rawValue as? CKRecordValue
        r["nativeLanguage"]        = p.nativeLanguage?.rawValue as? CKRecordValue
        r["wordsPerWeek"]          = p.wordsPerWeek as CKRecordValue
        r["notificationsEnabled"]  = (p.notificationsEnabled ? 1 : 0) as CKRecordValue
        r["notificationCount"]     = p.notificationCount as CKRecordValue
        r["notificationStart"]     = p.notificationStart as CKRecordValue
        r["notificationEnd"]       = p.notificationEnd as CKRecordValue
        r["selectedTheme"]         = p.selectedTheme.rawValue as CKRecordValue
        r["onboardingCompleted"]   = (p.onboardingCompleted ? 1 : 0) as CKRecordValue
        r["currentStreak"]         = p.currentStreak as CKRecordValue
        r["longestStreak"]         = p.longestStreak as CKRecordValue
        r["totalPoints"]           = p.totalPoints as CKRecordValue
        r["quarterlyPoints"]       = p.quarterlyPoints as CKRecordValue
        r["lastOpenedDate"]        = p.lastOpenedDate as? CKRecordValue
        r["quarterlyResetDate"]    = p.quarterlyResetDate as CKRecordValue
        r["profileUpdatedAt"]      = p.profileUpdatedAt as CKRecordValue
        r["settingsUpdatedAt"]     = p.settingsUpdatedAt as CKRecordValue
        r["streakFreezes"]         = p.streakFreezes as CKRecordValue
        r["streakTimezone"]        = p.streakTimezone as? CKRecordValue
        r["dailyGoal"]             = p.dailyGoal as CKRecordValue
        r["wordsLearnedToday"]     = p.wordsLearnedToday as CKRecordValue
        r["wordsLearnedDate"]      = p.wordsLearnedDate as CKRecordValue
        r["practiceGamesPlayedToday"] = p.practiceGamesPlayedToday as CKRecordValue
        r["practiceGamesDate"]     = p.practiceGamesDate as CKRecordValue
        r["bookmarkedWordIds"]     = p.bookmarkedWordIds.map(\.uuidString) as CKRecordValue
        r["likedWordIds"]          = p.likedWordIds.map(\.uuidString) as CKRecordValue
        r["seenWordIds"]           = p.seenWordIds.map(\.uuidString) as CKRecordValue
        // Heavy / high-value collections as JSON blobs. These are the highest-value user
        // data in a spaced-repetition app — losing them on reinstall is a real complaint.
        r["earnedBadges"]          = jsonBlob(p.earnedBadges)
        r["reviews"]               = jsonBlob(p.reviews)
        r["decks"]                 = jsonBlob(p.decks)
        r["wordMastery"]           = jsonBlob(p.wordMastery)
        r["challengeHighScores"]   = jsonBlob(p.challengeHighScores)
        r["streakFreezeUsedDates"] = jsonBlob(p.streakFreezeUsedDates)
        r["dailyOpens"]            = jsonBlob(p.dailyOpens)
    }

    private func jsonBlob<T: Encodable>(_ value: T) -> CKRecordValue? {
        (try? JSONEncoder().encode(value)) as CKRecordValue?
    }

    private func decodeBlob<T: Decodable>(_ value: CKRecordValue?, as type: T.Type, default fallback: T) -> T {
        guard let data = value as? Data,
              let decoded = try? JSONDecoder().decode(T.self, from: data) else { return fallback }
        return decoded
    }

    private func decode(from r: CKRecord) -> UserProfile {
        var p = UserProfile()
        p.name                 = r["name"] as? String ?? ""
        p.age                  = (r["age"] as? String).flatMap(AgeRange.init)
        p.gender               = (r["gender"] as? String).flatMap(Gender.init)
        p.nativeLanguage       = (r["nativeLanguage"] as? String).flatMap(NativeLanguage.init)
        p.wordsPerWeek         = r["wordsPerWeek"] as? Int ?? 30
        p.notificationsEnabled = (r["notificationsEnabled"] as? Int ?? 0) == 1
        p.notificationCount    = r["notificationCount"] as? Int ?? 3
        p.notificationStart    = r["notificationStart"] as? String ?? "09:00"
        p.notificationEnd      = r["notificationEnd"] as? String ?? "22:00"
        p.selectedTheme        = (r["selectedTheme"] as? String).flatMap(AppTheme.init) ?? .dark
        p.onboardingCompleted  = (r["onboardingCompleted"] as? Int ?? 0) == 1
        p.currentStreak        = r["currentStreak"] as? Int ?? 0
        p.longestStreak        = r["longestStreak"] as? Int ?? 0
        p.totalPoints          = r["totalPoints"] as? Int ?? 0
        p.quarterlyPoints      = r["quarterlyPoints"] as? Int ?? 0
        p.lastOpenedDate       = r["lastOpenedDate"] as? Date
        p.quarterlyResetDate   = r["quarterlyResetDate"] as? Date ?? Date()
        p.profileUpdatedAt     = r["profileUpdatedAt"] as? Date ?? .distantPast
        p.settingsUpdatedAt    = r["settingsUpdatedAt"] as? Date ?? (r["profileUpdatedAt"] as? Date ?? .distantPast)
        p.streakFreezes        = r["streakFreezes"] as? Int ?? 0
        p.streakTimezone       = r["streakTimezone"] as? String
        p.dailyGoal            = r["dailyGoal"] as? Int ?? 5
        p.wordsLearnedToday    = r["wordsLearnedToday"] as? Int ?? 0
        p.wordsLearnedDate     = r["wordsLearnedDate"] as? Date ?? .distantPast
        p.practiceGamesPlayedToday = r["practiceGamesPlayedToday"] as? Int ?? 0
        p.practiceGamesDate    = r["practiceGamesDate"] as? Date ?? .distantPast
        p.bookmarkedWordIds    = (r["bookmarkedWordIds"] as? [String] ?? []).compactMap(UUID.init)
        p.likedWordIds         = (r["likedWordIds"] as? [String] ?? []).compactMap(UUID.init)
        p.seenWordIds          = (r["seenWordIds"] as? [String] ?? []).compactMap(UUID.init)
        p.earnedBadges         = decodeBlob(r["earnedBadges"], as: [EarnedBadge].self, default: [])
        p.reviews              = decodeBlob(r["reviews"], as: [String: WordReview].self, default: [:])
        p.decks                = decodeBlob(r["decks"], as: [WordDeck].self, default: [])
        p.wordMastery          = decodeBlob(r["wordMastery"], as: [String: Int].self, default: [:])
        p.challengeHighScores  = decodeBlob(r["challengeHighScores"], as: [String: Int].self, default: [:])
        p.streakFreezeUsedDates = decodeBlob(r["streakFreezeUsedDates"], as: [Date].self, default: [])
        p.dailyOpens           = decodeBlob(r["dailyOpens"], as: [Date].self, default: [])
        return p
    }

    // MARK: - Merge

    // Static + internal so the (pure) LWW merge rules can be unit-tested directly without
    // instantiating the CloudKit container.
    static func merge(local: UserProfile, remote: UserProfile) -> UserProfile {
        var merged = local

        // User-editable scalar fields: pick the side whose settingsUpdatedAt is newer
        // (Last-Write-Wins, but keyed on *settings* recency, not "anything changed"). This
        // stops a device that merely swipes words from clobbering another device's genuine
        // settings edit. onboardingCompleted is included so resetOnboarding() actually sticks
        // across a sync instead of being un-reset by the old `local || remote` OR rule.
        // Old records without settingsUpdatedAt fall back to profileUpdatedAt in decode().
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

        // Counters: take max (monotonic, never regress).
        merged.currentStreak   = max(local.currentStreak, remote.currentStreak)
        merged.longestStreak   = max(local.longestStreak, remote.longestStreak)
        merged.totalPoints     = max(local.totalPoints, remote.totalPoints)
        merged.quarterlyPoints = max(local.quarterlyPoints, remote.quarterlyPoints)
        // Consumable balance: take the side that acted most recently as authoritative, rather
        // than max(). Freezes only change inside recordDailyOpen (which bumps profileUpdatedAt),
        // so the newer profile has the true balance — max() would "refund" a freeze that the
        // other device already spent. Clamp to the earn cap (3) defensively.
        merged.streakFreezes = min(3, (remote.profileUpdatedAt > local.profileUpdatedAt)
            ? remote.streakFreezes : local.streakFreezes)
        // Locked-once timezone: keep whichever side set it (prefer local).
        merged.streakTimezone  = local.streakTimezone ?? remote.streakTimezone
        merged.quarterlyResetDate = max(local.quarterlyResetDate, remote.quarterlyResetDate)

        if let rl = remote.lastOpenedDate, let ll = local.lastOpenedDate {
            merged.lastOpenedDate = max(rl, ll)
        } else {
            merged.lastOpenedDate = remote.lastOpenedDate ?? local.lastOpenedDate
        }

        // Daily counters: the side with the later date is authoritative; same day takes max.
        (merged.wordsLearnedToday, merged.wordsLearnedDate) = Self.mergeDailyCounter(
            (local.wordsLearnedToday, local.wordsLearnedDate),
            (remote.wordsLearnedToday, remote.wordsLearnedDate))
        (merged.practiceGamesPlayedToday, merged.practiceGamesDate) = Self.mergeDailyCounter(
            (local.practiceGamesPlayedToday, local.practiceGamesDate),
            (remote.practiceGamesPlayedToday, remote.practiceGamesDate))

        // Sets: union.
        merged.bookmarkedWordIds = Array(Set(local.bookmarkedWordIds).union(remote.bookmarkedWordIds))
        merged.likedWordIds      = Array(Set(local.likedWordIds).union(remote.likedWordIds))
        merged.seenWordIds       = Array(Set(local.seenWordIds).union(remote.seenWordIds))
        merged.streakFreezeUsedDates = Array(Set(local.streakFreezeUsedDates).union(remote.streakFreezeUsedDates))
        merged.dailyOpens        = Array(Set(local.dailyOpens).union(remote.dailyOpens)).sorted()

        var seenKeys = Set<String>()
        merged.earnedBadges = (local.earnedBadges + remote.earnedBadges).filter { b in
            seenKeys.insert("\(b.tier.rawValue)-\(b.period)").inserted
        }

        // FSRS reviews: keep the entry reviewed most recently (highest-value data).
        var mergedReviews = local.reviews
        for (key, rv) in remote.reviews {
            if let cur = mergedReviews[key] {
                if (rv.lastReview ?? .distantPast) > (cur.lastReview ?? .distantPast) { mergedReviews[key] = rv }
            } else {
                mergedReviews[key] = rv
            }
        }
        merged.reviews = mergedReviews

        // Mastery / high scores: max per key (never regress a hard-won value across devices).
        merged.wordMastery = Self.mergeMaxByKey(local.wordMastery, remote.wordMastery)
        merged.challengeHighScores = Self.mergeMaxByKey(local.challengeHighScores, remote.challengeHighScores)

        // Decks: union by id; on the rare id collision keep the fuller deck (minimize loss).
        var decksById: [UUID: WordDeck] = [:]
        for d in local.decks { decksById[d.id] = d }
        for d in remote.decks {
            if let existing = decksById[d.id] {
                if d.wordIds.count > existing.wordIds.count { decksById[d.id] = d }
            } else {
                decksById[d.id] = d
            }
        }
        merged.decks = decksById.values.sorted { $0.createdAt < $1.createdAt }

        return merged
    }

    /// Merge a "resets at local midnight" counter: later date wins; same calendar day takes max.
    private static func mergeDailyCounter(_ a: (Int, Date), _ b: (Int, Date)) -> (Int, Date) {
        if Calendar.current.isDate(a.1, inSameDayAs: b.1) {
            return (max(a.0, b.0), max(a.1, b.1))
        }
        return a.1 > b.1 ? a : b
    }

    private static func mergeMaxByKey(_ a: [String: Int], _ b: [String: Int]) -> [String: Int] {
        var out = a
        for (k, v) in b { out[k] = max(out[k] ?? Int.min, v) }
        return out
    }
}
