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

    init(seenIds: Set<UUID>, isPro: Bool, userLevel: WordLevel) {
        // Pool = words the user has seen AND still has access to.
        // After the locked-as-seen bug fix, the two sets already line up — the
        // extra canAccess check is defensive in case of stale persisted data.
        self.pool = WordRepository.shared.all.filter { word in
            seenIds.contains(word.id) &&
            WordAccess.canAccess(word, isPro: isPro, userLevel: userLevel)
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
        guard let word = pool.randomElement() else { return }
        let distractors = pool.filter { $0.id != word.id }.shuffled().prefix(3).map(\.definition)
        let options = ([word.definition] + distractors).shuffled()
        currentQuestion = QuizQuestion(word: word, options: options, correct: word.definition)
        selectedAnswer = nil
        isCorrect = nil
        questionNumber += 1
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
