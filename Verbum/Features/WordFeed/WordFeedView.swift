import SwiftUI

struct WordFeedView: View {
    @EnvironmentObject var userProfile: UserProfileStore
    @EnvironmentObject var subscriptions: SubscriptionManager
    @EnvironmentObject var auth: AuthService
    @StateObject private var viewModel = WordFeedViewModel()

    private enum ActiveSheet: String, Identifiable {
        case detail, profile, practice, categories, share, stats, premium, leaderboard
        var id: RawValue { rawValue }
    }

    @State private var activeSheet: ActiveSheet?
    @State private var showBatchQuiz = false
    @State private var dragOffset: CGFloat = 0
    @State private var likeScale: CGFloat = 1.0
    @State private var bookmarkScale: CGFloat = 1.0
    @State private var showStreakBanner = false
    @AppStorage("hasSeenSwipeHint") private var hasSeenSwipeHint = false
    @State private var showSwipeHint = false
    @State private var showEndOfFeed = false
    @State private var pendingNextWord = false
    @State private var greenFlashOpacity: Double = 0
    @State private var seenWordIdsSet: Set<UUID> = []
    @State private var showQuizToast = false
    @State private var showConfetti = false
    @State private var showGoalToast = false

    var body: some View {
        ZStack {
            AppColors.background.ignoresSafeArea()

            Color.green
                .opacity(greenFlashOpacity)
                .ignoresSafeArea()
                .allowsHitTesting(false)

            VStack(spacing: 0) {
                topBar
                if showStreakBanner { streakBanner }
                wordArea
                actionRow
                bottomNav
            }

            if showQuizToast {
                quizToast
            }

            if showGoalToast {
                goalToast
            }

            if showSwipeHint {
                swipeHint
            }

            if showEndOfFeed {
                endOfFeedOverlay
            }

            if showConfetti {
                ConfettiView()
                    .ignoresSafeArea()
            }
        }
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .detail:
                if let word = viewModel.currentWord {
                    WordDetailView(word: word).environmentObject(userProfile)
                }
            case .profile:
                ProfileView().environmentObject(userProfile).environmentObject(subscriptions).environmentObject(auth)
            case .practice:
                PracticeMenuView().environmentObject(userProfile).environmentObject(subscriptions)
            case .categories:
                CategoriesView().environmentObject(userProfile).environmentObject(subscriptions)
            case .share:
                if let word = viewModel.currentWord {
                    ShareSheet(items: ["\(word.text) — \(word.definition)\n\nLearn more with Verbum app."])
                }
            case .stats:
                StatsView().environmentObject(userProfile)
            case .premium:
                PremiumSheet().environmentObject(subscriptions)
            case .leaderboard:
                LeaderboardView().environmentObject(userProfile)
            }
        }
        .sheet(isPresented: $showBatchQuiz, onDismiss: {
            viewModel.resetBatchCounter()
            if pendingNextWord {
                pendingNextWord = false
                withAnimation(.spring(response: 0.35, dampingFraction: 0.75, blendDuration: 0)) { viewModel.nextWord() }
            } else if viewModel.isAtEnd {
                withAnimation(.spring()) { showEndOfFeed = true }
            }
        }) {
            BatchQuizView(
                words: viewModel.currentBatchWords,
                allWords: viewModel.words
            ) { pts in
                userProfile.addPoints(pts)
            }
            .environmentObject(userProfile)
        }
        .onAppear {
            seenWordIdsSet = Set(userProfile.profile.seenWordIds)
            viewModel.isPro = subscriptions.isPro
            viewModel.reloadFromRepository()
            if userProfile.profile.currentStreak > 1 {
                showStreakBanner = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                    withAnimation(.easeOut) { showStreakBanner = false }
                }
            }
            if !hasSeenSwipeHint {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                    withAnimation { showSwipeHint = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        withAnimation { showSwipeHint = false }
                        hasSeenSwipeHint = true
                    }
                }
            }
        }
        .onChange(of: userProfile.profile.seenWordIds) { newValue in
            seenWordIdsSet = Set(newValue)
        }
        .onChange(of: subscriptions.isPro) { newValue in
            viewModel.isPro = newValue
            viewModel.reloadFromRepository()
        }
        .onReceive(NotificationCenter.default.publisher(for: .wordDatabaseInstalled)) { _ in
            viewModel.reloadFromRepository()
        }
    }

    // MARK: - Quiz Toast

    private var quizToast: some View {
        VStack {
            Text("Quiz after next word! 🧠")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(AppColors.textOnAccent)
                .padding(.horizontal, AppSpacing.md)
                .padding(.vertical, AppSpacing.sm)
                .background(AppColors.accent.opacity(0.92))
                .clipShape(Capsule())
                .shadow(color: .black.opacity(0.2), radius: 8, y: 2)
            Spacer()
        }
        .padding(.top, AppSpacing.sm)
        .transition(.move(edge: .top).combined(with: .opacity))
        .allowsHitTesting(false)
    }

    // MARK: - Streak Banner
    private var streakBanner: some View {
        HStack(spacing: AppSpacing.sm) {
            Text("🔥")
                .font(.system(size: 20))
            Text("\(userProfile.profile.currentStreak) day streak! Keep it up!")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(AppColors.textOnAccent)
            Spacer()
            Button {
                activeSheet = .leaderboard
                withAnimation(.easeOut) { showStreakBanner = false }
            } label: {
                Text("View Progress")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(AppColors.textOnAccent)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.black.opacity(0.2))
                    .cornerRadius(6)
            }
            Button { withAnimation(.easeOut) { showStreakBanner = false } } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(AppColors.textOnAccent.opacity(0.7))
            }
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, AppSpacing.sm)
        .background(Color.orange)
        .transition(.move(edge: .top).combined(with: .opacity))
        .gesture(
            DragGesture(minimumDistance: 10)
                .onEnded { val in
                    if val.translation.height < -10 {
                        withAnimation(.easeOut) { showStreakBanner = false }
                    }
                }
        )
    }

    // MARK: - Swipe Hint Overlay
    private var swipeHint: some View {
        VStack {
            Spacer()
            VStack(spacing: AppSpacing.sm) {
                Group {
                    if #available(iOS 18.0, *) {
                        Image(systemName: "chevron.up")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(AppColors.accent)
                            .symbolEffect(.bounce, options: .repeating)
                    } else {
                        Image(systemName: "chevron.up")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(AppColors.accent)
                    }
                }
                Text("Swipe up for the next word")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(AppColors.textPrimary)
            }
            .padding(.vertical, AppSpacing.md)
            .padding(.horizontal, AppSpacing.xl)
            .background(.ultraThinMaterial)
            .cornerRadius(AppSpacing.cornerRadius)
            .shadow(color: .black.opacity(0.3), radius: 12, y: 4)
            .padding(.bottom, 120)
        }
        .transition(.opacity.combined(with: .scale))
    }

    // MARK: - End of Feed Overlay
    private var endOfFeedOverlay: some View {
        ZStack {
            AppColors.background.opacity(0.95).ignoresSafeArea()
            VStack(spacing: AppSpacing.lg) {
                Text("🎉")
                    .font(.system(size: 64))
                Text("All caught up!")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(AppColors.textPrimary)
                Text("You've seen all \(viewModel.words.count) words.\nReady for another round?")
                    .font(.system(size: 16))
                    .foregroundColor(AppColors.textSecondary)
                    .multilineTextAlignment(.center)
                VStack(spacing: AppSpacing.sm) {
                    Button {
                        withAnimation(.easeInOut(duration: 0.3)) { showEndOfFeed = false }
                        viewModel.restartFeed()
                    } label: {
                        Text("Restart Feed")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(AppColors.textOnAccent)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, AppSpacing.md)
                            .background(AppColors.accent)
                            .cornerRadius(AppSpacing.pillRadius)
                    }
                    Button {
                        withAnimation(.easeInOut(duration: 0.3)) { showEndOfFeed = false }
                        activeSheet = .practice
                    } label: {
                        Text("Go to Practice")
                            .font(.system(size: 17, weight: .medium))
                            .foregroundColor(AppColors.accent)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, AppSpacing.md)
                            .background(AppColors.surface)
                            .cornerRadius(AppSpacing.pillRadius)
                    }
                }
                .padding(.horizontal, AppSpacing.xl)
            }
            .padding(AppSpacing.xl)
        }
        .transition(.opacity.combined(with: .scale))
    }

    // MARK: - Top Bar
    private var topBar: some View {
        HStack {
            Button { activeSheet = .profile } label: {
                Image(systemName: "person.fill")
                    .font(.system(size: 17))
                    .foregroundColor(AppColors.textPrimary)
                    .frame(width: 44, height: 44)
                    .background(AppColors.surface)
                    .clipShape(Circle())
            }

            Spacer()

            VStack(spacing: 4) {
                WordProgressBar(
                    current: viewModel.batchProgress,
                    total: 5
                )
                HStack(spacing: 4) {
                    Image(systemName: userProfile.wordsLearnedToday >= userProfile.profile.dailyGoal ? "checkmark.circle.fill" : "target")
                        .font(.system(size: 9))
                        .foregroundColor(userProfile.wordsLearnedToday >= userProfile.profile.dailyGoal ? .green : AppColors.textSecondary)
                    Text("\(userProfile.wordsLearnedToday)/\(userProfile.profile.dailyGoal) today")
                        .font(.system(size: 10))
                        .foregroundColor(AppColors.textSecondary)
                }
            }
            .frame(width: 130)

            Spacer()

            Button { activeSheet = .premium } label: {
                Image(systemName: "crown.fill")
                    .font(.system(size: 17))
                    .foregroundColor(AppColors.accent)
                    .frame(width: 44, height: 44)
                    .background(AppColors.surface)
                    .clipShape(Circle())
            }
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.top, AppSpacing.sm)
    }

    // MARK: - Word Area
    private var wordArea: some View {
        Group {
            if let word = viewModel.currentWord {
                WordCardView(word: word, viewModel: viewModel, seenSet: seenWordIdsSet)
                    .environmentObject(userProfile)
                    .environmentObject(subscriptions)
                    .offset(y: dragOffset * 0.35)
                    .rotation3DEffect(.degrees(Double(dragOffset) * 0.015), axis: (x: 1, y: 0, z: 0))
                    .animation(.interactiveSpring(), value: dragOffset)
                    .gesture(swipeGesture)
                    .onTapGesture {
                        if !subscriptions.isPro && word.level != .beginner {
                            activeSheet = .premium
                        } else {
                            activeSheet = .detail
                        }
                    }
                    .id(viewModel.currentIndex)
                    .transition(.asymmetric(
                        insertion: .move(edge: viewModel.goingBack ? .top : .bottom).combined(with: .opacity),
                        removal: .move(edge: viewModel.goingBack ? .bottom : .top).combined(with: .opacity)
                    ))
            } else {
                SkeletonWordCard()
            }
        }
    }

    private var swipeGesture: some Gesture {
        DragGesture()
            .onChanged { dragOffset = $0.translation.height }
            .onEnded { val in
                let threshold: CGFloat = 50
                if val.translation.height < -threshold {
                    HapticManager.swipeWave()
                    if let word = viewModel.currentWord {
                        let goalJustHit = userProfile.markWordSeen(word.id)
                        if goalJustHit { triggerGoalCelebration() }
                    }
                    resetActionScales()
                    greenFlashOpacity = 0.07
                    withAnimation(.easeOut(duration: 0.4)) { greenFlashOpacity = 0 }
                    if viewModel.isEndOfBatch {
                        // Quiz first — even on the last word of the feed
                        pendingNextWord = !viewModel.isAtEnd
                        showBatchQuiz = true
                    } else if viewModel.isAtEnd {
                        withAnimation(.spring()) { showEndOfFeed = true }
                    } else {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.75, blendDuration: 0)) { viewModel.nextWord() }
                        if viewModel.swipesSinceLastQuiz == 3 {
                            withAnimation { showQuizToast = true }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                withAnimation { showQuizToast = false }
                            }
                        }
                    }
                } else if val.translation.height > threshold {
                    if viewModel.isAtStart {
                        HapticManager.error()
                    } else {
                        HapticManager.swipeWave()
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.75, blendDuration: 0)) { viewModel.previousWord() }
                        resetActionScales()
                    }
                }
                withAnimation(.easeOut(duration: 0.2)) { dragOffset = 0 }
            }
    }

    private func resetActionScales() {
        likeScale = 1.0
        bookmarkScale = 1.0
    }

    /// Triggers confetti + toast + haptic for hitting the daily goal.
    private func triggerGoalCelebration() {
        HapticManager.correctAnswer()
        SoundManager.shared.playCorrectChime()
        withAnimation(.easeOut(duration: 0.2)) {
            showConfetti = true
            showGoalToast = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            withAnimation { showConfetti = false }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            withAnimation { showGoalToast = false }
        }
    }

    private var goalToast: some View {
        VStack {
            HStack(spacing: AppSpacing.sm) {
                Text("🎯")
                    .font(.system(size: 20))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Daily goal reached!")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(AppColors.textPrimary)
                    Text("\(userProfile.profile.dailyGoal) words learned today")
                        .font(.system(size: 12))
                        .foregroundColor(AppColors.textSecondary)
                }
            }
            .padding(AppSpacing.md)
            .background(AppColors.surface)
            .cornerRadius(AppSpacing.cornerRadius)
            .shadow(color: .black.opacity(0.3), radius: 8, y: 4)
            .padding(.top, 60)
            Spacer()
        }
        .transition(.move(edge: .top).combined(with: .opacity))
        .allowsHitTesting(false)
    }

    // MARK: - Action Row
    @ViewBuilder
    private var actionRow: some View {
        if let word = viewModel.currentWord {
            HStack(spacing: AppSpacing.xl) {
                Button { activeSheet = .detail } label: {
                    Image(systemName: "info.circle")
                        .actionIcon()
                }
                Button { activeSheet = .share } label: {
                    Image(systemName: "square.and.arrow.up")
                        .actionIcon()
                }
                Button {
                    HapticManager.impact(.soft)
                    userProfile.likeWord(word.id)
                    likeScale = 1.4
                    withAnimation(.interpolatingSpring(stiffness: 400, damping: 10)) { likeScale = 1.0 }
                } label: {
                    Image(systemName: userProfile.profile.likedWordIds.contains(word.id) ? "heart.fill" : "heart")
                        .font(.system(size: 22))
                        .foregroundColor(userProfile.profile.likedWordIds.contains(word.id) ? .red : AppColors.textSecondary)
                        .scaleEffect(likeScale)
                }
                Button {
                    HapticManager.impact(.medium)
                    userProfile.bookmarkWord(word.id)
                    bookmarkScale = 1.4
                    withAnimation(.interpolatingSpring(stiffness: 400, damping: 10)) { bookmarkScale = 1.0 }
                } label: {
                    Image(systemName: userProfile.profile.bookmarkedWordIds.contains(word.id) ? "bookmark.fill" : "bookmark")
                        .font(.system(size: 22))
                        .foregroundColor(userProfile.profile.bookmarkedWordIds.contains(word.id) ? AppColors.accent : AppColors.textSecondary)
                        .scaleEffect(bookmarkScale)
                }
            }
            .padding(.vertical, AppSpacing.md)
        }
    }

    // MARK: - Bottom Nav
    private var bottomNav: some View {
        HStack {
            Spacer()
            BottomNavButton(icon: "square.grid.2x2", label: "Categories") { activeSheet = .categories }
            Spacer()
            BottomNavButton(icon: "graduationcap", label: "Practice") { activeSheet = .practice }
            Spacer()
            BottomNavButton(icon: "trophy", label: "Ranking") { activeSheet = .leaderboard }
            Spacer()
            BottomNavButton(icon: "chart.bar", label: "Stats") { activeSheet = .stats }
            Spacer()
        }
        .padding(.bottom, AppSpacing.lg)
    }
}

