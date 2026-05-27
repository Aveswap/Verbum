import CloudKit
import Foundation
import os

/// Syncs UserProfile to the user's private CloudKit database.
/// One CKRecord per user, keyed by the stable Apple User ID.
///
/// Merge rules:
///   - Sets (bookmarks, likes, seen, badges): union
///   - Counters (streak, points): take max
///   - Scalars (name, level, etc.): Last-Write-Wins via modificationDate
///
/// Requires: iCloud + CloudKit capability in Xcode target.
@MainActor
final class CloudKitSyncManager {

    private let logger = Logger(subsystem: "com.verbum.app", category: "CloudKit")
    private let container = CKContainer.default()
    private var db: CKDatabase { container.privateCloudDatabase }

    private static let recordType = "UserProfile"
    private static let zoneID = CKRecordZone.ID(zoneName: "VerbumZone", ownerName: CKCurrentUserDefaultName)

    // MARK: - Push

    func push(_ profile: UserProfile) async {
        guard let userID = profile.appleUserID else { return }
        do {
            try await ensureZoneExists()
            let recordID = CKRecord.ID(recordName: userID, zoneID: Self.zoneID)
            let record: CKRecord
            do {
                record = try await db.record(for: recordID)
            } catch {
                record = CKRecord(recordType: Self.recordType, recordID: recordID)
            }
            encode(profile, into: record)
            try await db.save(record)
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
            store.profile = merge(local: store.profile, remote: remote)
            store.saveNow()
        } catch let ckErr as CKError where ckErr.code == .unknownItem {
            await push(store.profile)
        } catch {
            logger.error("[CloudKit] pull failed: \(error, privacy: .public)")
        }
    }

    // MARK: - Zone

    private func ensureZoneExists() async throws {
        let zone = CKRecordZone(zoneID: Self.zoneID)
        _ = try await db.modifyRecordZones(saving: [zone], deleting: [])
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
        r["level"]                 = p.level.rawValue as CKRecordValue
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
        r["bookmarkedWordIds"]     = p.bookmarkedWordIds.map(\.uuidString) as CKRecordValue
        r["likedWordIds"]          = p.likedWordIds.map(\.uuidString) as CKRecordValue
        r["seenWordIds"]           = p.seenWordIds.map(\.uuidString) as CKRecordValue
        if let badgeData = try? JSONEncoder().encode(p.earnedBadges) {
            r["earnedBadges"] = badgeData as CKRecordValue
        }
    }

    private func decode(from r: CKRecord) -> UserProfile {
        var p = UserProfile()
        p.name                 = r["name"] as? String ?? ""
        p.age                  = (r["age"] as? String).flatMap(AgeRange.init)
        p.gender               = (r["gender"] as? String).flatMap(Gender.init)
        p.nativeLanguage       = (r["nativeLanguage"] as? String).flatMap(NativeLanguage.init)
        p.level                = (r["level"] as? String).flatMap(WordLevel.init) ?? .beginner
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
        p.bookmarkedWordIds    = (r["bookmarkedWordIds"] as? [String] ?? []).compactMap(UUID.init)
        p.likedWordIds         = (r["likedWordIds"] as? [String] ?? []).compactMap(UUID.init)
        p.seenWordIds          = (r["seenWordIds"] as? [String] ?? []).compactMap(UUID.init)
        if let data = r["earnedBadges"] as? Data,
           let badges = try? JSONDecoder().decode([EarnedBadge].self, from: data) {
            p.earnedBadges = badges
        }
        return p
    }

    // MARK: - Merge

    private func merge(local: UserProfile, remote: UserProfile) -> UserProfile {
        var merged = local

        // Scalar fields: pick the side whose profileUpdatedAt is newer (Last-Write-Wins by timestamp).
        // Old records without profileUpdatedAt default to .distantPast and lose to any newer write.
        let useRemoteScalars = remote.profileUpdatedAt > local.profileUpdatedAt
        if useRemoteScalars {
            if !remote.name.isEmpty         { merged.name = remote.name }
            if remote.age != nil            { merged.age = remote.age }
            if remote.gender != nil         { merged.gender = remote.gender }
            if remote.nativeLanguage != nil { merged.nativeLanguage = remote.nativeLanguage }
            merged.level                = remote.level
            merged.wordsPerWeek         = remote.wordsPerWeek
            merged.notificationsEnabled = remote.notificationsEnabled
            merged.notificationCount    = remote.notificationCount
            merged.notificationStart    = remote.notificationStart
            merged.notificationEnd      = remote.notificationEnd
            merged.selectedTheme        = remote.selectedTheme
        }
        merged.onboardingCompleted = local.onboardingCompleted || remote.onboardingCompleted
        merged.profileUpdatedAt    = max(local.profileUpdatedAt, remote.profileUpdatedAt)

        merged.currentStreak   = max(local.currentStreak, remote.currentStreak)
        merged.longestStreak   = max(local.longestStreak, remote.longestStreak)
        merged.totalPoints     = max(local.totalPoints, remote.totalPoints)
        merged.quarterlyPoints = max(local.quarterlyPoints, remote.quarterlyPoints)

        if let rl = remote.lastOpenedDate, let ll = local.lastOpenedDate {
            merged.lastOpenedDate = max(rl, ll)
        } else {
            merged.lastOpenedDate = remote.lastOpenedDate ?? local.lastOpenedDate
        }

        merged.bookmarkedWordIds = Array(Set(local.bookmarkedWordIds).union(remote.bookmarkedWordIds))
        merged.likedWordIds      = Array(Set(local.likedWordIds).union(remote.likedWordIds))
        merged.seenWordIds       = Array(Set(local.seenWordIds).union(remote.seenWordIds))

        var seenKeys = Set<String>()
        merged.earnedBadges = (local.earnedBadges + remote.earnedBadges).filter { b in
            seenKeys.insert("\(b.tier.rawValue)-\(b.period)").inserted
        }

        return merged
    }
}
