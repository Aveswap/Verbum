import XCTest
@testable import Verbum

/// DailyWords.forToday feeds both the daily notifications and (formerly) the widget, so the same
/// `count` words must be chosen for a given day, advance each day, and not glitch at the year
/// boundary. Driven through the free pool via `WordAccess.catalogProvider` — no DB/repo boot.
@MainActor
final class DailyWordsTests: XCTestCase {

    private func word(_ text: String, rank: Int) -> Word {
        Word(id: UUID(), text: text, phonetic: "", partOfSpeech: "noun",
             definition: "def of \(text)", exampleSentence: nil, synonyms: [],
             category: "General", isNew: true, etymology: nil, frequencyRank: rank)
    }

    /// 60 non-premium words ⇒ free pool of `freeLimit` (50), rank-ordered.
    private func makeCatalogue() -> [Word] {
        (1...60).map { word("w\($0)", rank: $0) }
    }

    private let cal: Calendar = {
        var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(identifier: "UTC")!; return c
    }()

    private func date(_ y: Int, _ m: Int, _ d: Int, h: Int = 12) -> Date {
        var c = cal; return c.date(from: DateComponents(year: y, month: m, day: d, hour: h))!
    }

    override func setUp() {
        super.setUp()
        WordAccess.catalogProvider = { [self] in makeCatalogue() }
        WordAccess.invalidate()
    }

    override func tearDown() {
        WordAccess.catalogProvider = { WordRepository.shared.all }
        WordAccess.invalidate()
        super.tearDown()
    }

    private func ids(_ words: [Word]) -> [UUID] { words.map(\.id) }

    func testSameDayReturnsSameSet() {
        // notification slot #i and (former) widget slot #i must agree → identical, in order.
        let morning = DailyWords.forToday(count: 5, seenIds: [], calendar: cal, isPro: false, now: date(2024, 6, 1, h: 8))
        let evening = DailyWords.forToday(count: 5, seenIds: [], calendar: cal, isPro: false, now: date(2024, 6, 1, h: 21))
        XCTAssertEqual(ids(morning), ids(evening))
        XCTAssertEqual(morning.count, 5)
    }

    func testSetAdvancesEachDay() {
        let d1 = DailyWords.forToday(count: 4, seenIds: [], calendar: cal, isPro: false, now: date(2024, 6, 1))
        let d2 = DailyWords.forToday(count: 4, seenIds: [], calendar: cal, isPro: false, now: date(2024, 6, 2))
        XCTAssertNotEqual(Set(ids(d1)), Set(ids(d2)))
    }

    func testYearBoundaryAdvancesContinuouslyNoResetOrDuplicate() {
        // Reproduces the epoch-day formula and pins it across 2024-12-31 → 2025-01-01. A buggy
        // day-of-year implementation would reset the window on Jan 1; the continuous day number
        // must instead advance by `n`, exactly like any other day boundary.
        let seq = WordAccess.freePool()  // all-unseen base order == rank-sorted free pool
        let n = 4
        func expectedStart(_ now: Date) -> Int {
            let dayNumber = Int(cal.startOfDay(for: now).timeIntervalSince1970 / 86_400)
            return ((dayNumber * n) % seq.count + seq.count) % seq.count
        }
        let dec31 = date(2024, 12, 31)
        let jan01 = date(2025, 1, 1)

        let got31 = DailyWords.forToday(count: n, seenIds: [], calendar: cal, isPro: false, now: dec31)
        let got01 = DailyWords.forToday(count: n, seenIds: [], calendar: cal, isPro: false, now: jan01)

        XCTAssertEqual(got31.first?.id, seq[expectedStart(dec31)].id)
        XCTAssertEqual(got01.first?.id, seq[expectedStart(jan01)].id)
        // The window genuinely moved across the boundary (no reset to a day-of-year window).
        XCTAssertNotEqual(Set(ids(got31)), Set(ids(got01)))
        XCTAssertEqual((expectedStart(dec31) + n) % seq.count, expectedStart(jan01))
    }

    func testUnseenWordsLeadTheRotation() {
        let pool = WordAccess.freePool()
        let unseen = Set(pool.suffix(5).map(\.id))         // leave only 5 unseen
        let seen = Set(pool.map(\.id)).subtracting(unseen)
        let today = DailyWords.forToday(count: 5, seenIds: seen, calendar: cal, isPro: false, now: date(2024, 6, 1))
        XCTAssertTrue(Set(ids(today)).isSubset(of: unseen))
    }

    func testCountGreaterThanPoolClampsWithoutCrashOrDuplicates() {
        let result = DailyWords.forToday(count: 1000, seenIds: [], calendar: cal, isPro: false, now: date(2024, 6, 1))
        XCTAssertEqual(result.count, WordAccess.freeLimit)            // clamped to the 50-word pool
        XCTAssertEqual(Set(ids(result)).count, result.count)         // no word repeats within a day
    }

    func testZeroCountReturnsEmpty() {
        XCTAssertTrue(DailyWords.forToday(count: 0, seenIds: [], calendar: cal, isPro: false, now: date(2024, 6, 1)).isEmpty)
    }
}