// MARK: - Word Card
private struct WordCardView: View {
    let word: Word
    let viewModel: WordFeedViewModel
    let seenSet: Set<UUID>
    @EnvironmentObject var userProfile: UserProfileStore
    @EnvironmentObject var subscriptions: SubscriptionManager
    @State private var translatedDef: String? = nil

    private var isLocked: Bool { !subscriptions.isPro && word.level != .beginner }

    var body: some View {
        ZStack {
            cardContent
                .blur(radius: isLocked ? 10 : 0)
                .allowsHitTesting(!isLocked)

            if isLocked {
                VStack(spacing: AppSpacing.sm) {
                    Text(String(word.text.prefix(3)) + "…")
                        .font(.system(size: 34, weight: .bold))
                        .foregroundColor(AppColors.textPrimary)
                    Text("This word has a fascinating history")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(AppColors.textPrimary)
                        .multilineTextAlignment(.center)
                    Text("Tap to unlock all 1,000 words →")
                        .font(.system(size: 12))
                        .foregroundColor(AppColors.accent)
                }
                .padding(AppSpacing.xl)
                .background(.ultraThinMaterial)
                .cornerRadius(AppSpacing.cornerRadius)
                .shadow(color: .black.opacity(0.25), radius: 12, y: 4)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var cardContent: some View {
        VStack(spacing: AppSpacing.sm) {
            Spacer()

            if word.isNew(for: seenSet) {
                Text("NEW")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(AppColors.textOnAccent)
                    .padding(.horizontal, AppSpacing.sm)
                    .padding(.vertical, 4)
                    .background(AppColors.accent)
                    .cornerRadius(8)
            }

            Text(word.text)
                .font(AppTypography.wordTitle)
                .foregroundColor(AppColors.textPrimary)

            HStack(spacing: AppSpacing.sm) {
                Text(word.phonetic)
                    .font(AppTypography.phonetic)
                    .foregroundColor(AppColors.textSecondary)
                    .padding(.horizontal, AppSpacing.sm)
                    .padding(.vertical, 4)
                    .background(AppColors.surface)
                    .cornerRadius(20)

                Button { viewModel.speakWord(word.text) } label: {
                    Image(systemName: "speaker.wave.2")
                        .foregroundColor(AppColors.textSecondary)
                }
            }

            Text("\(word.partOfSpeech)  \(word.definition)")
                .font(AppTypography.definition)
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, AppSpacing.xl)
                .lineLimit(3)

            if let t = translatedDef, word.level == .beginner {
                Text(t)
                    .font(AppTypography.definition)
                    .foregroundColor(AppColors.textSecondary.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AppSpacing.xl)
                    .lineLimit(2)
            }

            if let example = word.exampleSentence {
                Text("\u{201C}\(example)\u{201D}")
                    .font(.system(size: 13).italic())
                    .foregroundColor(AppColors.textSecondary.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AppSpacing.xl)
                    .lineLimit(2)
            }

            if word.level != .beginner, let etymology = word.etymology {
                HStack(spacing: 4) {
                    Image(systemName: "book.closed")
                        .font(.system(size: 10))
                        .foregroundColor(AppColors.textSecondary.opacity(0.55))
                    Text(etymology)
                        .font(.system(size: 11))
                        .foregroundColor(AppColors.textSecondary.opacity(0.55))
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, AppSpacing.xl)
            }

            Spacer()
        }
        .onAppear {
            if word.level == .beginner,
               let lang = userProfile.profile.nativeLanguage?.rawValue,
               lang != "en" {
                translatedDef = WordDatabase.shared.translation(wordId: word.id, lang: lang)?.definition
            }
        }
    }
}

// MARK: - Bottom Nav Button
private struct BottomNavButton: View {
    let icon: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 22))
                    .foregroundColor(AppColors.textSecondary)
                Text(label)
                    .font(.system(size: 10))
                    .foregroundColor(AppColors.textSecondary)
            }
        }
    }
}

