import XCTest
@testable import Verbum

/// Pure streak/freeze math (StreakEngine.recordOpen) — the most consequential untested logic in
/// the app and the source of "it ate my streak after I travelled" reviews. No store / CloudKit /
/// DB boot needed: the engine is a pure function of (profile, calendar, now).
final class StreakEngineTests: XCTestCase {

    private func calendar(_ tz: String = "UTC") -> Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: tz)!
        return c
    }

    private func date(_ y: Int, _ m: Int, _ d: Int, h: Int = 12, tz: String = "UTC") -> Date {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: tz)!
        return cal.date(from: DateComponents(year: y, month: m, day: d, hour: h))!
    }

    func testFirstOpenStartsStreakAtOne() {
        let p = UserProfile()  // lastOpenedDate nil
        let r = StreakEngine.recordOpen(p, calendar: calendar(), now: date(2024, 1, 1))!
        XCTAssertEqual(r.currentStreak, 1)
        XCTAssertEqual(r.longestStreak, 1)
    }

    func testConsecutiveDayIncrementsStreak() {
        var p = UserProfile(); p.currentStreak = 3; p.lastOpenedDate = date(2024, 1, 1)
        let r = StreakEngine.recordOpen(p, calendar: calendar(), now: date(2024, 1, 2))!
        XCTAssertEqual(r.currentStreak, 4)
    }

    func testSameDayReturnsNil() {
        var p = UserProfile(); p.currentStreak = 4; p.lastOpenedDate = date(2024, 1, 1, h: 9)
        XCTAssertNil(StreakEngine.recordOpen(p, calendar: calendar(), now: date(2024, 1, 1, h: 23)))
    }

    func testGapOfTwoDaysWithoutFreezeResetsToOne() {
        var p = UserProfile(); p.currentStreak = 5; p.streakFreezes = 0; p.lastOpenedDate = date(2024, 1, 1)
        let r = StreakEngine.recordOpen(p, calendar: calendar(), now: date(2024, 1, 3))!
        XCTAssertEqual(r.currentStreak, 1)
    }

    func testGapFullyCoveredByFreezesSurvivesAndDecrementsFreezes() {
        // day1 → day4 = diff 3 ⇒ 2 missed days; 2 freezes exactly cover it.
        var p = UserProfile(); p.currentStreak = 5; p.streakFreezes = 2; p.lastOpenedDate = date(2024, 1, 1)
        let r = StreakEngine.recordOpen(p, calendar: calendar(), now: date(2024, 1, 4))!
        XCTAssertEqual(r.currentStreak, 6)
        XCTAssertEqual(r.streakFreezes, 0)
        XCTAssertEqual(r.streakFreezeUsedDates.count, 2)
    }

    func testPartialFreezeCoverageResetsAndDoesNotBurnFreezes() {
        // 2 missed days but only 1 freeze ⇒ reset, freeze untouched.
        var p = UserProfile(); p.currentStreak = 5; p.streakFreezes = 1; p.lastOpenedDate = date(2024, 1, 1)
        let r = StreakEngine.recordOpen(p, calendar: calendar(), now: date(2024, 1, 4))!
        XCTAssertEqual(r.currentStreak, 1)
        XCTAssertEqual(r.streakFreezes, 1)
        XCTAssertTrue(r.streakFreezeUsedDates.isEmpty)
    }

    func testSevenDayMilestoneAwardsOneFreeze() {
        var p = UserProfile(); p.currentStreak = 6; p.streakFreezes = 0; p.lastOpenedDate = date(2024, 1, 1)
        let r = StreakEngine.recordOpen(p, calendar: calendar(), now: date(2024, 1, 2))!
        XCTAssertEqual(r.currentStreak, 7)
        XCTAssertEqual(r.streakFreezes, 1)
    }

    func testMilestoneFreezeCappedAtThree() {
        var p = UserProfile(); p.currentStreak = 13; p.streakFreezes = 3; p.lastOpenedDate = date(2024, 1, 1)
        let r = StreakEngine.recordOpen(p, calendar: calendar(), now: date(2024, 1, 2))!
        XCTAssertEqual(r.currentStreak, 14)
        XCTAssertEqual(r.streakFreezes, 3)  // capped, not 4
    }

    func testLongestStreakTracksMaxAndSurvivesReset() {
        var grow = UserProfile(); grow.currentStreak = 9; grow.longestStreak = 9; grow.lastOpenedDate = date(2024, 1, 1)
        let r1 = StreakEngine.recordOpen(grow, calendar: calendar(), now: date(2024, 1, 2))!
        XCTAssertEqual(r1.currentStreak, 10)
        XCTAssertEqual(r1.longestStreak, 10)

        var lapse = UserProfile(); lapse.currentStreak = 10; lapse.longestStreak = 10; lapse.lastOpenedDate = date(2024, 1, 1)
        let r2 = StreakEngine.recordOpen(lapse, calendar: calendar(), now: date(2024, 1, 10))!
        XCTAssertEqual(r2.currentStreak, 1)
        XCTAssertEqual(r2.longestStreak, 10)  // a lapse never lowers the record
    }

    func testDSTSpringForwardCountsAsOneConsecutiveDay() {
        // 2024-03-10 is the US spring-forward (a 23-hour day). Noon→noon across it must be +1.
        let cal = calendar("America/New_York")
        var p = UserProfile(); p.currentStreak = 2
        p.lastOpenedDate = date(2024, 3, 9, h: 12, tz: "America/New_York")
        let r = StreakEngine.recordOpen(p, calendar: cal, now: date(2024, 3, 10, h: 12, tz: "America/New_York"))!
        XCTAssertEqual(r.currentStreak, 3)
    }

    func testLockedTimezoneKeepsTwoOpensOnSameLocalDayFromDoubleCounting() {
        // Locked TZ = Tokyo. Two opens on the SAME Tokyo day but DIFFERENT UTC days. A naive UTC
        // calendar would see two days and increment; the locked Tokyo calendar must return nil.
        let tokyo = calendar("Asia/Tokyo")
        var p = UserProfile(); p.currentStreak = 5
        p.lastOpenedDate = date(2024, 6, 2, h: 6, tz: "Asia/Tokyo")   // = 2024-06-01 21:00 UTC
        XCTAssertNil(StreakEngine.recordOpen(p, calendar: tokyo,
                                             now: date(2024, 6, 2, h: 10, tz: "Asia/Tokyo")))  // = 2024-06-02 01:00 UTC
        // …and the next Tokyo day still increments normally.
        let r = StreakEngine.recordOpen(p, calendar: tokyo, now: date(2024, 6, 3, h: 1, tz: "Asia/Tokyo"))!
        XCTAssertEqual(r.currentStreak, 6)
    }

    func testDailyOpensDedupedAndTrimmedToSevenDays() {
        var p = UserProfile()
        p.lastOpenedDate = date(2024, 1, 9)
        p.dailyOpens = [date(2024, 1, 1), date(2024, 1, 9)]   // Jan 1 is outside the 7-day window from Jan 10
        let cal = calendar()
        let r = StreakEngine.recordOpen(p, calendar: cal, now: date(2024, 1, 10))!
        XCTAssertFalse(r.dailyOpens.contains { cal.isDate($0, inSameDayAs: self.date(2024, 1, 1)) })
        XCTAssertEqual(r.dailyOpens.filter { cal.isDate($0, inSameDayAs: self.date(2024, 1, 10)) }.count, 1)
    }
}
