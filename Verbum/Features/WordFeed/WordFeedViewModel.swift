import Foundation

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
        // unseen-first. A category filter (category drill-down) narrows it.
        if let ct = categoryFilter {
            let pool = WordRepository.shared.all.filter { $0.category == ct }
            words = prependDueReviews(pool.shuffled())
        } else if isPro {
            // Pro, no filter: full catalogue, unseen words first (each group shuffled) so
            // returning users get new content, not repeats.
            words = prependDueReviews(unseenFirst(WordRepository.shared.all))
        } else {
            // Free, no filter: the free 50 in freq-rank order.
            words = WordAccess.freePool()
        }
        goingBack = false
        currentIndex = 0
        resetBatchCounter()
    }

    /// Count of free pool words the user hasn't yet swiped at their current level.
    /// Drives the "5 left" badge in the feed top bar (only meaningful for free users).
    func remainingFreeCount(seenIds: Set<UUID>) -> Int {
        guard !isPro else { return 0 }
        return WordAccess.remainingFreeCount(seenIds: seenIds)
    }

    /// True when a free user has consumed every word in their level's free pool.
    /// The view layer shows a paywall card on the final swipe.
    func isFreePoolExhausted(seenIds: Set<UUID>) -> Bool {
        !isPro && remainingFreeCount(seenIds: seenIds) == 0 && !words.isEmpty
    }

    /// Orders a pool so words the user hasn't swiped yet come first (shuffled), followed by
    /// already-seen words (shuffled) — so a returning Pro user keeps getting new vocabulary
    /// before the app starts recycling familiar words.
    private func unseenFirst(_ pool: [Word]) -> [Word] {
        guard !seenWordIds.isEmpty else { return pool.shuffled() }
        let unseen = pool.filter { !seenWordIds.contains($0.id) }.shuffled()
        let seen   = pool.filter {  seenWordIds.contains($0.id) }.shuffled()
        return unseen + seen
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