// MARK: - Helpers
private extension Image {
    func actionIcon() -> some View {
        self.font(.system(size: 22)).foregroundColor(AppColors.textSecondary)
    }
}

// MARK: - Skeleton Loading

private struct SkeletonWordCard: View {
    var body: some View {
        VStack(spacing: AppSpacing.md) {
            Spacer()
            ShimmerBlock(width: 80,  height: 14, radius: 6)
            ShimmerBlock(width: 200, height: 44, radius: 14)
            ShimmerBlock(width: 90,  height: 14, radius: 6)
            ShimmerBlock(width: 260, height: 14, radius: 6)
            ShimmerBlock(width: 220, height: 14, radius: 6)
            ShimmerBlock(width: 180, height: 12, radius: 6)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}

private struct ShimmerBlock: View {
    let width: CGFloat
    let height: CGFloat
    let radius: CGFloat
    @State private var animating = false

    var body: some View {
        LinearGradient(
            colors: [AppColors.surface, AppColors.surface.opacity(0.3), AppColors.surface],
            startPoint: .init(x: animating ? 1.5 : -0.5, y: 0.5),
            endPoint:   .init(x: animating ? 2.5 :  0.5, y: 0.5)
        )
        .frame(width: width, height: height)
        .cornerRadius(radius)
        .onAppear {
            withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: false)) {
                animating = true
            }
        }
    }
}

// MARK: - Share Sheet
import UIKit

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}
