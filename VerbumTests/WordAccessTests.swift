import XCTest
@testable import Verbum

/// Exercises the soft-paywall rules against a fixture catalogue injected via
/// `WordAccess.catalogProvider`, so no database/repository boot is needed.
@MainActor
final class WordAccessTests: XCTestCase {

    private func word(_ text: String, level: WordLevel, rank: Int?, category: String = "General") -> Word {
        Word(
            id: UUID(), text: text, phonetic: "", partOfSpeech: "noun",
            definition: "def of \(text)", exampleSentence: nil, synonyms: [],
            category: category, level: level, isNew: true, etymology: nil,
            frequencyRank: rank
        )
    }

    /// 60 beginner words (ranks 1...60) + 5 premium-category beginner words + 10 intermediate.
    private func makeCatalogue() -> [Word] {
        var words: [Word] = []
        for i in 1...60 { words.append(word("b\(i)", level: .beginner, rank: i)) }
        for i in 1...5  { words.append(word("prem\(i)", level: .beginner, rank: 100 + i, category: "Science")) }
        for i in 1...10 { words.append(word("i\(i)", level: .intermediate, rank: i)) }
        return words
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

    func testFreePoolIsCappedAtFreeLimit() {
        XCTAssertEqual(WordAccess.freePool(level: .beginner).count, WordAccess.freeLimit)
    }

    func testFreePoolExcludesPremiumCategories() {
        let pool = WordAccess.freePool(level: .beginner)
        XCTAssertFalse(pool.contains { WordAccess.premiumDbCategories.contains($0.category) })
    }

    func testFreePoolOrderedByFrequencyRankAscending() {
        let ranks = WordAccess.freePool(level: .beginner).compactMap(\.frequencyRank)
        XCTAssertEqual(ranks, ranks.sorted())
        XCTAssertEqual(ranks.first, 1)            // most common word first
        XCTAssertEqual(ranks.last, WordAccess.freeLimit) // 50th by rank, premium excluded
    }

    func testProSeesFullLevelCatalogue() {
        // 60 plain + 5 premium beginner words are all visible to Pro.
        let all = WordAccess.accessibleWords(isPro: true, level: .beginner)
        XCTAssertEqual(all.count, 65)
    }

    func testCanAccessFreeVsLockedWord() {
        let pool = WordAccess.freePool(level: .beginner)
        let inPool = pool[0]
        let locked = word("zzz", level: .beginner, rank: 9999) // not in the catalogue at all
        XCTAssertTrue(WordAccess.canAccess(inPool, isPro: false, userLevel: .beginner))
        XCTAssertFalse(WordAccess.canAccess(locked, isPro: false, userLevel: .beginner))
        XCTAssertTrue(WordAccess.canAccess(locked, isPro: true, userLevel: .beginner))
    }

    func testWrongLevelNeverAccessibleToFreeUser() {
        let intermediate = WordAccess.accessibleWords(isPro: true, level: .intermediate)[0]
        XCTAssertFalse(WordAccess.canAccess(intermediate, isPro: false, userLevel: .beginner))
    }

    func testRemainingFreeCountDecrementsWithSeen() {
        let pool = WordAccess.freePool(level: .beginner)
        let seen = Set(pool.prefix(10).map(\.id))
        XCTAssertEqual(WordAccess.remainingFreeCount(seenIds: seen, userLevel: .beginner),
                       WordAccess.freeLimit - 10)
    }

    func testLockedAtLevelCount() {
        // 65 beginner words total (60 plain + 5 premium); 50 are free ⇒ 15 locked behind the cap.
        XCTAssertEqual(WordAccess.lockedAtLevelCount(userLevel: .beginner), 65 - WordAccess.freeLimit)
    }
}
