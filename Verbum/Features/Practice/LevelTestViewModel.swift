import Foundation

@MainActor
class LevelTestViewModel: ObservableObject {
    @Published var currentIndex: Int = 0
    @Published var selectedOption: String? = nil
    @Published var isCorrect: Bool? = nil
    @Published var score: Int = 0
    @Published var isFinished: Bool = false
    @Published private(set) var options: [String] = []

    let questions: [Word]
    private let allWords: [Word]

    init() {
        let all = WordRepository.shared.all
        allWords = all
        questions = Array(all.shuffled().prefix(10))
        regenerateOptions()
    }

    var currentQuestion: Word? {
        guard questions.indices.contains(currentIndex) else { return nil }
        return questions[currentIndex]
    }

    private func regenerateOptions() {
        guard let q = currentQuestion else { options = []; return }
        var opts = Set([q.definition])
        let distractors = allWords.filter { $0.id != q.id }.shuffled()
        for w in distractors {
            opts.insert(w.definition)
            if opts.count == 4 { break }
        }
        options = opts.shuffled()
    }

    func select(_ option: String) {
        guard selectedOption == nil, let q = currentQuestion else { return }
        selectedOption = option
        isCorrect = option == q.definition
        if isCorrect == true { score += 1 }
    }

    func next() {
        if currentIndex < questions.count - 1 {
            currentIndex += 1
            selectedOption = nil
            isCorrect = nil
            regenerateOptions()
        } else {
            isFinished = true
        }
    }

    var resultLevel: WordLevel {
        switch score {
        case 0...3: return .beginner
        case 4...7: return .intermediate
        default: return .expert
        }
    }

    var progress: Double {
        Double(currentIndex + 1) / Double(questions.count)
    }
}
