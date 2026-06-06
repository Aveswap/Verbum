import SwiftUI

/// Three time/streak-pressured variants on top of the standard quiz mechanic:
/// - Perfection: keep answering correctly until you reach 10 in a row; one wrong ends it
/// - Rush: 60 seconds, answer as many as you can; high score = total correct
/// - Sprint: 5 questions with a 5-second time limit each; high score = perfect (5 fastest)
enum ChallengeKind: String, CaseIterable, Identifiable {
    case perfection, rush, sprint

    var id: String { rawValue }

    var title: String {
        switch self {
        case .perfection: return NSLocalizedString("Perfection", comment: "challenge")
        case .rush:       return NSLocalizedString("Rush", comment: "challenge")
        case .sprint:     return NSLocalizedString("Sprint", comment: "challenge")
        }
    }

    var subtitle: String {
        switch self {
        case .perfection: return NSLocalizedString("10 in a row, one wrong ends it", comment: "challenge")
        case .rush:       return NSLocalizedString("How many in 60 seconds?", comment: "challenge")
        case .sprint:     return NSLocalizedString("5 words · 5 seconds each", comment: "challenge")
        }
    }

    var icon: String {
        switch self {
        case .perfection: return "trophy.fill"
        case .rush:       return "bolt.fill"
        case .sprint:     return "timer"
        }
    }
}

@MainActor
final class ChallengeViewModel: ObservableObject {
    struct Question {
        let word: Word
        let options: [String]
        let correct: String
    }

    let kind: ChallengeKind
    let pool: [Word]

    @Published var current: Question?
    @Published var selectedAnswer: String?
    @Published var score = 0
    @Published var timeRemaining: Double = 0
    @Published var isFinished = false
    @Published var insufficientWords = false

    var onAnswer: ((UUID, Bool) -> Void)?

    // `nonisolated(unsafe)`: Timer.invalidate() is thread-safe per docs, and the deinit hop
    // is the only off-MainActor access — every other use is on the @MainActor class.
    nonisolated(unsafe) private var timer: Timer?
    /// Words asked in the current round — avoids repeats. Endless modes (rush/perfection)
    /// can outlast the pool, so on exhaustion we start a fresh round rather than stop,
    /// just never repeating the current word back-to-back.
    private var asked = Set<UUID>()

    init(kind: ChallengeKind, seenIds: Set<UUID>, isPro: Bool) {
        self.kind = kind
        self.pool = WordRepository.shared.all.filter { word in
            seenIds.contains(word.id) &&
            WordAccess.canAccess(word, isPro: isPro)
        }
        if pool.count < 4 {
            insufficientWords = true
            isFinished = true
        } else {
            startChallenge()
        }
    }

    deinit { timer?.invalidate() }

    private func startChallenge() {
        switch kind {
        case .rush:
            timeRemaining = 60
            startGlobalTimer()
        case .sprint:
            timeRemaining = 5  // per-question
        case .perfection:
            timeRemaining = 0
        }
        nextQuestion()
    }

    func nextQuestion() {
        guard !isFinished, let word = pickWord() else { return }
        let distractors = pool.filter { $0.id != word.id }.shuffled().prefix(3).map(\.definition)
        let options = ([word.definition] + distractors).shuffled()
        current = Question(word: word, options: options, correct: word.definition)
        selectedAnswer = nil
        if kind == .sprint {
            timeRemaining = 5
            startPerQuestionTimer()
        }
    }

    func selectAnswer(_ answer: String) {
        guard selectedAnswer == nil, let q = current else { return }
        selectedAnswer = answer
        let correct = answer == q.correct
        onAnswer?(q.word.id, correct)
        if correct {
            score += 1
            HapticManager.success()
            advance()
        } else {
            HapticManager.error()
            switch kind {
            case .perfection: finish()
            case .sprint:     advance()
            case .rush:       advance()
            }
        }
    }

    private func advance() {
        switch kind {
        case .perfection:
            if score >= 10 { finish() } else { nextQuestion() }
        case .rush:
            nextQuestion()
        case .sprint:
            // Sprint is exactly 5 questions; the question cap is the sole end condition.
            if questionCount >= 5 {
                finish()
            } else {
                questionCount += 1
                nextQuestion()
            }
        }
    }

    private var questionCount = 1

    /// Picks the next word, avoiding repeats within a round. On pool exhaustion (endless
    /// modes), resets the round without repeating the current word back-to-back.
    private func pickWord() -> Word? {
        var fresh = pool.filter { !asked.contains($0.id) }
        if fresh.isEmpty {
            asked.removeAll()
            fresh = pool.filter { $0.id != current?.word.id }
            if fresh.isEmpty { fresh = pool }
        }
        guard let word = fresh.randomElement() else { return nil }
        asked.insert(word.id)
        return word
    }

    private func startGlobalTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.timeRemaining -= 0.1
                if self.timeRemaining <= 0 { self.finish() }
            }
        }
    }

    private func startPerQuestionTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.timeRemaining -= 0.1
                if self.timeRemaining <= 0 {
                    // Time's up — count as wrong and advance
                    if self.selectedAnswer == nil, let q = self.current {
                        self.onAnswer?(q.word.id, false)
                    }
                    self.advance()
                }
            }
        }
    }

    func finish() {
        timer?.invalidate()
        isFinished = true
    }
}

