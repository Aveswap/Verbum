import SwiftUI

// MARK: - ViewModel

final class BatchQuizViewModel: ObservableObject {
    let words: [Word]

    @Published var currentIndex = 0
    @Published var selectedAnswer: Int? = nil
    @Published var showResult = false
    @Published var correctCount = 0
    @Published var pointsEarned = 0

    private let options: [[String]]
    private let correctIndices: [Int]

    init(words: [Word], allWords: [Word]) {
        self.words = words
        var opts: [[String]] = []
        var correct: [Int] = []
        for word in words {
            let rightDef = word.definition
            let wrongs = allWords
                .filter { $0.id != word.id }
                .shuffled()
                .prefix(3)
                .map { $0.definition }
            var choices = ([rightDef] + wrongs).shuffled()
            let ci = choices.firstIndex(of: rightDef) ?? 0
            opts.append(choices)
            correct.append(ci)
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
        if index == correctIndex {
            correctCount += 1
            pointsEarned += points(for: currentWord)
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

    private func points(for word: Word) -> Int {
        switch word.level {
        case .beginner:     return 10
        case .intermediate: return 20
        case .expert:       return 35
        }
    }
}

// MARK: - Quiz View

struct BatchQuizView: View {
    let words: [Word]
    let allWords: [Word]
    var onFinish: (Int) -> Void   // passes points earned

    @StateObject private var vm: BatchQuizViewModel
    @Environment(\.dismiss) private var dismiss

    init(words: [Word], allWords: [Word], onFinish: @escaping (Int) -> Void) {
        self.words = words
        self.allWords = allWords
        self.onFinish = onFinish
        _vm = StateObject(wrappedValue: BatchQuizViewModel(words: words, allWords: allWords))
    }

    var body: some View {
        ZStack {
            AppColors.background.ignoresSafeArea()

            if vm.showResult {
                resultScreen
            } else {
                questionScreen
            }
        }
        .preferredColorScheme(.dark)
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

            // Next button (appears after answer)
            if vm.selectedAnswer != nil {
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
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .animation(.spring(), value: vm.selectedAnswer)
            }
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
                onFinish(vm.pointsEarned)
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
        case words.count: return "Perfect!"
        case (words.count - 1)...: return "Great job!"
        case 3...: return "Good work!"
        default: return "Keep learning!"
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
            HStack {
                Text(text)
                    .font(.system(size: 15))
                    .foregroundColor(textColor)
                    .multilineTextAlignment(.leading)
                Spacer()
                if state == .correct {
                    Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
                } else if state == .wrong {
                    Image(systemName: "xmark.circle.fill").foregroundColor(.red)
                }
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
