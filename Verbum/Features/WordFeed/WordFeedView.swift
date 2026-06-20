import SwiftUI

struct WordFeedView: View {
    @EnvironmentObject var userProfile: UserProfileStore
    @EnvironmentObject var subscriptions: SubscriptionManager
    @EnvironmentObject var auth: AuthService
    @StateObject private var viewModel = WordFeedViewModel()
    /// HIG: respect Reduce Motion — gates the confetti burst and the repeating swipe-hint bounce.
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private enum ActiveSheet: String, Identifiable {
        case detail, profile, practice, categories, share, stats, premium, leaderboard, search, lexicon
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
    @State private var deepLinkWord: Word?
    /// Word whose personal-note sheet is open (presented after a first claim, or from the Lexicon).
    @State private var noteWord: Word?
    /// Drives the Instagram-style heart burst on a double-tap like.
    @State private var likeBurst = false

    var body: some View {
        ZStack {
            AppColors.background.ignoresSafeArea()

            Color.green
                .opacity(greenFlashOpacity)
                .ignoresSafeArea()
                .allowsHitTesting(false)

            VStack(spacing: 0) {
                topBar
                // Streaks are gameplay — only shown when the user opts into gameplay.
                if userProfile.profile.quizEnabled && showStreakBanner { streakBanner }
                wordArea
                actionRow
                // Bottom nav (Categories/Practice/Ranking/Stats) removed — the feed is now a
                // pure swipe surface. Those live behind the profile → Practice hub.
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

            if showConfetti && !reduceMotion {
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
                    WordShareSheet(word: word)
                }
            case .stats:
                StatsView().environmentObject(userProfile)
            case .premium:
                PremiumSheet().environmentObject(subscriptions)
            case .leaderboard:
                LeaderboardView().environmentObject(userProfile)
            case .search:
                SearchView()
                    .environmentObject(userProfile)
                    .environmentObject(subscriptions)
            case .lexicon:
                LexiconView()
                    .environmentObject(userProfile)
                    .environmentObject(subscriptions)
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
                // Restrict distractors to already-seen words so the batch quiz only practices
                // vocabulary the user has actually been through. The just-swiped batch is
                // already in seenWordIdsSet (markWordSeen runs before this sheet presents).
                seenWordsPool: viewModel.words.filter { seenWordIdsSet.contains($0.id) }
            ) { pts, resurfaceIds in
                userProfile.addPoints(pts)
                // 0/5 quiz → undo the swipe-mark so those words resurface for another pass.
                if !resurfaceIds.isEmpty {
                    userProfile.unmarkWordsSeen(resurfaceIds)
                }
            }
            .environmentObject(userProfile)
        }
        .onAppear {
            // Language is resolved at launch (VerbumApp.init); the feed just reads it.
            seenWordIdsSet = Set(userProfile.profile.seenWordIds)
            viewModel.isPro = subscriptions.isPro
            viewModel.dueReviewIds = userProfile.dueReviews()
            viewModel.seenWordIds = seenWordIdsSet
            viewModel.reloadFromRepository()
            // Cold-launch deep-link: AppDelegate's `didReceive` may have fired before this
            // view's `.onReceive(.openWord)` subscribed — drain the stashed id here.
            if let pendingId = NotificationManager.pendingDeepLinkWordId,
               let word = WordRepository.shared.word(id: pendingId) {
                NotificationManager.pendingDeepLinkWordId = nil
                DispatchQueue.main.async {
                    activeSheet = nil
                    deepLinkWord = word
                }
            }
        }
        // Banner/hint timers live in .task so they're cancelled when the feed disappears —
        // asyncAfter would still fire and flash stale UI after a dismiss.
        .task {
            guard userProfile.profile.currentStreak > 1 else { return }
            showStreakBanner = true
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut) { showStreakBanner = false }
        }
        .task {
            guard !hasSeenSwipeHint else { return }
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            guard !Task.isCancelled else { return }
            withAnimation { showSwipeHint = true }
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            guard !Task.isCancelled else { return }
            withAnimation { showSwipeHint = false }
            hasSeenSwipeHint = true
        }
        .onChange(of: userProfile.profile.seenWordIds) { newValue in
            seenWordIdsSet = Set(newValue)
            viewModel.seenWordIds = seenWordIdsSet
        }
        .onChange(of: subscriptions.isPro) { newValue in
            viewModel.isPro = newValue
            viewModel.seenWordIds = seenWordIdsSet
            viewModel.reloadFromRepository()
        }
        .onChange(of: userProfile.profile.wordLanguage) { _ in
            // Switching the vocabulary language reloads the catalogue in WordRepository;
            // rebuild the feed too, otherwise stale words from the old language get checked
            // against the new language's free pool and all show up "locked".
            viewModel.dueReviewIds = userProfile.dueReviews()
            viewModel.reloadFromRepository()
            seenWordIdsSet = Set(userProfile.profile.seenWordIds)
        }
        .onReceive(NotificationCenter.default.publisher(for: .wordDatabaseInstalled)) { _ in
            viewModel.reloadFromRepository()
        }
        .onReceive(NotificationCenter.default.publisher(for: .openWord)) { note in
            // Deep-link from Spotlight or the widget: open the requested word's detail.
            // Dismiss any sheet already up first, then present on the next runloop — two
            // `.sheet`s competing at the same level (activeSheet + deepLinkWord) would otherwise
            // conflict and one silently fails to present.
            guard let id = note.object as? UUID,
                  let word = WordRepository.shared.word(id: id) else { return }
            activeSheet = nil
            DispatchQueue.main.async { deepLinkWord = word }
        }
        .sheet(item: $deepLinkWord) { word in
            WordDetailView(word: word)
                .environmentObject(userProfile)
                .environmentObject(subscriptions)
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
                    if #available(iOS 18.0, *), !reduceMotion {
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
            .accessibilityLabel("Profile")

            Spacer()

            // The familiar center progress — now tappable: opens My Lexicon (with search inside it).
            Button { activeSheet = .lexicon } label: {
                VStack(spacing: 4) {
                    WordProgressBar(current: viewModel.batchProgress, total: 5)
                    HStack(spacing: 4) {
                        let remaining = viewModel.remainingFreeCount(seenIds: seenWordIdsSet)
                        if !subscriptions.isPro, remaining <= 5, remaining > 0 {
                            Image(systemName: "lock.open.fill")
                                .font(.system(size: 9))
                                .foregroundColor(.orange)
                            Text(String(format: NSLocalizedString("%lld free words left", comment: "free words remaining"), remaining))
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(.orange)
                        } else {
                            Image(systemName: userProfile.wordsLearnedToday >= userProfile.profile.dailyGoal ? "checkmark.circle.fill" : "target")
                                .font(.system(size: 9))
                                .foregroundColor(userProfile.wordsLearnedToday >= userProfile.profile.dailyGoal ? .green : AppColors.textSecondary)
                            Text("\(userProfile.wordsLearnedToday)/\(userProfile.profile.dailyGoal) today")
                                .font(.system(size: 10))
                                .foregroundColor(AppColors.textSecondary)
                            let due = userProfile.dueTodayCount()
                            if due > 0 {
                                Text("· \(due) due")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundColor(AppColors.accent)
                            }
                        }
                    }
                }
                .frame(width: 180)
            }
            .accessibilityLabel("My lexicon and search")

            Spacer()

            // Trailing slot is always 44×44 to keep the header balanced. Free users get
            // the upgrade-CTA crown; Pro users get a subtle "premium active" badge so the
            // layout feels intentional instead of empty.
            if subscriptions.isPro {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 17))
                    .foregroundColor(AppColors.accent.opacity(0.85))
                    .frame(width: 44, height: 44)
                    .background(AppColors.surface)
                    .clipShape(Circle())
                    .accessibilityLabel("Premium active")
            } else {
                Button { activeSheet = .premium } label: {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 17))
                        .foregroundColor(AppColors.accent)
                        .frame(width: 44, height: 44)
                        .background(AppColors.surface)
                        .clipShape(Circle())
                }
            }
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.top, AppSpacing.sm)
    }

    // MARK: - Word Area
    private var wordArea: some View {
        Group {
            if viewModel.isFreePoolExhausted(seenIds: seenWordIdsSet) || viewModel.freePoolIsEmpty() {
                paywallCard
                    .gesture(TapGesture().onEnded { activeSheet = .premium })
            } else if let word = viewModel.currentWord {
                WordCardView(word: word, viewModel: viewModel, seenSet: seenWordIdsSet)
                    .environmentObject(userProfile)
                    .environmentObject(subscriptions)
                    .offset(y: dragOffset * 0.35)
                    .rotation3DEffect(.degrees(Double(dragOffset) * 0.015), axis: (x: 1, y: 0, z: 0))
                    // No implicit animation on dragOffset — it fought with the explicit
                    // withAnimation in onEnded, producing the stutter on release. Live drag
                    // tracks the finger directly; the release animation comes from onEnded.
                    .gesture(swipeGesture)
                    // Instagram-style heart that pops on a double-tap like.
                    .overlay {
                        if likeBurst {
                            Image(systemName: "heart.fill")
                                .font(.system(size: 120))
                                .foregroundColor(.red)
                                .shadow(color: .black.opacity(0.3), radius: 14)
                                .transition(.scale(scale: 0.4).combined(with: .opacity))
                                .allowsHitTesting(false)
                        }
                    }
                    // Double-tap to like (sets a like, never un-likes — like Instagram).
                    .onTapGesture(count: 2) {
                        guard WordAccess.canAccess(word, isPro: subscriptions.isPro) else { return }
                        if !userProfile.profile.likedWordIds.contains(word.id) {
                            userProfile.likeWord(word.id)
                            PublicLikes.service.like(wordID: word.id)   // cross-user (dormant unless backend on)
                        }
                        HapticManager.impact(.soft)
                        triggerLikeBurst()
                    }
                    // Single tap → learn more (replaces the old "i" icon).
                    .onTapGesture {
                        if !WordAccess.canAccess(word, isPro: subscriptions.isPro) {
                            activeSheet = .premium
                        } else {
                            activeSheet = .detail
                        }
                    }
                    // VoiceOver: the swipe feed is gesture-only, so expose the card as one
                    // readable element with explicit Next/Previous actions (in the rotor) — a
                    // blind user can otherwise never advance past the first word.
                    .accessibilityElement(children: .combine)
                    // Never read a locked word's definition aloud — that would leak paid
                    // content past the visual blur. (Latent today since the feed only holds
                    // accessible words, but guards the moment category drill-down is wired in.)
                    .accessibilityLabel(
                        WordAccess.canAccess(word, isPro: subscriptions.isPro)
                            ? "\(word.text), \(word.localizedPartOfSpeech). \(word.definition)"
                            : "\(word.text), locked. Unlock with Verbum Premium."
                    )
                    .accessibilityHint("Double-tap for details")
                    // Mirror the touch swipe path exactly: only access-granted words count as
                    // seen / toward the daily goal, and the goal celebration must fire here too
                    // or VoiceOver users get a different learning loop than sighted users.
                    .accessibilityAction(named: Text("Next word")) {
                        if WordAccess.canAccess(word, isPro: subscriptions.isPro) {
                            let goalJustHit = userProfile.markWordSeen(word.id)
                            if goalJustHit { triggerGoalCelebration() }
                        }
                        if !viewModel.isAtEnd { withAnimation { viewModel.nextWord() } }
                    }
                    .accessibilityAction(named: Text("Previous word")) {
                        if !viewModel.isAtStart { withAnimation { viewModel.previousWord() } }
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

    // MARK: - Paywall card (shown when free pool is exhausted)

    private var paywallCard: some View {
        let lockedCount = WordAccess.lockedCount()
        // Actual free-pool size, not the freeLimit cap — the curated catalogue can be
        // smaller than the 50-word cap, so "all 50" would be a lie.
        let freeCount = WordAccess.freePool().count
        return VStack(spacing: AppSpacing.lg) {
            Image(systemName: "crown.fill")
                .font(.system(size: 56))
                .foregroundColor(AppColors.accent)

            Text(freeCount > 0
                 ? "You learned all \(freeCount) free words 🎉"
                 : "These words are Premium 🔒")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(AppColors.textPrimary)
                .multilineTextAlignment(.center)

            if lockedCount > 0 {
                Text("Unlock \(lockedCount) more words")
                    .font(.system(size: 16))
                    .foregroundColor(AppColors.textSecondary)
                    .multilineTextAlignment(.center)
            } else {
                Text("Go Premium to unlock the rest of the catalog")
                    .font(.system(size: 16))
                    .foregroundColor(AppColors.textSecondary)
                    .multilineTextAlignment(.center)
            }

            if freeCount > 0 {
                Text("Your \(freeCount) words remain free to practice, review, and add to decks — forever.")
                    .font(.system(size: 13))
                    .foregroundColor(AppColors.textSecondary.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AppSpacing.lg)
            }

            PillButton(title: "Get Premium") { activeSheet = .premium }
                .padding(.horizontal, AppSpacing.lg)
                .padding(.top, AppSpacing.sm)
        }
        .padding(AppSpacing.lg)
        .frame(maxWidth: .infinity)
    }

    private var swipeGesture: some Gesture {
        DragGesture()
            .onChanged { dragOffset = $0.translation.height }
            .onEnded { val in
                let threshold: CGFloat = 50
                if val.translation.height < -threshold {
                    HapticManager.swipeWave()
                    if let word = viewModel.currentWord {
                        // Only access-granted words count toward seen / daily goal / batch.
                        if WordAccess.canAccess(word, isPro: subscriptions.isPro) {
                            let goalJustHit = userProfile.markWordSeen(word.id)
                            if goalJustHit { triggerGoalCelebration() }
                        }
                    }
                    resetActionScales()
                    greenFlashOpacity = 0.07
                    withAnimation(.easeOut(duration: 0.4)) { greenFlashOpacity = 0 }
                    if userProfile.profile.quizEnabled && viewModel.isEndOfBatch {
                        // Include the card currently in front — nextWord() hasn't appended it
                        // yet, so without this it's the one word excluded from its own batch.
                        if let w = viewModel.currentWord,
                           WordAccess.canAccess(w, isPro: subscriptions.isPro) {
                            viewModel.addToBatch(w)
                        }
                        // Quiz first — even on the last word of the feed
                        pendingNextWord = !viewModel.isAtEnd
                        showBatchQuiz = true
                    } else if viewModel.isAtEnd {
                        withAnimation(.spring()) { showEndOfFeed = true }
                    } else {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.75, blendDuration: 0)) { viewModel.nextWord() }
                        // Heads-up that a quiz comes after the next word — only when quiz is on.
                        if userProfile.profile.quizEnabled && viewModel.swipesSinceLastQuiz == 3 {
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

    /// Pops the double-tap heart, then fades it out.
    private func triggerLikeBurst() {
        withAnimation(.spring(response: 0.28, dampingFraction: 0.55)) { likeBurst = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
            withAnimation(.easeOut(duration: 0.3)) { likeBurst = false }
        }
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
            // Only two actions now: Save (claim into lexicon) and Share. Info moved to a single
            // tap on the word; like is a double-tap on the card (see wordArea).
            HStack(spacing: 64) {
                FeedActionButton(
                    icon: userProfile.isClaimed(word.id) ? "bookmark.fill" : "bookmark",
                    label: "Save",
                    active: userProfile.isClaimed(word.id),
                    scale: bookmarkScale
                ) {
                    HapticManager.impact(.medium)
                    let wasClaimed = userProfile.isClaimed(word.id)
                    userProfile.claimWord(word.id)
                    bookmarkScale = 1.4
                    withAnimation(.interpolatingSpring(stiffness: 400, damping: 10)) { bookmarkScale = 1.0 }
                    // First claim → invite a personal note ("why this word is mine"); optional.
                    if !wasClaimed {
                        Analytics.log(.wordClaimed)
                        noteWord = word
                    }
                }
                .accessibilityLabel(userProfile.isClaimed(word.id) ? "Remove from lexicon" : "Claim into lexicon")

                FeedActionButton(icon: "square.and.arrow.up", label: "Share", active: false, scale: 1) {
                    // Free users can only share words they actually have access to.
                    if WordAccess.canAccess(word, isPro: subscriptions.isPro) {
                        Analytics.log(.cardShared, ["from": "feed"])
                        activeSheet = .share
                    } else {
                        activeSheet = .premium
                    }
                }
                .accessibilityLabel("Share word")
            }
            .padding(.vertical, AppSpacing.md)
            .sheet(item: $noteWord) { w in
                LexiconNoteSheet(word: w).environmentObject(userProfile)
            }
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

// MARK: - Feed action button (Save / Share)
private struct FeedActionButton: View {
    let icon: String
    let label: String
    let active: Bool
    var scale: CGFloat = 1
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(active ? AppColors.accent : AppColors.textPrimary)
                    .frame(width: 54, height: 54)
                    .background(AppColors.surface)
                    .clipShape(Circle())
                    .scaleEffect(scale)
                Text(label)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(AppColors.textSecondary)
            }
        }
    }
}

// MARK: - Word Card
private struct WordCardView: View {
    let word: Word
    let viewModel: WordFeedViewModel
    let seenSet: Set<UUID>
    @EnvironmentObject var userProfile: UserProfileStore
    @EnvironmentObject var subscriptions: SubscriptionManager
    // The main reading surface scales with Dynamic Type (keeps the base size at default settings,
    // grows for larger accessibility text) instead of being pinned in points.
    @ScaledMetric(relativeTo: .largeTitle) private var wordTitleSize: CGFloat = 40
    @ScaledMetric(relativeTo: .body) private var definitionSize: CGFloat = 18
    // At accessibility text sizes a 3-line definition / 2-line example clips. Lift the caps so
    // the reading surface stays fully legible (it already grows via @ScaledMetric); keep the caps
    // at normal sizes so the card layout stays tidy.
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var isLocked: Bool {
        !WordAccess.canAccess(word, isPro: subscriptions.isPro)
    }

    var body: some View {
        ZStack {
            cardContent
                .blur(radius: isLocked ? 10 : 0)
                .allowsHitTesting(!isLocked)

            if isLocked {
                let lockedCount = WordAccess.lockedCount()
                VStack(spacing: AppSpacing.sm) {
                    Text(String(word.text.prefix(3)) + "…")
                        .font(.system(size: 34, weight: .bold))
                        .foregroundColor(AppColors.textPrimary)
                    Text("This word has a fascinating history")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(AppColors.textPrimary)
                        .multilineTextAlignment(.center)
                    Text(lockedCount > 0
                         ? "Tap to unlock \(lockedCount) more words →"
                         : "Tap to unlock Premium →")
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
            } else {
                let mastery = userProfile.mastery(for: word.id)
                if mastery > 0 {
                    HStack(spacing: 4) {
                        ForEach(0..<5, id: \.self) { i in
                            Circle()
                                .fill(i < mastery ? AppColors.accent : AppColors.surfaceSecondary)
                                .frame(width: 7, height: 7)
                        }
                        if mastery == 5 {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 11))
                                .foregroundColor(AppColors.accent)
                        }
                    }
                }
            }

            Text(word.text)
                .font(.system(size: wordTitleSize, weight: .bold, design: .serif))
                .foregroundColor(AppColors.textPrimary)

            HStack(spacing: AppSpacing.sm) {
                // Phonetic is optional (e.g. Ukrainian has no IPA) — omit the empty pill.
                if !word.phonetic.isEmpty {
                    Text(word.phonetic)
                        .font(AppTypography.phonetic)
                        .foregroundColor(AppColors.textSecondary)
                        .padding(.horizontal, AppSpacing.sm)
                        .padding(.vertical, 4)
                        .background(AppColors.surface)
                        .cornerRadius(20)
                }

                Button { viewModel.speakWord(word.text) } label: {
                    Image(systemName: "speaker.wave.2")
                        .foregroundColor(AppColors.textSecondary)
                }
                .accessibilityLabel("Pronounce \(word.text)")
            }

            // Cross-user likes, visible right on the card. Placeholder count until VERBUM_BACKEND
            // is live; the heart fills red when *you* like it (double-tap the card).
            HStack(spacing: 5) {
                let liked = userProfile.profile.likedWordIds.contains(word.id)
                Image(systemName: liked ? "heart.fill" : "heart")
                    .font(.system(size: 14))
                    .foregroundColor(.red)
                Text(WordLikeDisplay.formatted(WordLikeDisplay.placeholderCount(for: word) + (liked ? 1 : 0)))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(AppColors.textSecondary)
            }
            .accessibilityLabel("\(WordLikeDisplay.placeholderCount(for: word)) likes")

            Text("\(word.abbreviatedPartOfSpeech) \(word.definition)")
                .font(.system(size: definitionSize, weight: .regular))
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, AppSpacing.xl)
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 3)

            if let example = word.exampleSentence {
                Text("\u{201C}\(example)\u{201D}")
                    .font(.system(size: 13).italic())
                    .foregroundColor(AppColors.textSecondary.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AppSpacing.xl)
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
            }

            if let etymology = word.etymology {
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
