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

    // Current active filters — preserved across restartFeed()
    var levelFilter: WordLevel? = nil
    var categoryFilter: String? = nil
    var isPro: Bool = false
    /// IDs of words FSRS says are due for review. Set from outside (WordFeedView.onAppear)
    /// because the VM has no access to UserProfileStore.
    var dueReviewIds: [UUID] = []

    init() {
        SpeechService.configureAudioSession()
        // WordRepository is @MainActor; we're already on the main actor so a direct read is fine.
        self.words = WordRepository.shared.feedWords(isPro: false).shuffled()
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
            recentBatchWords.append(word)
            if recentBatchWords.count > 5 { recentBatchWords.removeFirst() }
        }
        swipesSinceLastQuiz += 1
        currentIndex += 1
    }

    func previousWord() {
        guard currentIndex > 0 else { return }
        goingBack = true
        if swipesSinceLastQuiz > 0 { swipesSinceLastQuiz -= 1 }
        if !recentBatchWords.isEmpty { recentBatchWords.removeLast() }
        currentIndex -= 1
    }

    func resetBatchCounter() {
        swipesSinceLastQuiz = 0
        recentBatchWords = []
    }

    func restartFeed() {
        // Always load the full catalog; locked words are shown blurred in the card (soft paywall).
        // If a level or category filter is active, respect it — but don't filter by pro tier here.
        // NOTE: restartFeed() calls resetBatchCounter() at the end — callers do NOT need to reset separately.
        var pool = WordRepository.shared.all
        if let lv = levelFilter { pool = pool.filter { $0.level == lv } }
        if let ct = categoryFilter { pool = pool.filter { $0.category == ct } }
        if !isPro && levelFilter == nil && categoryFilter == nil {
            // Unfiltered feed: lead with all Beginner words, then sprinkle locked previews (1 in 5)
            let free = pool.filter { $0.level == .beginner }.shuffled()
            let locked = pool.filter { $0.level != .beginner }.shuffled()
            var mixed: [Word] = []
            var lockedIdx = 0
            for (i, w) in free.enumerated() {
                mixed.append(w)
                if (i + 1) % 4 == 0, lockedIdx < locked.count {
                    mixed.append(locked[lockedIdx])
                    lockedIdx += 1
                }
            }
            words = prependDueReviews(mixed)
        } else {
            words = prependDueReviews(pool.shuffled())
        }
        goingBack = false
        currentIndex = 0
        resetBatchCounter()
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
