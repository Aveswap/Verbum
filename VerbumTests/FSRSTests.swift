import XCTest
@testable import Verbum

/// FSRS-4.5 scheduler — pure function, no app state.
final class FSRSTests: XCTestCase {

    func testFirstReviewBootstrapsFromRating() {
        let r = FSRS.next(.newCard(), rating: .good)
        XCTAssertEqual(r.reps, 1)
        XCTAssertEqual(r.state, .review)
        XCTAssertGreaterThan(r.stability, 0)
        XCTAssertTrue((1.0...10.0).contains(r.difficulty))
        XCTAssertGreaterThan(r.dueDate, Date())
    }

    func testAgainOnNewCardEntersLearning() {
        let r = FSRS.next(.newCard(), rating: .again)
        XCTAssertEqual(r.state, .learning)
    }

    func testEasySchedulesFurtherOutThanHard() {
        let base = FSRS.next(.newCard(), rating: .good)
        let now = Date().addingTimeInterval(3 * 86400)
        let easy = FSRS.next(base, rating: .easy, now: now)
        let hard = FSRS.next(base, rating: .hard, now: now)
        XCTAssertGreaterThan(easy.dueDate, hard.dueDate)
        XCTAssertGreaterThan(easy.stability, hard.stability)
    }

    func testLapseIncrementsLapsesAndShortensInterval() {
        let learned = FSRS.next(.newCard(), rating: .good)
        let now = Date().addingTimeInterval(10 * 86400)
        let lapsed = FSRS.next(learned, rating: .again, now: now)
        XCTAssertEqual(lapsed.lapses, 1)
        XCTAssertEqual(lapsed.state, .relearning)
        XCTAssertLessThan(lapsed.scheduledDays, learned.scheduledDays + 100) // sanity
        XCTAssertGreaterThanOrEqual(lapsed.scheduledDays, 1.0)
    }

    func testIntervalNeverBelowOneDay() {
        var r = FSRS.next(.newCard(), rating: .again)
        for _ in 0..<5 { r = FSRS.next(r, rating: .again, now: r.dueDate) }
        XCTAssertGreaterThanOrEqual(r.scheduledDays, 1.0)
    }

    func testDifficultyStaysClamped() {
        var r = FSRS.next(.newCard(), rating: .again)
        for _ in 0..<20 { r = FSRS.next(r, rating: .again, now: r.dueDate.addingTimeInterval(86400)) }
        XCTAssertTrue((1.0...10.0).contains(r.difficulty))
    }
}
