import SwiftUI

struct PracticeMenuView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var userProfile: UserProfileStore
    @EnvironmentObject var subscriptions: SubscriptionManager
    @State private var showQuiz = false
    @State private var showFillGap = false
    @State private var showSynonyms = false
    @State private var showGuessWord = false
    @State private var showPremium = false
    @State private var activeChallenge: ChallengeKind?

    private var gamesRemaining: Int { userProfile.practiceGamesRemaining() }
    private var canPlay: Bool { subscriptions.isPro || gamesRemaining > 0 }

    private func startGame(_ action: @escaping () -> Void) {
        guard canPlay else { showPremium = true; return }
        if !subscriptions.isPro { userProfile.recordPracticeGame() }
        action()
    }

    var body: some View {
        NavigationView {
            ZStack {
                AppColors.background.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: AppSpacing.lg) {
                        // Challenges
                        sectionHeader("CHALLENGES")
                        // Bleed past the parent VStack's horizontal padding so the trailing
                        // card has breathing room before the ScrollView clips — fixes the
                        // squared-off right edge on the last card.
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: AppSpacing.sm) {
                                ForEach(ChallengeKind.allCases) { kind in
                                    let high = userProfile.profile.challengeHighScores[kind.rawValue] ?? 0
                                    Button {
                                        startGame { activeChallenge = kind }
                                    } label: {
                                        ChallengeCard(kind: kind, highScore: high, isLocked: !canPlay)
                                    }
                                }
                            }
                            .padding(.horizontal, AppSpacing.md)
                        }
                        .padding(.horizontal, -AppSpacing.md)

                        // Daily limit banner (free users only)
                        if !subscriptions.isPro {
                            HStack {
                                Image(systemName: canPlay ? "gamecontroller" : "lock.fill")
                                    .foregroundColor(canPlay ? AppColors.accent : AppColors.locked)
                                    .font(.system(size: 15))
                                if canPlay {
                                    Text("\(gamesRemaining) of \(UserProfile.freePracticeLimit) sessions left today")
                                        .font(.system(size: 13))
                                        .foregroundColor(AppColors.textSecondary)
                                } else {
                                    Text("Daily limit reached · Resets at midnight")
                                        .font(.system(size: 13))
                                        .foregroundColor(AppColors.textSecondary)
                                }
                                Spacer()
                                Button("Unlock") { showPremium = true }
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(AppColors.textOnAccent)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(AppColors.accent)
                                    .cornerRadius(12)
                            }
                            .padding(AppSpacing.sm)
                            .background(AppColors.surface)
                            .cornerRadius(AppSpacing.cornerRadius)
                        }

                        // Practice games
                        sectionHeader("PRACTICE")
                        PracticeRow(title: "Word Meaning", subtitle: "Choose the correct definition", icon: "questionmark.circle", isLocked: !canPlay) {
                            startGame { showQuiz = true }
                        }
                        PracticeRow(title: "Fill the Gap", subtitle: "Complete the sentence", icon: "text.cursor", isLocked: !canPlay) {
                            startGame { showFillGap = true }
                        }
                        PracticeRow(title: "Find Synonyms", subtitle: "Match similar words", icon: "arrow.left.arrow.right", isLocked: !canPlay) {
                            startGame { showSynonyms = true }
                        }
                        PracticeRow(title: "Guess the Word", subtitle: "From definition to word", icon: "lightbulb", isLocked: !canPlay) {
                            startGame { showGuessWord = true }
                        }
                        PracticeRow(title: "Random Practice", subtitle: "Surprise me with a game", icon: "shuffle", isLocked: !canPlay) {
                            startGame {
                                switch Int.random(in: 0...3) {
                                case 0: showQuiz = true
                                case 1: showFillGap = true
                                case 2: showSynonyms = true
                                default: showGuessWord = true
                                }
                            }
                        }
                    }
                    .padding(AppSpacing.md)
                }
            }
            .navigationTitle("Practice")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark").foregroundColor(AppColors.textSecondary)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    if !subscriptions.isPro {
                        Button("Unlock All") { showPremium = true }
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(AppColors.textOnAccent)
                            .padding(.horizontal, AppSpacing.sm)
                            .padding(.vertical, 5)
                            .background(AppColors.accent)
                            .cornerRadius(20)
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showQuiz) {
            QuizView(seenIds: Set(userProfile.profile.seenWordIds),
                     isPro: subscriptions.isPro)
        }
        .sheet(isPresented: $showFillGap) {
            FillGapView(seenIds: Set(userProfile.profile.seenWordIds),
                        isPro: subscriptions.isPro)
        }
        .sheet(isPresented: $showSynonyms) {
            SynonymsView(seenIds: Set(userProfile.profile.seenWordIds),
                         isPro: subscriptions.isPro)
        }
        .sheet(isPresented: $showGuessWord) {
            GuessWordView(seenIds: Set(userProfile.profile.seenWordIds),
                          isPro: subscriptions.isPro)
        }
        .sheet(isPresented: $showPremium) { PremiumSheet().environmentObject(subscriptions) }
        .sheet(item: $activeChallenge) { kind in
            ChallengeView(kind: kind,
                          seenIds: Set(userProfile.profile.seenWordIds),
                          isPro: subscriptions.isPro)
                .environmentObject(userProfile)
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(AppColors.textSecondary)
    }
}

private struct ChallengeCard: View {
    let kind: ChallengeKind
    let highScore: Int
    let isLocked: Bool

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(spacing: AppSpacing.xs) {
                Image(systemName: kind.icon)
                    .font(.system(size: 28))
                    .foregroundColor(AppColors.accent)
                Text(kind.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppColors.textPrimary)
                if highScore > 0 {
                    Text("Best: \(highScore)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(AppColors.textSecondary)
                } else {
                    Text(kind.subtitle)
                        .font(.system(size: 10))
                        .foregroundColor(AppColors.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .padding(.horizontal, 4)
                }
            }
            .frame(width: 130, height: 120)
            .background(AppColors.surface)
            .cornerRadius(AppSpacing.cornerRadius)
            .opacity(isLocked ? 0.5 : 1)

            if isLocked {
                Image(systemName: "lock.fill")
                    .font(.system(size: 11))
                    .foregroundColor(AppColors.locked)
                    .padding(6)
            }
        }
    }
}

private struct PracticeRow: View {
    let title: String
    let subtitle: String
    let icon: String
    var isLocked: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 22))
                    .foregroundColor(isLocked ? AppColors.textSecondary : AppColors.accent)
                    .frame(width: 36)
                VStack(alignment: .leading, spacing: 2) {
                    Text(LocalizedStringKey(title))
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(isLocked ? AppColors.textSecondary : AppColors.textPrimary)
                    Text(LocalizedStringKey(subtitle))
                        .font(.system(size: 13))
                        .foregroundColor(AppColors.textSecondary)
                }
                Spacer()
                Image(systemName: isLocked ? "lock.fill" : "chevron.right")
                    .foregroundColor(isLocked ? AppColors.locked : AppColors.textSecondary)
                    .font(.system(size: 13))
            }
            .padding(AppSpacing.md)
            .background(AppColors.surface)
            .cornerRadius(AppSpacing.cornerRadius)
            .opacity(isLocked ? 0.6 : 1)
        }
    }
}
