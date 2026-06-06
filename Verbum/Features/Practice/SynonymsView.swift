import SwiftUI

@MainActor
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
    @Published var insufficientWords = false

    var onAnswer: ((UUID, Bool) -> Void)?

    private let totalQuestions = 5
    private let pool: [Word]
    private let distractorPool: [Word]
    /// Words already asked — prevents repeats within the session.
    private var asked = Set<UUID>()

    init(seenIds: Set<UUID>, isPro: Bool) {
        let seen = WordRepository.shared.all.filter { word in
            seenIds.contains(word.id) &&
            WordAccess.canAccess(word, isPro: isPro)
        }
        self.distractorPool = seen
        self.pool = seen.filter { !$0.synonyms.isEmpty }
        if pool.count < 1 || distractorPool.count < 4 {
            insufficientWords = true
            isFinished = true
        } else {
            nextQuestion()
        }
    }

    func nextQuestion() {
        guard questionNumber < totalQuestions else { isFinished = true; return }
        guard let word = pickWord(),
              let correctSynonym = word.synonyms.randomElement() else {
            isFinished = true; return
        }

        let distractors = distractorPool
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

    /// Picks the next word with synonyms, avoiding repeats within a round; reuses gracefully
    /// if the pool is small, never repeating the current word back-to-back.
    private func pickWord() -> Word? {
        var fresh = pool.filter { !asked.contains($0.id) }
        if fresh.isEmpty {
            asked.removeAll()
            fresh = pool.filter { $0.id != currentQuestion?.word.id }
            if fresh.isEmpty { fresh = pool }
        }
        guard let word = fresh.randomElement() else { return nil }
        asked.insert(word.id)
        return word
    }

    func selectAnswer(_ answer: String) {
        guard selectedAnswer == nil, let q = currentQuestion else { return }
        selectedAnswer = answer
        let correct = answer == q.correct
        isCorrect = correct
        onAnswer?(q.word.id, correct)
        if correct { score += 1; HapticManager.success() }
        else { HapticManager.error() }
    }
}

struct SynonymsView: View {
    @EnvironmentObject var userProfile: UserProfileStore
    @StateObject private var viewModel: SynonymsViewModel
    @Environment(\.dismiss) private var dismiss

    init(seenIds: Set<UUID>, isPro: Bool) {
        _viewModel = StateObject(wrappedValue: SynonymsViewModel(
            seenIds: seenIds, isPro: isPro))
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
        .onAppear {
            viewModel.onAnswer = { id, correct in
                userProfile.recordReview(id, rating: correct ? .good : .again)
            }
        }
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

            Text(q.word.localizedPartOfSpeech + " · " + q.word.definition)
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
