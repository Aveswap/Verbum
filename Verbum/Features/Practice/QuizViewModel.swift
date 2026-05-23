import Foundation

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

    private let totalQuestions = 5
    private let wordStore = WordStore()

    init() { nextQuestion() }

    func nextQuestion() {
        guard questionNumber < totalQuestions else { isFinished = true; return }
        let words = wordStore.words
        guard words.count >= 4 else { return }
        let word = words.randomElement()!
        let distractors = words.filter { $0.id != word.id }.shuffled().prefix(3).map(\.definition)
        let options = ([word.definition] + distractors).shuffled()
        currentQuestion = QuizQuestion(word: word, options: options, correct: word.definition)
        selectedAnswer = nil
        isCorrect = nil
        questionNumber += 1
    }

    func selectAnswer(_ answer: String) {
        guard selectedAnswer == nil, let q = currentQuestion else { return }
        selectedAnswer = answer
        isCorrect = answer == q.correct
        if isCorrect == true { score += 1 }
    }
}
