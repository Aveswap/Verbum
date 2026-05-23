import SwiftUI

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

    private let totalQuestions = 5
    private let wordStore = WordStore()

    init() { nextQuestion() }

    func nextQuestion() {
        guard questionNumber < totalQuestions else { isFinished = true; return }

        let words = wordStore.words.filter { $0.exampleSentence != nil }
        guard words.count >= 4 else { isFinished = true; return }

        let word = words.randomElement()!
        guard let sentence = word.exampleSentence else { nextQuestion(); return }

        let blanked = sentence.replacingOccurrences(
            of: word.text,
            with: "___",
            options: .caseInsensitive
        )

        let distractors = words
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
        isCorrect = answer.lowercased() == q.correct.lowercased()
        if isCorrect == true {
            score += 1
            HapticManager.success()
        } else {
            HapticManager.error()
        }
    }
}

struct FillGapView: View {
    @StateObject private var viewModel = FillGapViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ZStack {
                AppColors.background.ignoresSafeArea()
                if viewModel.isFinished {
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
