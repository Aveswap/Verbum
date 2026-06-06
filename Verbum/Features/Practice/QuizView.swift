import SwiftUI

struct QuizView: View {
    @EnvironmentObject var userProfile: UserProfileStore
    @StateObject private var viewModel: QuizViewModel
    @Environment(\.dismiss) private var dismiss

    init(seenIds: Set<UUID>, isPro: Bool) {
        _viewModel = StateObject(wrappedValue: QuizViewModel(
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
            .navigationTitle("Word Meaning")
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
            Image(systemName: "star.fill")
                .font(.system(size: 70))
                .foregroundColor(AppColors.accent)
            Text("Quiz Complete!")
                .font(AppTypography.heroTitle)
                .foregroundColor(AppColors.textPrimary)
            Text("Score: \(viewModel.score) / \(5)")
                .font(.system(size: 24, weight: .semibold))
                .foregroundColor(AppColors.textSecondary)
            Spacer()
            PillButton(title: "Done") { dismiss() }
                .padding(.horizontal, AppSpacing.lg)
                .padding(.bottom, AppSpacing.xl)
        }
    }

    private func questionView(_ q: QuizViewModel.QuizQuestion) -> some View {
        VStack(spacing: AppSpacing.lg) {
            // Progress dots
            HStack(spacing: 6) {
                ForEach(0..<5, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(i < viewModel.questionNumber ? AppColors.accent : AppColors.surface)
                        .frame(height: 4)
                }
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.top, AppSpacing.md)

            Text("What does this word mean?")
                .font(.system(size: 15))
                .foregroundColor(AppColors.textSecondary)

            Text(q.word.text)
                .font(AppTypography.wordTitle)
                .foregroundColor(AppColors.textPrimary)

            Text(q.word.phonetic)
                .font(AppTypography.phonetic)
                .foregroundColor(AppColors.textSecondary)

            Spacer()

            VStack(spacing: AppSpacing.sm) {
                ForEach(q.options, id: \.self) { option in
                    QuizOptionButton(
                        text: option,
                        state: optionState(for: option, in: q)
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

    private func optionState(for option: String, in q: QuizViewModel.QuizQuestion) -> QuizOptionButton.AnswerState {
        guard viewModel.selectedAnswer != nil else { return .normal }
        if option == q.correct { return .correct }
        if option == viewModel.selectedAnswer { return .wrong }
        return .normal
    }
}

private struct QuizOptionButton: View {
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
                .font(.system(size: 15))
                .foregroundColor(AppColors.textPrimary)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(AppSpacing.md)
                .background(bg)
                .cornerRadius(AppSpacing.cornerRadius)
        }
        .disabled(state != .normal)
    }
}
