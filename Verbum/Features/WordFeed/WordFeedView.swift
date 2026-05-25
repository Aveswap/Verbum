import SwiftUI

struct WordFeedView: View {
    @EnvironmentObject var userProfile: UserProfileStore
    @StateObject private var viewModel = WordFeedViewModel()

    @State private var showDetail = false
    @State private var showProfile = false
    @State private var showPractice = false
    @State private var showCategories = false
    @State private var dragOffset: CGFloat = 0
    @State private var likeScale: CGFloat = 1.0
    @State private var bookmarkScale: CGFloat = 1.0
    @State private var showShareSheet = false
    @State private var showStats = false
    @State private var showLeaderboard = false
    @State private var showStreakBanner = false
    @State private var showPremium = false
    @AppStorage("hasSeenSwipeHint") private var hasSeenSwipeHint = false
    @State private var showSwipeHint = false
    @State private var showEndOfFeed = false
    @State private var showBatchQuiz = false
    @State private var pendingNextWord = false
    @State private var greenFlashOpacity: Double = 0

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

            if showSwipeHint {
                swipeHint
            }

            if showEndOfFeed {
                endOfFeedOverlay
            }
        }
        .sheet(isPresented: $showDetail) {
            if let word = viewModel.currentWord {
                WordDetailView(word: word).environmentObject(userProfile)
            }
        }
        .sheet(isPresented: $showProfile) {
            ProfileView().environmentObject(userProfile)
        }
        .sheet(isPresented: $showPractice) {
            PracticeMenuView().environmentObject(userProfile)
        }
        .sheet(isPresented: $showCategories) {
            CategoriesView().environmentObject(userProfile)
        }
        .sheet(isPresented: $showShareSheet) {
            if let word = viewModel.currentWord {
                ShareSheet(items: ["\(word.text) — \(word.definition)\n\nLearn more with Verbum app."])
            }
        }
        .sheet(isPresented: $showStats) {
            StatsView().environmentObject(userProfile)
        }
        .sheet(isPresented: $showPremium) { PremiumSheet() }
        .sheet(isPresented: $showLeaderboard) {
            LeaderboardView().environmentObject(userProfile)
        }
        .sheet(isPresented: $showBatchQuiz, onDismiss: {
            if pendingNextWord {
                pendingNextWord = false
                withAnimation(.easeInOut(duration: 0.25)) { viewModel.nextWord() }
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
            if userProfile.profile.currentStreak > 1 {
                showStreakBanner = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
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
            Button { withAnimation { showStreakBanner = false } } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(AppColors.textOnAccent.opacity(0.7))
            }
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, AppSpacing.sm)
        .background(Color.orange)
        .transition(.move(edge: .top).combined(with: .opacity))
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
                        showPractice = true
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
            Button { showProfile = true } label: {
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
                Text("\(viewModel.currentIndex + 1) of \(viewModel.words.count)")
                    .font(.system(size: 10))
                    .foregroundColor(AppColors.textSecondary)
            }
            .frame(width: 130)

            Spacer()

            Button { showPremium = true } label: {
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
                WordCardView(word: word, viewModel: viewModel)
                    .environmentObject(userProfile)
                    .offset(y: dragOffset * 0.08)
                    .animation(.interactiveSpring(), value: dragOffset)
                    .gesture(swipeGesture)
                    .onTapGesture { showDetail = true }
                    .id(viewModel.currentIndex)
                    .transition(.asymmetric(
                        insertion: .move(edge: viewModel.goingBack ? .top : .bottom).combined(with: .opacity),
                        removal: .move(edge: viewModel.goingBack ? .bottom : .top).combined(with: .opacity)
                    ))
            } else {
                VStack {
                    Spacer()
                    ProgressView()
                        .tint(AppColors.accent)
                    Text("Loading words…")
                        .foregroundColor(AppColors.textSecondary)
                        .padding(.top, AppSpacing.sm)
                    Spacer()
                }
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
                    if let word = viewModel.currentWord { userProfile.markWordSeen(word.id) }
                    resetActionScales()
                    greenFlashOpacity = 0.18
                    withAnimation(.easeOut(duration: 0.5)) { greenFlashOpacity = 0 }
                    if viewModel.isEndOfBatch {
                        // Quiz first — even on the last word of the feed
                        pendingNextWord = !viewModel.isAtEnd
                        showBatchQuiz = true
                    } else if viewModel.isAtEnd {
                        withAnimation(.spring()) { showEndOfFeed = true }
                    } else {
                        withAnimation(.easeInOut(duration: 0.25)) { viewModel.nextWord() }
                    }
                } else if val.translation.height > threshold {
                    if viewModel.isAtStart {
                        HapticManager.error()
                    } else {
                        HapticManager.swipeWave()
                        withAnimation(.easeInOut(duration: 0.25)) { viewModel.previousWord() }
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

    // MARK: - Action Row
    @ViewBuilder
    private var actionRow: some View {
        if let word = viewModel.currentWord {
            HStack(spacing: AppSpacing.xl) {
                Button { showDetail = true } label: {
                    Image(systemName: "info.circle")
                        .actionIcon()
                }
                Button { showShareSheet = true } label: {
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
            BottomNavButton(icon: "square.grid.2x2", label: "Categories") { showCategories = true }
            Spacer()
            BottomNavButton(icon: "graduationcap", label: "Practice") { showPractice = true }
            Spacer()
            BottomNavButton(icon: "trophy", label: "Ranking") { showLeaderboard = true }
            Spacer()
            BottomNavButton(icon: "chart.bar", label: "Stats") { showStats = true }
            Spacer()
        }
        .padding(.bottom, AppSpacing.lg)
    }
}

// MARK: - Word Card
private struct WordCardView: View {
    let word: Word
    let viewModel: WordFeedViewModel
    @EnvironmentObject var userProfile: UserProfileStore

    var body: some View {
        VStack(spacing: AppSpacing.sm) {
            Spacer()

            if word.isNew {
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

            if let example = word.exampleSentence {
                Text("\u{201C}\(example)\u{201D}")
                    .font(.system(size: 13).italic())
                    .foregroundColor(AppColors.textSecondary.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AppSpacing.xl)
                    .lineLimit(2)
            }

            if word.level == .expert, let etymology = word.etymology {
                HStack(spacing: 4) {
                    Text("📜")
                        .font(.system(size: 10))
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
        .frame(maxWidth: .infinity)
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

// MARK: - Share Sheet
import UIKit

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}