struct ChallengeView: View {
    @EnvironmentObject var userProfile: UserProfileStore
    @Environment(\.dismiss) private var dismiss
    @StateObject private var vm: ChallengeViewModel
    let kind: ChallengeKind

    init(kind: ChallengeKind, seenIds: Set<UUID>, isPro: Bool) {
        self.kind = kind
        _vm = StateObject(wrappedValue: ChallengeViewModel(
            kind: kind, seenIds: seenIds, isPro: isPro))
    }

    var body: some View {
        NavigationView {
            ZStack {
                AppColors.background.ignoresSafeArea()
                if vm.insufficientWords {
                    InsufficientWordsView(needed: 4) { dismiss() }
                } else if vm.isFinished {
                    finishedView
                } else if let q = vm.current {
                    questionView(q)
                }
            }
            .navigationTitle(kind.title)
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
            vm.onAnswer = { id, correct in
                userProfile.recordReview(id, rating: correct ? .good : .again)
            }
        }
    }

    private var finishedView: some View {
        let highScore = userProfile.profile.challengeHighScores[kind.rawValue] ?? 0
        let newHigh = vm.score > highScore
        return VStack(spacing: AppSpacing.lg) {
            Spacer()
            Image(systemName: kind.icon)
                .font(.system(size: 70))
                .foregroundColor(AppColors.accent)
            Text(newHigh ? "New high score!" : "Challenge complete")
                .font(AppTypography.heroTitle)
                .foregroundColor(AppColors.textPrimary)
            Text("\(vm.score)")
                .font(.system(size: 80, weight: .bold, design: .rounded))
                .foregroundColor(AppColors.accent)
            Text(scoreLabel)
                .font(.system(size: 16))
                .foregroundColor(AppColors.textSecondary)
            if !newHigh && highScore > 0 {
                Text("Best: \(highScore)")
                    .font(.system(size: 13))
                    .foregroundColor(AppColors.textSecondary)
            }
            Spacer()
            PillButton(title: "Done") {
                if newHigh {
                    userProfile.profile.challengeHighScores[kind.rawValue] = vm.score
                }
                dismiss()
            }
            .padding(.horizontal, AppSpacing.lg)
            .padding(.bottom, AppSpacing.xl)
        }
    }

    private var scoreLabel: String {
        switch kind {
        case .perfection: return NSLocalizedString("correct in a row", comment: "challenge score")
        case .rush:       return NSLocalizedString("words in 60 seconds", comment: "challenge score")
        case .sprint:     return NSLocalizedString("of 5 correct", comment: "challenge score")
        }
    }

    private func questionView(_ q: ChallengeViewModel.Question) -> some View {
        VStack(spacing: AppSpacing.lg) {
            // Timer / progress
            timerBar

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
                    Button { vm.selectAnswer(option) } label: {
                        Text(option)
                            .font(.system(size: 15))
                            .foregroundColor(AppColors.textPrimary)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(AppSpacing.md)
                            .background(optionBackground(for: option, q: q))
                            .cornerRadius(AppSpacing.cornerRadius)
                    }
                    .disabled(vm.selectedAnswer != nil)
                }
            }
            .padding(.horizontal, AppSpacing.md)

            Spacer()
        }
    }

    private func optionBackground(for option: String, q: ChallengeViewModel.Question) -> Color {
        guard vm.selectedAnswer != nil else { return AppColors.surface }
        if option == q.correct { return Color.green.opacity(0.25) }
        if option == vm.selectedAnswer { return Color.red.opacity(0.25) }
        return AppColors.surface
    }

    @ViewBuilder
    private var timerBar: some View {
        switch kind {
        case .rush:
            HStack(spacing: AppSpacing.sm) {
                Image(systemName: "bolt.fill")
                    .foregroundColor(AppColors.accent)
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3).fill(AppColors.surface).frame(height: 6)
                        RoundedRectangle(cornerRadius: 3)
                            .fill(vm.timeRemaining < 10 ? .red : AppColors.accent)
                            .frame(width: geo.size.width * max(0, vm.timeRemaining / 60), height: 6)
                            .animation(.linear(duration: 0.1), value: vm.timeRemaining)
                    }
                }
                .frame(height: 6)
                Text("\(Int(vm.timeRemaining))s")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppColors.textPrimary)
                    .frame(width: 36)
                Spacer()
                Text("Score: \(vm.score)")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppColors.accent)
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.top, AppSpacing.md)
        case .sprint:
            HStack(spacing: AppSpacing.sm) {
                Image(systemName: "timer")
                    .foregroundColor(vm.timeRemaining < 2 ? .red : AppColors.accent)
                Text(String(format: "%.1fs", vm.timeRemaining))
                    .font(.system(size: 18, weight: .bold, design: .monospaced))
                    .foregroundColor(vm.timeRemaining < 2 ? .red : AppColors.textPrimary)
                Spacer()
                Text("Q \(min(vm.score + 1, 5)) / 5")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppColors.textSecondary)
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.top, AppSpacing.md)
        case .perfection:
            HStack(spacing: 6) {
                ForEach(0..<10, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(i < vm.score ? AppColors.accent : AppColors.surface)
                        .frame(height: 4)
                }
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.top, AppSpacing.md)
        }
    }
}
