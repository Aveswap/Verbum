import Foundation

@MainActor
class QuizViewModel: ObservableObject {
    struct QuizQuestion {
        let word: Word
        let options: [String]
        let correct: String
    }

    @Published var currentQuestion: QuizQuestion?
    @Published var score = 0
    @Published var questionNumber = 0
    @Published var selectedAnswer: String?
    @Published var isCorrect: Bool?
    @Published var isFinished = false
    @Published var insufficientWords = false

    var onAnswer: ((UUID, Bool) -> Void)?

    private let totalQuestions = 5
    private let pool: [Word]
    /// Words already asked this session — prevents the same word appearing twice.
    private var asked = Set<UUID>()

    init(seenIds: Set<UUID>, isPro: Bool, words: [Word]? = nil) {
        // An explicit set (e.g. "words you'll soon forget" — FSRS-fading claimed words) takes
        // priority when it has enough accessible words; otherwise fall back to the seen pool.
        let explicit = (words ?? []).filter { WordAccess.canAccess($0, isPro: isPro) }
        if explicit.count >= 4 {
            self.pool = explicit
        } else {
            // Pool = words the user has seen AND still has access to.
            self.pool = WordRepository.shared.all.filter { word in
                seenIds.contains(word.id) &&
                WordAccess.canAccess(word, isPro: isPro)
            }
        }
        if pool.count < 4 {
            insufficientWords = true
            isFinished = true
        } else {
            nextQuestion()
        }
    }

    func nextQuestion() {
        guard questionNumber < totalQuestions else { isFinished = true; return }
        guard let word = pickWord() else { isFinished = true; return }
        asked.insert(word.id)
        // Exclude distractors whose definition matches the answer, so the correct option is
        // unambiguous when two words share a definition string.
        let distractors = pool.filter { $0.id != word.id && $0.definition != word.definition }
            .shuffled().prefix(3).map(\.definition)
        let options = ([word.definition] + distractors).shuffled()
        currentQuestion = QuizQuestion(word: word, options: options, correct: word.definition)
        selectedAnswer = nil
        isCorrect = nil
        questionNumber += 1
    }

    /// Picks the next word, avoiding repeats within the session where possible. With the minimum
    /// allowed pool (4 words) and 5 fixed questions, the 5th pick has no unused word left — rather
    /// than ending the quiz early on question 4 (which left "Score: X / 5" showing the wrong
    /// denominator), allow a repeat there, just never the word that was *just* asked.
    private func pickWord() -> Word? {
        let unused = pool.filter { !asked.contains($0.id) }
        if let word = unused.randomElement() { return word }
        return pool.filter { $0.id != currentQuestion?.word.id }.randomElement() ?? pool.randomElement()
    }

    func selectAnswer(_ answer: String) {
        guard selectedAnswer == nil, let q = currentQuestion else { return }
        selectedAnswer = answer
        let correct = answer == q.correct
        isCorrect = correct
        onAnswer?(q.word.id, correct)
        if correct {
            score += 1
            HapticManager.success()
        } else {
            HapticManager.error()
        }
    }
}
