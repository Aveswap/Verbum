import SwiftUI

// MARK: - ViewModel

@MainActor
final class BatchQuizViewModel: ObservableObject {
    let words: [Word]

    @Published var currentIndex = 0
    @Published var selectedAnswer: Int? = nil
    @Published var showResult = false
    @Published var correctCount = 0
    @Published var pointsEarned = 0

    var onAnswer: ((UUID, Bool) -> Void)?

    private let options: [[String]]
    private let correctIndices: [Int]

    init(words: [Word], seenWordsPool: [Word]) {
        self.words = words
        var opts: [[String]] = []
        var correct: [Int] = []
        // Distractors are drawn ONLY from words the user has already seen — practice should
        // reinforce known vocabulary, never surface new words as wrong options. Prefer the
        // same categories as the quiz words for a thematic feel; if that subset has fewer
        // than 3 viable distractors (early user with few learned words), widen to the full
        // seen pool so we still ship 4 options.
        let bucketCategories = Set(words.map(\.category))
        let sameCategoryPool = seenWordsPool.filter { bucketCategories.contains($0.category) }
        for word in words {
            let rightDef = word.definition
            // Drop distractors whose definition is textually identical to the answer, so the
            // correct index is unambiguous, then track correctness by a tag rather than by
            // string search (firstIndex(of:) would point at the wrong slot on a duplicate).
            let primary = sameCategoryPool.filter { $0.id != word.id && $0.definition != rightDef }
            let pool = primary.count >= 3
                ? primary
                : seenWordsPool.filter { $0.id != word.id && $0.definition != rightDef }
            let wrongs = pool.shuffled().prefix(3).map(\.definition)
            var tagged: [(def: String, isCorrect: Bool)] =
                [(rightDef, true)] + wrongs.map { ($0, false) }
            tagged.shuffle()
            opts.append(tagged.map(\.def))
            correct.append(tagged.firstIndex(where: \.isCorrect) ?? 0)
        }
        self.options = opts
        self.correctIndices = correct
    }

    var currentWord: Word { words[currentIndex] }
    var currentOptions: [String] { options[currentIndex] }
    var correctIndex: Int { correctIndices[currentIndex] }
    var isLastQuestion: Bool { currentIndex == words.count - 1 }

    func select(_ index: Int) {
        guard selectedAnswer == nil else { return }
        selectedAnswer = index
        let correct = index == correctIndex
        onAnswer?(currentWord.id, correct)
        if correct {
            correctCount += 1
            pointsEarned += points(for: currentWord)
            HapticManager.correctAnswer()
            SoundManager.shared.playCorrectChime()
        } else {
            HapticManager.wrongAnswer()
        }
    }

    func advance() {
        if isLastQuestion {
            if correctCount == words.count { pointsEarned += 50 }
            showResult = true
        } else {
            currentIndex += 1
            selectedAnswer = nil
        }
    }

    private func points(for word: Word) -> Int { 20 }
}

// MARK: - Quiz View

struct BatchQuizView: View {
    let words: [Word]
    let seenWordsPool: [Word]
    /// Reports points earned, plus the IDs of the words to resurface (only populated when the
    /// user scored 0/5 — the swipe-mark is then rolled back so they re-encounter those words).
    var onFinish: (Int, [UUID]) -> Void

    @EnvironmentObject var userProfile: UserProfileStore
    @StateObject private var vm: BatchQuizViewModel
    @Environment(\.dismiss) private var dismiss

    init(words: [Word], seenWordsPool: [Word], onFinish: @escaping (Int, [UUID]) -> Void) {
        self.words = words
        self.seenWordsPool = seenWordsPool
        self.onFinish = onFinish
        _vm = StateObject(wrappedValue: BatchQuizViewModel(words: words, seenWordsPool: seenWordsPool))
    }

