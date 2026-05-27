import SwiftUI

@MainActor
class GuessWordViewModel: ObservableObject {
    struct GuessQuestion {
        let definition: String
        let partOfSpeech: String
        let options: [String]   // word texts
        let correct: String
    }

    @Published var currentQuestion: GuessQuestion?
    @Published var score = 0
    @Published var questionNumber = 0
    @Published var selectedAnswer: String?
    @Published var isCorrect: Bool?
    @Published var isFinished = false
    @Published var insufficientWords = false

    var onAnswer: ((UUID, Bool) -> Void)?

    private let totalQuestions = 5
    private let pool: [Word]
    private var currentWordId: UUID?

    init(seenIds: Set<UUID>) {
        self.pool = WordRepository.shared.all.filter { seenIds.contains($0.id) }
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
        let distractors = pool.filter { $0.id != word.id }.shuffled().prefix(3).map(\.text)
        let options = ([word.text] + distractors).shuffled()

        currentWordId = word.id
        currentQuestion = GuessQuestion(
            definition: word.definition,
            partOfSpeech: word.partOfSpeech,
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
        let correct = answer == q.correct
        isCorrect = correct
        if let id = currentWordId { onAnswer?(id, correct) }
        if correct { score += 1; HapticManager.success() }
        else { HapticManager.error() }
    }
}

struct GuessWordView: View {
    @EnvironmentObject var userProfile: UserProfileStore
    @StateObject private var viewModel: GuessWordViewModel
    @Environment(\.dismiss) private var dismiss

    init(seenIds: Set<UUID>) {
        _viewModel = StateObject(wrappedValue: GuessWordViewModel(seenIds: seenIds))
    }

    var body: some View {
        NavigationView {
            ZStack {
                AppColors.background.ignoresSafeArea()
                if viewModel.insufficientWords {
                    InsufficientWordsView(needed: 4) { dismiss() }
                } else if viewModel.isFinished { finishedView }
                else if let q = viewModel.currentQuestion { questionView(q) }
            }
            .navigationTitle("Guess the Word")
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
            Image(systemName: "lightbulb.fill")
                .font(.system(size: 70))
                .foregroundColor(.yellow)
            Text("Nice work!")
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

    private func questionView(_ q: GuessWordViewModel.GuessQuestion) -> some View {
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

            Text("Which word matches this definition?")
                .font(.system(size: 15))
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.center)

            // Definition card
            VStack(spacing: AppSpacing.sm) {
                Text(q.partOfSpeech)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(AppColors.accent)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(q.definition)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(AppColors.textPrimary)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(AppSpacing.md)
            .background(AppColors.surface)
            .cornerRadius(AppSpacing.cornerRadius)
            .padding(.horizontal, AppSpacing.md)

            Spacer()

            // Word options (serif font to match app style)
            VStack(spacing: AppSpacing.sm) {
                ForEach(q.options, id: \.self) { option in
                    WordOptionButton(
                        text: option,
                        state: guessState(for: option, in: q)
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

    private func guessState(for option: String, in q: GuessWordViewModel.GuessQuestion) -> WordOptionButton.AnswerState {
        guard viewModel.selectedAnswer != nil else { return .normal }
        if option == q.correct { return .correct }
        if option == viewModel.selectedAnswer { return .wrong }
        return .normal
    }
}

private struct WordOptionButton: View {
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
                .font(.system(size: 22, weight: .bold, design: .serif))
                .foregroundColor(AppColors.textPrimary)
                .frame(maxWidth: .infinity)
                .padding(AppSpacing.md)
                .background(bg)
                .cornerRadius(AppSpacing.cornerRadius)
        }
        .disabled(state != .normal)
    }
}
