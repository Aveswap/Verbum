import Foundation
import os

@MainActor
class WordFeedViewModel: ObservableObject {
    @Published var words: [Word] = []
    @Published var currentIndex: Int = 0
    @Published var goingBack: Bool = false

    /// Counts forward swipes since the last quiz — resets on quiz shown and on filter change.
    private(set) var swipesSinceLastQuiz: Int = 0
    /// The last 5 swiped words for the batch quiz.
    private var recentBatchWords: [Word] = []

    // Current active filter — preserved across restartFeed()
    var categoryFilter: String? = nil
    var isPro: Bool = false
    /// IDs of words FSRS says are due for review. Set from outside (WordFeedView.onAppear)
    /// because the VM has no access to UserProfileStore.
    var dueReviewIds: [UUID] = []
    /// IDs the user has already swiped. Set from outside (like dueReviewIds) so the Pro feed
    /// can surface unseen words first instead of reshuffling the whole catalog every restart
    /// (which made a returning Pro user re-see old words before new ones).
    var seenWordIds: Set<UUID> = []

    init() {
        SpeechService.configureAudioSession()
        // WordDatabase seeds synchronously from the bundle, so restartFeed() here
        // populates words before the first render — no skeleton flash.
        // onAppear will call reloadFromRepository() again once isPro is set.
        restartFeed()
    }

    var currentWord: Word? {
        guard !words.isEmpty, words.indices.contains(currentIndex) else { return nil }
        return words[currentIndex]
    }

    var isAtEnd: Bool {
        !words.isEmpty && currentIndex >= words.count - 1
    }

    var isAtStart: Bool {
        currentIndex == 0
    }

    var batchProgress: Int {
        swipesSinceLastQuiz + 1
    }

    var currentBatchWords: [Word] {
        recentBatchWords
    }

    var isEndOfBatch: Bool {
        swipesSinceLastQuiz == 4
    }

    func nextWord() {
        guard currentIndex < words.count - 1 else { return }
        goingBack = false
        if let word = currentWord {
            // Locked cards (premium tease + paywall card) don't count for batch progress.
            if WordAccess.canAccess(word, isPro: isPro) {
                recentBatchWords.append(word)
                if recentBatchWords.count > 5 { recentBatchWords.removeFirst() }
                swipesSinceLastQuiz += 1
            }
        }
        currentIndex += 1
    }

    func previousWord() {
        guard currentIndex > 0 else { return }
        goingBack = true
        if swipesSinceLastQuiz > 0 { swipesSinceLastQuiz -= 1 }
        if !recentBatchWords.isEmpty { recentBatchWords.removeLast() }
        currentIndex -= 1
    }

    /// Appends the card currently in front to the batch. Needed because the quiz triggers
    /// on the 5th swipe *before* nextWord() runs for that card, so without this the most
    /// recent word would be excluded and the quiz would only cover the previous 4. Caps at 5.
    func addToBatch(_ word: Word) {
        recentBatchWords.append(word)
        if recentBatchWords.count > 5 { recentBatchWords.removeFirst() }
    }

    func resetBatchCounter() {
        swipesSinceLastQuiz = 0
        recentBatchWords = []
    }

    func restartFeed() {
        // No difficulty levels: the feed is the whole active-language catalogue.
        // Free users get WordAccess.freePool() (top 50 by freq-rank); Pro gets everything,
        // unseen-first. A category filter (category drill-down) narrows it. Shuffle is applied
        // *inside each group* (due / unseen / seen) — never across groups — so the "review →
        // unseen → seen" priority stays intact while order *within* a group is randomized.
        if let ct = categoryFilter {
            let pool = WordRepository.shared.all.filter { $0.category == ct }
            words = prependDueReviews(Self.shuffle(pool))
        } else if isPro {
            words = prependDueReviews(unseenFirst(WordRepository.shared.all))
        } else {
            // Free: keep the curated free-pool order (the hand-picked "trailer") for unseen words —
            // never shuffle the front; that opening is the conversion moment. Already-seen words
            // still get shuffled for variety on repeat sessions.
            words = prependDueReviews(unseenFirst(WordAccess.freePool(), preserveUnseenOrder: true))
        }
        goingBack = false
        currentIndex = 0
        resetBatchCounter()
        // Build-verification log: lets us prove the Fisher-Yates path actually runs on device.
        // If you see this in Console with non-row-order `first5`, the shuffle is alive.
        let logger = Logger(subsystem: "com.verbum.app", category: "Feed")
        let first5 = words.prefix(5).map(\.text).joined(separator: ", ")
        logger.info("FY_SHUFFLE_v2 isPro=\(self.isPro, privacy: .public) seen=\(self.seenWordIds.count, privacy: .public) due=\(self.dueReviewIds.count, privacy: .public) total=\(self.words.count, privacy: .public) first5=[\(first5, privacy: .public)]")
    }

