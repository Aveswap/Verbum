import XCTest
@testable import Verbum

/// The CloudKit LWW/union merge rules (CloudKitSyncManager.merge) — pure, static, so testable
/// without a CloudKit container. Covers the data-loss regressions called out in the audit.
@MainActor
final class CloudKitMergeTests: XCTestCase {

    private func merge(_ a: UserProfile, _ b: UserProfile) -> UserProfile {
        CloudKitSyncManager.merge(local: a, remote: b)
    }

    func testScalarsFollowSettingsRecency() {
        var local = UserProfile()
        local.dailyGoal = 5
        local.settingsUpdatedAt = Date(timeIntervalSince1970: 100)
        var remote = UserProfile()
        remote.dailyGoal = 20
        remote.settingsUpdatedAt = Date(timeIntervalSince1970: 200) // newer settings

        XCTAssertEqual(merge(local, remote).dailyGoal, 20)
        // …and the reverse: older remote settings must not clobber local.
        remote.settingsUpdatedAt = Date(timeIntervalSince1970: 50)
        XCTAssertEqual(merge(local, remote).dailyGoal, 5)
    }

    func testMonotonicCountersTakeMax() {
        // totalPoints / longestStreak are records → max. currentStreak is NOT (it resets on a
        // lapse) → it follows the side that opened most recently, not max.
        var local = UserProfile();  local.totalPoints = 100; local.longestStreak = 9
        var remote = UserProfile(); remote.totalPoints = 40;  remote.longestStreak = 5
        let m = merge(local, remote)
        XCTAssertEqual(m.totalPoints, 100)
        XCTAssertEqual(m.longestStreak, 9)
    }

    func testCurrentStreakFollowsLatestOpen() {
        // The device that opened more recently owns the live streak — even if its number is lower
        // (a lapse). max() would wrongly revive the broken streak.
        var local = UserProfile();  local.currentStreak = 7; local.lastOpenedDate = Date(timeIntervalSince1970: 1_000)
        var remote = UserProfile(); remote.currentStreak = 1; remote.lastOpenedDate = Date(timeIntervalSince1970: 2_000)
        XCTAssertEqual(merge(local, remote).currentStreak, 1)   // remote opened later → its streak
        XCTAssertEqual(merge(remote, local).currentStreak, 1)   // order-independent
    }

    func testToggleUnlikeSticksWithTimestamp() {
        // local un-liked `a` AFTER remote liked it → the un-like wins (no resurrection).
        let a = UUID()
        var local = UserProfile();  local.likedWordIds = [];  local.likeChangedAt = [a.uuidString: Date(timeIntervalSince1970: 2_000)]
        var remote = UserProfile(); remote.likedWordIds = [a]; remote.likeChangedAt = [a.uuidString: Date(timeIntervalSince1970: 1_000)]
        XCTAssertFalse(merge(local, remote).likedWordIds.contains(a))
    }

    func testSeenAndLikedAreUnioned() {
        let a = UUID(), b = UUID(), c = UUID()
        var local = UserProfile();  local.seenWordIds = [a, b]; local.likedWordIds = [a]
        var remote = UserProfile(); remote.seenWordIds = [b, c]; remote.likedWordIds = [c]
        let m = merge(local, remote)
        XCTAssertEqual(Set(m.seenWordIds), [a, b, c])
        XCTAssertEqual(Set(m.likedWordIds), [a, c])
    }

    func testStreakFreezesFollowMostRecentProfileNotMax() {
        // The device that acted most recently owns the true balance — max() would "refund"
        // a freeze the other device already spent.
        var local = UserProfile()
        local.streakFreezes = 1
        local.profileUpdatedAt = Date(timeIntervalSince1970: 500) // most recent
        var remote = UserProfile()
        remote.streakFreezes = 3
        remote.profileUpdatedAt = Date(timeIntervalSince1970: 100)
        XCTAssertEqual(merge(local, remote).streakFreezes, 1)
    }

    func testStreakFreezesClampedToCap() {
        var local = UserProfile();  local.streakFreezes = 9; local.profileUpdatedAt = Date(timeIntervalSince1970: 500)
        var remote = UserProfile(); remote.streakFreezes = 0; remote.profileUpdatedAt = Date(timeIntervalSince1970: 100)
        XCTAssertEqual(merge(local, remote).streakFreezes, 3)
    }

    func testReviewsKeepMostRecentlyReviewed() {
        let key = UUID().uuidString
        var newer = WordReview.newCard(); newer.reps = 9; newer.lastReview = Date(timeIntervalSince1970: 300)
        var older = WordReview.newCard(); older.reps = 1; older.lastReview = Date(timeIntervalSince1970: 100)
        var local = UserProfile();  local.reviews = [key: older]
        var remote = UserProfile(); remote.reviews = [key: newer]
        XCTAssertEqual(merge(local, remote).reviews[key]?.reps, 9)
    }

    func testOnboardingCompletedRespectsSettingsRecency() {
        // resetOnboarding() must stick across a sync (the old `local || remote` OR rule un-reset it).
        var local = UserProfile();  local.onboardingCompleted = false; local.settingsUpdatedAt = Date(timeIntervalSince1970: 200)
        var remote = UserProfile(); remote.onboardingCompleted = true;  remote.settingsUpdatedAt = Date(timeIntervalSince1970: 100)
        XCTAssertFalse(merge(local, remote).onboardingCompleted)
    }
}
