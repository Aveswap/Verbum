import SwiftUI

@MainActor
class FillGapViewModel: ObservableObject {
    struct GapQuestion {
        let word: Word
        let sentence: String           // full sentence
        let blankedSentence: String    // sentence with "___"
        let options: [String]
        let correct: String
    }

    @Published var currentQuestion: GapQuestion?
    @Published var score = 0
    @Published var questionNumber = 0
    @Published var selectedAnswer: String?
    @Published var isCorrect: Bool?
    @Published var isFinished = false
    @Published var insufficientWords = false

    var onAnswer: ((UUID, Bool) -> Void)?

    private let totalQuestions = 5
    private let pool: [Word]
    private let distractorPool: [Word]

    init(seenIds: Set<UUID>) {
        let seen = WordRepository.shared.all.filter { seenIds.contains($0.id) }
        self.distractorPool = seen
        // FillGap requires words with example sentences containing the word as a whole token
        self.pool = seen.filter { word in
            guard let sentence = word.exampleSentence else { return false }
            return Self.findWordRange(of: word.text, in: sentence) != nil
        }
        if pool.count < 1 || distractorPool.count < 4 {
            insufficientWords = true
            isFinished = true
        } else {
            nextQuestion()
        }
    }

    func nextQuestion() {
        guard questionNumber < totalQuestions else { isFinished = true; return }
        guard let word = pool.randomElement(), let sentence = word.exampleSentence else {
            isFinished = true; return
        }

        let blanked = Self.blankOut(word: word.text, in: sentence)

        let distractors = distractorPool
            .filter { $0.id != word.id }
            .shuffled()
            .prefix(3)
            .map { $0.text }

        let options = ([word.text] + distractors).shuffled()

        currentQuestion = GapQuestion(
            word: word,
            sentence: sentence,
            blankedSentence: blanked,
            options: options,
            correct: word.text
        )
        selectedAnswer = nil
        isCorrect = nil
        questionNumber += 1
    }

    func selectAnswer(_ answer: String) {
        guard selectedAnswer == nil, let q = currentQuestion else { return }
        selectedAnswer = answer
        let correct = answer.lowercased() == q.correct.lowercased()
        isCorrect = correct
        onAnswer?(q.word.id, correct)
        if correct {
            score += 1
            HapticManager.success()
        } else {
            HapticManager.error()
        }
    }

    /// Match the word as a whole token (\bword\b style), case-insensitive.
    /// Avoids matching "run" inside "running" or "rerun".
    static func findWordRange(of word: String, in sentence: String) -> Range<String.Index>? {
        let pattern = "\\b\(NSRegularExpression.escapedPattern(for: word))\\b"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
            return nil
        }
        let range = NSRange(sentence.startIndex..., in: sentence)
        guard let match = regex.firstMatch(in: sentence, range: range) else { return nil }
        return Range(match.range, in: sentence)
    }

    static func blankOut(word: String, in sentence: String) -> String {
        let pattern = "\\b\(NSRegularExpression.escapedPattern(for: word))\\b"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
            return sentence
        }
        let range = NSRange(sentence.startIndex..., in: sentence)
        return regex.stringByReplacingMatches(in: sentence, range: range, withTemplate: "___")
    }
}

struct FillGapView: View {
    @EnvironmentObject var userProfile: UserProfileStore
    @StateObject private var viewModel: FillGapViewModel
    @Environment(\.dismiss) private var dismiss

    init(seenIds: Set<UUID>) {
        _viewModel = StateObject(wrappedValue: FillGapViewModel(seenIds: seenIds))
    }

    var body: some View {
        NavigationView {
            ZStack {
                AppColors.background.ignoresSafeArea()
                if viewModel.insufficientWords {
                    InsufficientWordsView(needed: 4) { dismiss() }
                } else if viewModel.isFinished {
                    finishedView
                } else if let question = viewModel.currentQuestion {
                    questionView(question)
                }
            }
            .navigationTitle("Fill the Gap")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark").foregroundColor(AppColors.textSecondary)
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            viewModel.onAnswer = { id, correct in
                userProfile.recordReview(id, rating: correct ? .good : .again)
            }
        }
    }

