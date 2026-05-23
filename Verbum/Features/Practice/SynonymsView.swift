import SwiftUI

class SynonymsViewModel: ObservableObject {
    struct SynonymQuestion {
        let word: Word
        let options: [String]   // one correct synonym + 3 wrong words
        let correct: String
    }

    @Published var currentQuestion: SynonymQuestion?
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

        let words = wordStore.words.filter { !$0.synonyms.isEmpty }
        guard words.count >= 4 else { isFinished = true; return }

        let word = words.randomElement()!
        let correctSynonym = word.synonyms.randomElement()!

        // Distractors: random words (not synonyms of this word)
        let distractors = wordStore.words
            .filter { $0.id != word.id && !word.synonyms.contains($0.text) }
            .shuffled()
            .prefix(3)
            .map { $0.text }

        let options = ([correctSynonym] + distractors).shuffled()

        currentQuestion = SynonymQuestion(word: word, options: options, correct: correctSynonym)
        selectedAnswer = nil
        isCorrect = nil
        questionNumber += 1
    }

    func selectAnswer(_ answer: String) {
        guard selectedAnswer == nil else { return }
        selectedAnswer = answer
        isCorrect = answer == currentQuestion?.correct
        if isCorrect == true { score += 1; HapticManager.success() }
        else { HapticManager.error() }
    }
}

struct SynonymsView: View {
    @StateObject private var viewModel = SynonymsViewModel()
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
            .navigationTitle("Find Synonyms")
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
            Image(systemName: "arrow.left.arrow.right.circle.fill")
                .font(.system(size: 70))
                .foregroundColor(AppColors.accent)
            Text("Finished!")
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

    private func questionView(_ q: SynonymsViewModel.SynonymQuestion) -> some View {
        VStack(spacing: AppSpacing.lg) {
            HStack(spacing: 6) {
                ForEach(0..<5, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(i < viewModel.questionNumber ? AppColors.accent : AppColors.surface)
                        .frame(height: 4)
                }
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.top, AppSpacing.md)

            Text("Find a synonym for")
                .font(.system(size: 15))
                .foregroundColor(AppColors.textSecondary)

            Text(q.word.text)
                .font(AppTypography.wordTitle)
                .foregroundColor(AppColors.textPrimary)

            Text(q.word.partOfSpeech + " · " + q.word.definition)
                .font(.system(size: 14))
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, AppSpacing.lg)
                .lineLimit(2)

            Spacer()

            // Options as pill buttons in a grid
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: AppSpacing.sm) {
                ForEach(q.options, id: \.self) { option in
                    SynonymOptionButton(
                        text: option,
                        state: synonymState(for: option, in: q)
                    ) { viewModel.selectAnswer(option) }
                }
            }
            .padding(.horizontal, AppSpacing.md)

            if viewModel.selectedAnswer != nil {
                PillButton(title: viewModel.questionNumber == 5 ? "See Results" : "Next") {
                    withAnimation { viewModel.nextQuestion() }
                }
                .padding(.horizontal, AppSpacing.md)
            }

            Spacer()
        }
    }

    private func synonymState(for option: String, in q: SynonymsViewModel.SynonymQuestion) -> SynonymOptionButton.AnswerState {
        guard viewModel.selectedAnswer != nil else { return .normal }
        if option == q.correct { return .correct }
        if option == viewModel.selectedAnswer { return .wrong }
        return .normal
    }
}

private struct SynonymOptionButton: View {
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

    private var border: Color {
        switch state {
        case .correct: return Color.green.opacity(0.6)
        case .wrong:   return Color.red.opacity(0.6)
        default:       return Color.clear
        }
    }

    var body: some View {
        Button(action: action) {
            Text(text)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(AppColors.textPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: 60)
                .background(bg)
                .cornerRadius(AppSpacing.cornerRadius)
                .overlay(
                    RoundedRectangle(cornerRadius: AppSpacing.cornerRadius)
                        .stroke(border, lineWidth: 2)
                )
        }
        .disabled(state != .normal)
    }
}
