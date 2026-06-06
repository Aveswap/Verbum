import XCTest
@testable import Verbum

/// Exercises the soft-paywall rules against a fixture catalogue injected via
/// `WordAccess.catalogProvider`, so no database/repository boot is needed.
///
/// There are no difficulty levels — access is purely free-pool (top `freeLimit`
/// non-premium words by frequency) vs. Pro (the whole catalogue).
@MainActor
final class WordAccessTests: XCTestCase {

    private func word(_ text: String, rank: Int?, category: String = "General") -> Word {
        Word(
            id: UUID(), text: text, phonetic: "", partOfSpeech: "noun",
            definition: "def of \(text)", exampleSentence: nil, synonyms: [],
            category: category, isNew: true, etymology: nil,
            frequencyRank: rank
        )
    }

    /// 60 non-premium words (ranks 1...60) + 5 premium-category words ⇒ 65 total.
    private func makeCatalogue() -> [Word] {
        var words: [Word] = []
        for i in 1...60 { words.append(word("w\(i)", rank: i)) }
        for i in 1...5  { words.append(word("prem\(i)", rank: 100 + i, category: "Science")) }
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
        XCTAssertEqual(WordAccess.freePool().count, WordAccess.freeLimit)
    }

    func testFreePoolExcludesPremiumCategories() {
        let pool = WordAccess.freePool()
        XCTAssertFalse(pool.contains { WordAccess.premiumDbCategories.contains($0.category) })
    }

    func testFreePoolOrderedByFrequencyRankAscending() {
        let ranks = WordAccess.freePool().compactMap(\.frequencyRank)
        XCTAssertEqual(ranks, ranks.sorted())
        XCTAssertEqual(ranks.first, 1)                   // most common word first
        XCTAssertEqual(ranks.last, WordAccess.freeLimit) // 50th by rank, premium excluded
    }

    func testCanAccessFreeVsLockedWord() {
        let pool = WordAccess.freePool()
        let inPool = pool[0]
        let locked = word("zzz", rank: 9999) // not in the catalogue at all
        XCTAssertTrue(WordAccess.canAccess(inPool, isPro: false))
        XCTAssertFalse(WordAccess.canAccess(locked, isPro: false))
        XCTAssertTrue(WordAccess.canAccess(locked, isPro: true))
    }

    func testPremiumCategoryNeverAccessibleToFreeUser() {
        let premium = makeCatalogue().first { $0.category == "Science" }!
        XCTAssertFalse(WordAccess.canAccess(premium, isPro: false))
        XCTAssertTrue(WordAccess.canAccess(premium, isPro: true))
    }

    func testRemainingFreeCountDecrementsWithSeen() {
        let pool = WordAccess.freePool()
        let seen = Set(pool.prefix(10).map(\.id))
        XCTAssertEqual(WordAccess.remainingFreeCount(seenIds: seen),
                       WordAccess.freeLimit - 10)
    }

    func testLockedCount() {
        // 65 words total; 50 are free ⇒ 15 locked behind the cap.
        XCTAssertEqual(WordAccess.lockedCount(), 65 - WordAccess.freeLimit)
    }
}