    private var finishedView: some View {
        VStack(spacing: AppSpacing.lg) {
            Spacer()
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 70))
                .foregroundColor(AppColors.accent)
            Text("Well done!")
                .font(AppTypography.heroTitle)
                .foregroundColor(AppColors.textPrimary)
            Text("Score: \(viewModel.score) / 5")
                .font(.system(size: 24, weight: .semibold))
                .foregroundColor(AppColors.textSecondary)
            Spacer()
            PillButton(title: "Done") { dismiss() }
                .padding(.horizontal, AppSpacing.lg)
                .padding(.bottom, AppSpacing.xl)
        }
    }

    private func questionView(_ q: FillGapViewModel.GapQuestion) -> some View {
        VStack(spacing: AppSpacing.lg) {
            // Progress
            HStack(spacing: 6) {
                ForEach(0..<5, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(i < viewModel.questionNumber ? AppColors.accent : AppColors.surface)
                        .frame(height: 4)
                }
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.top, AppSpacing.md)

            Text("Fill in the blank")
                .font(.system(size: 15))
                .foregroundColor(AppColors.textSecondary)

            // Sentence with blank highlighted
            Text(attributedSentence(q.blankedSentence))
                .font(.system(size: 20, weight: .medium))
                .foregroundColor(AppColors.textPrimary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, AppSpacing.lg)
                .padding(AppSpacing.md)
                .background(AppColors.surface)
                .cornerRadius(AppSpacing.cornerRadius)
                .padding(.horizontal, AppSpacing.md)

            Spacer()

            // Options
            VStack(spacing: AppSpacing.sm) {
                ForEach(q.options, id: \.self) { option in
                    GapOptionButton(
                        text: option,
                        state: gapState(for: option, in: q)
                    ) { viewModel.selectAnswer(option) }
                }
            }
            .padding(.horizontal, AppSpacing.md)

            if viewModel.selectedAnswer != nil {
                if let correct = viewModel.isCorrect, !correct, let q = viewModel.currentQuestion {
                    Text("Correct: \(q.correct)")
                        .font(.system(size: 14))
                        .foregroundColor(AppColors.textSecondary)
                }
                PillButton(title: viewModel.questionNumber == 5 ? "See Results" : "Next") {
                    withAnimation { viewModel.nextQuestion() }
                }
                .padding(.horizontal, AppSpacing.md)
            }

            Spacer()
        }
    }

    private func attributedSentence(_ sentence: String) -> AttributedString {
        var result = AttributedString(sentence)
        if let range = result.range(of: "___") {
            result[range].foregroundColor = UIColor(AppColors.accent)
            result[range].font = .boldSystemFont(ofSize: 20)
        }
        return result
    }

    private func gapState(for option: String, in q: FillGapViewModel.GapQuestion) -> GapOptionButton.AnswerState {
        guard viewModel.selectedAnswer != nil else { return .normal }
        if option.lowercased() == q.correct.lowercased() { return .correct }
        if option == viewModel.selectedAnswer { return .wrong }
        return .normal
    }
}

private struct GapOptionButton: View {
    enum AnswerState { case normal, correct, wrong }
    let text: String
    let state: AnswerState
    let action: () -> Void

    private var bg: Color {
        switch state {
        case .normal:  return AppColors.surface
        case .correct: return Color.green.opacity(0.25)
        case .wrong:   return Color.red.opacity(0.25)
        }
    }

    var body: some View {
        Button(action: action) {
            Text(text)
                .font(.system(size: 17, weight: .medium))
                .foregroundColor(AppColors.textPrimary)
                .frame(maxWidth: .infinity)
                .padding(AppSpacing.md)
                .background(bg)
                .cornerRadius(AppSpacing.cornerRadius)
        }
        .disabled(state != .normal)
    }
}