    /// Defensive Fisher-Yates shuffle with a fresh `SystemRandomNumberGenerator`. Used in place
    /// of `Array.shuffled()` so the feed order is guaranteed non-deterministic at runtime — if
    /// `Sequence.shuffled()` ever returns identity (compiler regression, deterministic RNG,
    /// extension overload elsewhere in the build), this still randomizes.
    static func shuffle(_ pool: [Word]) -> [Word] {
        guard pool.count > 1 else { return pool }
        var out = pool
        var rng = SystemRandomNumberGenerator()
        for i in stride(from: out.count - 1, through: 1, by: -1) {
            let j = Int.random(in: 0...i, using: &rng)
            out.swapAt(i, j)
        }
        return out
    }

    /// Count of free pool words the user hasn't yet swiped at their current level.
    /// Drives the "5 left" badge in the feed top bar (only meaningful for free users).
    func remainingFreeCount(seenIds: Set<UUID>) -> Int {
        guard !isPro else { return 0 }
        return WordAccess.remainingFreeCount(seenIds: seenIds)
    }

    /// True when a free user has consumed every word in their free pool.
    /// The view layer shows a paywall card on the final swipe.
    func isFreePoolExhausted(seenIds: Set<UUID>) -> Bool {
        !isPro && remainingFreeCount(seenIds: seenIds) == 0 && !words.isEmpty
    }

    /// True when a free user has NO free words at all (the whole loaded catalogue is premium-
    /// locked) — distinct from "exhausted". Gated on a non-empty catalogue so the initial DB
    /// seed (catalogue momentarily empty) still shows the skeleton, not a premature paywall.
    func freePoolIsEmpty() -> Bool {
        !isPro && words.isEmpty && !WordRepository.shared.all.isEmpty && WordAccess.freePool().isEmpty
    }

    /// Orders a pool so words the user hasn't swiped yet come first, followed by already-seen
    /// words — so a returning Pro user keeps getting new vocabulary before the app starts
    /// recycling familiar words. Within each group we use a *letter-stratified* shuffle (not a
    /// flat shuffle) — without it, a user whose unseen subset is dominated by one letter
    /// (e.g. recent vocabulary rounds added words alphabetically) gets a long alphabet-clustered
    /// streak even with a perfect Fisher-Yates: the data itself is monochromatic. Stratification
    /// interleaves first letters so the feed *feels* varied even when the unseen pool isn't.
    private func unseenFirst(_ pool: [Word], preserveUnseenOrder: Bool = false) -> [Word] {
        guard !seenWordIds.isEmpty else {
            // First session: keep the incoming order verbatim when asked (the curated free trailer),
            // otherwise stratify for variety (Pro's full-catalogue feed).
            return preserveUnseenOrder ? pool : Self.diversify(pool)
        }
        let unseenRaw = pool.filter { !seenWordIds.contains($0.id) }
        let unseen = preserveUnseenOrder ? unseenRaw : Self.diversify(unseenRaw)
        let seen   = Self.diversify(pool.filter {  seenWordIds.contains($0.id) })
        return unseen + seen
    }

    /// Letter-stratified shuffle: groups words by first letter, shuffles inside each group, then
    /// round-robins across groups (with the group order itself re-shuffled each round). The
    /// result is a randomized stream where consecutive cards almost never share a first letter
    /// — until one group is exhausted, after which the remaining cards rotate among whatever's
    /// left. Falls back to a plain Fisher-Yates when the pool spans ≤1 letter or ≤1 word.
    static func diversify(_ pool: [Word]) -> [Word] {
        guard pool.count > 1 else { return pool }
        var buckets: [Character: [Word]] = [:]
        for word in pool {
            let key = Character(word.text.prefix(1).lowercased())
            buckets[key, default: []].append(word)
        }
        guard buckets.count > 1 else { return Self.shuffle(pool) }
        for (k, v) in buckets { buckets[k] = Self.shuffle(v) }
        var rng = SystemRandomNumberGenerator()
        var result: [Word] = []
        result.reserveCapacity(pool.count)
        while !buckets.isEmpty {
            // Randomize the letter order *each round* so we don't always hit a→b→c…
            let letters = buckets.keys.shuffled(using: &rng)
            for letter in letters {
                guard var words = buckets[letter], !words.isEmpty else { continue }
                result.append(words.removeFirst())
                if words.isEmpty {
                    buckets.removeValue(forKey: letter)
                } else {
                    buckets[letter] = words
                }
            }
        }
        return result
    }

    /// Front-loads up to 10 FSRS-due reviews ahead of the rest of the feed.
    /// Limits to 10 so a long backlog doesn't drown out new content.
    private func prependDueReviews(_ rest: [Word]) -> [Word] {
        guard !dueReviewIds.isEmpty else { return rest }
        let dueSet = Set(dueReviewIds)
        let dueWords = rest.filter { dueSet.contains($0.id) }.prefix(10)
        let dueIds = Set(dueWords.map(\.id))
        let remainder = rest.filter { !dueIds.contains($0.id) }
        return Array(dueWords) + remainder
    }

    func reloadFromRepository() {
        restartFeed()
    }

    func loadWords(_ newWords: [Word]) {
        words = newWords.shuffled()
        currentIndex = 0
        goingBack = false
        resetBatchCounter()
    }

    func speakWord(_ text: String) {
        SpeechService.speak(text)
    }
}