    var body: some View {
        ZStack {
            AppColors.background.ignoresSafeArea()

            if words.count < 2 {
                // Guard against an empty/insufficient batch (would crash on words[currentIndex])
                VStack(spacing: AppSpacing.lg) {
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 60))
                        .foregroundColor(AppColors.accent)
                    Text("Not enough new words to quiz yet")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(AppColors.textPrimary)
                    PillButton(title: "Continue") {
                        onFinish(0, [])
                        dismiss()
                    }
                    .padding(.horizontal, AppSpacing.lg)
                }
            } else if vm.showResult {
                resultScreen
            } else {
                questionScreen
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            vm.onAnswer = { id, correct in
                // Quiz answer drives both the mastery dots and the FSRS scheduler.
                // We map binary correctness to FSRS ratings: again on wrong, good on right.
                // (A future "Hard / Easy" UI could expand this to the full 4-rating scale.)
                userProfile.recordReview(id, rating: correct ? .good : .again)
            }
        }
    }

    // MARK: - Question Screen

    private var questionScreen: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button("Skip") { dismiss() }
                    .font(.system(size: 15))
                    .foregroundColor(AppColors.textSecondary)
                Spacer()
                Text("\(vm.currentIndex + 1) / \(words.count)")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppColors.textSecondary)
                Spacer()
                // Progress dots
                HStack(spacing: 6) {
                    ForEach(0..<words.count, id: \.self) { i in
                        Circle()
                            .fill(i < vm.currentIndex ? AppColors.accent :
                                    i == vm.currentIndex ? AppColors.accent.opacity(0.6) :
                                    AppColors.surface)
                            .frame(width: 8, height: 8)
                    }
                }
            }
            .padding(.horizontal, AppSpacing.lg)
            .padding(.top, AppSpacing.lg)

            Spacer()

            // Word
            VStack(spacing: AppSpacing.sm) {
                Text("What does this word mean?")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(AppColors.textSecondary)

                Text(vm.currentWord.text)
                    .font(.system(size: 36, weight: .bold, design: .serif))
                    .foregroundColor(AppColors.textPrimary)

                Text(vm.currentWord.phonetic)
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundColor(AppColors.textSecondary)
            }
            .padding(.bottom, AppSpacing.xl)

            // Options
            VStack(spacing: AppSpacing.sm) {
                ForEach(Array(vm.currentOptions.enumerated()), id: \.offset) { idx, option in
                    AnswerButton(
                        text: option,
                        state: answerState(for: idx),
                        action: { vm.select(idx) }
                    )
                }
            }
            .padding(.horizontal, AppSpacing.lg)

            Spacer()

            // Next button: always rendered so it reserves space — fades in on answer instead of
            // pushing the question above it. Disabled + hit-test-off while invisible.
            Button(action: vm.advance) {
                Text(vm.isLastQuestion ? "See Results" : "Next Word")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(AppColors.textOnAccent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, AppSpacing.md)
                    .background(AppColors.accent)
                    .cornerRadius(AppSpacing.pillRadius)
            }
            .padding(.horizontal, AppSpacing.lg)
            .padding(.bottom, AppSpacing.xl)
            .opacity(vm.selectedAnswer != nil ? 1 : 0)
            .allowsHitTesting(vm.selectedAnswer != nil)
            .accessibilityHidden(vm.selectedAnswer == nil)
            .animation(.easeInOut(duration: 0.2), value: vm.selectedAnswer)
        }
    }

    private func answerState(for index: Int) -> AnswerButton.State {
        guard let selected = vm.selectedAnswer else { return .idle }
        if index == vm.correctIndex { return .correct }
        if index == selected { return .wrong }
        return .idle
    }

    // MARK: - Result Screen

    private var resultScreen: some View {
        VStack(spacing: AppSpacing.lg) {
            Spacer()

            Text(vm.correctCount == words.count ? "🎉" : vm.correctCount >= 3 ? "👏" : "📚")
                .font(.system(size: 64))

            Text(resultTitle)
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(AppColors.textPrimary)

            Text("\(vm.correctCount)/\(words.count) correct")
                .font(.system(size: 17))
                .foregroundColor(AppColors.textSecondary)

            // Points earned
            VStack(spacing: 4) {
                Text("+\(vm.pointsEarned)")
                    .font(.system(size: 42, weight: .bold))
                    .foregroundColor(AppColors.accent)
                Text("points earned")
                    .font(.system(size: 14))
                    .foregroundColor(AppColors.textSecondary)
                if vm.correctCount == words.count {
                    Text("✨ +50 perfect bonus included")
                        .font(.system(size: 12))
                        .foregroundColor(AppColors.accent.opacity(0.8))
                }
            }
            .padding(AppSpacing.lg)
            .background(AppColors.surface)
            .cornerRadius(AppSpacing.cornerRadius)

            Spacer()

            Button {
                // Zero correct → tell the caller to roll these words back out of "seen"
                // so the user re-encounters them in the feed and gets another shot.
                let resurfaceIds = vm.correctCount == 0 ? words.map(\.id) : []
                onFinish(vm.pointsEarned, resurfaceIds)
                dismiss()
            } label: {
                Text("Continue")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(AppColors.textOnAccent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, AppSpacing.md)
                    .background(AppColors.accent)
                    .cornerRadius(AppSpacing.pillRadius)
            }
            .padding(.horizontal, AppSpacing.lg)
            .padding(.bottom, AppSpacing.xl)
        }
    }

    private var resultTitle: String {
        switch vm.correctCount {
        case words.count: return NSLocalizedString("Perfect!", comment: "quiz result")
        case (words.count - 1)...: return NSLocalizedString("Great job!", comment: "quiz result")
        case 3...: return NSLocalizedString("Good work!", comment: "quiz result")
        default: return NSLocalizedString("Keep learning!", comment: "quiz result")
        }
    }
}

// MARK: - Answer Button

private struct AnswerButton: View {
    enum State { case idle, correct, wrong }

    let text: String
    let state: State
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: AppSpacing.sm) {
                Text(text)
                    .font(.system(size: 15))
                    .foregroundColor(textColor)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                // Reserved trailing slot so the layout doesn't reflow when the icon appears.
                Group {
                    switch state {
                    case .correct: Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
                    case .wrong:   Image(systemName: "xmark.circle.fill").foregroundColor(.red)
                    case .idle:    Color.clear
                    }
                }
                .frame(width: 22, height: 22)
            }
            .padding(AppSpacing.md)
            .background(backgroundColor)
            .cornerRadius(AppSpacing.cornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: AppSpacing.cornerRadius)
                    .stroke(borderColor, lineWidth: state == .idle ? 0 : 1.5)
            )
        }
        .disabled(state != .idle)
        .animation(.easeInOut(duration: 0.2), value: state)
    }

    private var backgroundColor: Color {
        switch state {
        case .idle:    return AppColors.surface
        case .correct: return Color.green.opacity(0.15)
        case .wrong:   return Color.red.opacity(0.15)
        }
    }

    private var textColor: Color {
        switch state {
        case .idle:    return AppColors.textPrimary
        case .correct: return .green
        case .wrong:   return .red
        }
    }

    private var borderColor: Color {
        switch state {
        case .idle:    return .clear
        case .correct: return .green.opacity(0.5)
        case .wrong:   return .red.opacity(0.5)
        }
    }
}
