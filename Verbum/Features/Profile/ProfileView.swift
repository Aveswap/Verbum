import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var userProfile: UserProfileStore
    @EnvironmentObject var subscriptions: SubscriptionManager
    @EnvironmentObject var auth: AuthService
    @Environment(\.dismiss) private var dismiss
    @State private var showSettings = false
    @State private var showFavorites = false
    @State private var showHistory = false
    @State private var showDecks = false
    @State private var showCategories = false
    @State private var showPremium = false
    @State private var showLiked = false
    @State private var showLevelTest = false
    @State private var showReminders = false
    @State private var showLeaderboard = false

    var body: some View {
        NavigationView {
            ZStack {
                AppColors.background.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: AppSpacing.lg) {
                        if subscriptions.isPro {
                            premiumActiveCard
                        } else {
                            premiumCard
                        }
                        streakCard
                        levelTestCard
                        pointsCard
                        customizeSection
                        vocabularySection
                        if !userProfile.profile.earnedBadges.isEmpty {
                            badgesSection
                        }
                    }
                    .padding(AppSpacing.md)
                }
            }
            .navigationTitle(userProfile.profile.name.isEmpty ? "Profile" : "Hi, \(userProfile.profile.name) 👋")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark").foregroundColor(AppColors.textSecondary)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showSettings = true } label: {
                        Image(systemName: "gearshape").foregroundColor(AppColors.textSecondary)
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showSettings)   { SettingsView().environmentObject(userProfile).environmentObject(subscriptions).environmentObject(auth) }
        .sheet(isPresented: $showFavorites)  { FavoritesView().environmentObject(userProfile) }
        .sheet(isPresented: $showLiked)      { LikedView().environmentObject(userProfile) }
        .sheet(isPresented: $showHistory)    { HistoryView().environmentObject(userProfile) }
        .sheet(isPresented: $showDecks)      { DecksView().environmentObject(userProfile) }
        .sheet(isPresented: $showCategories) { CategoriesView().environmentObject(userProfile).environmentObject(subscriptions) }
        .sheet(isPresented: $showPremium)    { PremiumSheet().environmentObject(subscriptions) }
        .sheet(isPresented: $showLevelTest)  { LevelTestView().environmentObject(userProfile) }
        .sheet(isPresented: $showReminders) {
            NavigationView { NotificationSettingsView().environmentObject(userProfile) }
                .preferredColorScheme(.dark)
        }
        .sheet(isPresented: $showLeaderboard) {
            LeaderboardView().environmentObject(userProfile)
        }
    }

    // MARK: - Premium Card (locked / not subscribed)
    private var premiumCard: some View {
        Button { showPremium = true } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Go Premium")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(AppColors.textOnAccent)
                    Text("Unlock all words & practice modes")
                        .font(.system(size: 13))
                        .foregroundColor(AppColors.textOnAccent.opacity(0.8))
                }
                Spacer()
                Image(systemName: "crown.fill")
                    .font(.system(size: 40))
                    .foregroundColor(AppColors.textOnAccent.opacity(0.5))
            }
            .padding(AppSpacing.md)
            .background(AppColors.accent)
            .cornerRadius(AppSpacing.cornerRadius)
        }
    }

    // MARK: - Premium Active Card (subscribed)
    private var premiumActiveCard: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: "crown.fill")
                        .foregroundColor(AppColors.textOnAccent)
                    Text("Verbum Premium")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(AppColors.textOnAccent)
                }
                Text("All words and features unlocked")
                    .font(.system(size: 13))
                    .foregroundColor(AppColors.textOnAccent.opacity(0.85))
            }
            Spacer()
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 32))
                .foregroundColor(AppColors.textOnAccent.opacity(0.8))
        }
        .padding(AppSpacing.md)
        .background(AppColors.accent)
        .cornerRadius(AppSpacing.cornerRadius)
    }

    // MARK: - Level Test Card
    private var levelTestCard: some View {
        Button { showLevelTest = true } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Take the test to find your level")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(AppColors.textPrimary)
                    Text("Current: \(userProfile.profile.level.displayName)")
                        .font(.system(size: 13))
                        .foregroundColor(AppColors.textSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundColor(AppColors.textSecondary)
            }
            .padding(AppSpacing.md)
            .background(AppColors.surface)
            .cornerRadius(AppSpacing.cornerRadius)
        }
    }

    // MARK: - Points Card

    // MARK: - Streak Card (with freeze count)
    private var streakCard: some View {
        HStack(spacing: AppSpacing.md) {
            Text("🔥")
                .font(.system(size: 32))
            VStack(alignment: .leading, spacing: 2) {
                Text("\(userProfile.profile.currentStreak) day streak")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(AppColors.textPrimary)
                Text("Best: \(userProfile.profile.longestStreak) · learn today to keep it")
                    .font(.system(size: 12))
                    .foregroundColor(AppColors.textSecondary)
            }
            Spacer()
            if userProfile.profile.streakFreezes > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "snowflake")
                        .font(.system(size: 14, weight: .semibold))
                    Text("\(userProfile.profile.streakFreezes)")
                        .font(.system(size: 16, weight: .bold))
                }
                .foregroundColor(.cyan)
                .padding(.horizontal, AppSpacing.sm)
                .padding(.vertical, 4)
                .background(Color.cyan.opacity(0.15))
                .cornerRadius(10)
            }
        }
        .padding(AppSpacing.md)
        .frame(maxWidth: .infinity)
        .background(AppColors.surface)
        .cornerRadius(AppSpacing.cornerRadius)
    }

    private var pointsCard: some View {
        let tier = UserProfileStore.badgeTier(for: userProfile.profile.quarterlyPoints)

        return Button { showLeaderboard = true } label: {
            HStack(spacing: AppSpacing.md) {
                ZStack {
                    Circle()
                        .fill(tierColor(tier).opacity(0.15))
                        .frame(width: 52, height: 52)
                    if let tier {
                        Text(tier.emoji).font(.system(size: 26))
                    } else {
                        Image(systemName: "trophy")
                            .font(.system(size: 22))
                            .foregroundColor(AppColors.accent)
                    }
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(tier.map { "\($0.emoji) \($0.label) Badge" } ?? "No Badge Yet")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(tier == nil ? AppColors.textPrimary : tierColor(tier))
                    Text("This quarter")
                        .font(.system(size: 12))
                        .foregroundColor(AppColors.textSecondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(userProfile.profile.quarterlyPoints)")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(AppColors.accent)
                    Text("pts")
                        .font(.system(size: 11))
                        .foregroundColor(AppColors.textSecondary)
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundColor(AppColors.textSecondary)
            }
            .padding(AppSpacing.md)
            .background(AppColors.surface)
            .cornerRadius(AppSpacing.cornerRadius)
        }
    }

    // MARK: - Badges Section

    private var badgesSection: some View {
        ProfileSection(title: "EARNED BADGES") {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AppSpacing.sm) {
                    ForEach(userProfile.profile.earnedBadges.sorted { $0.date > $1.date }) { badge in
                        VStack(spacing: 6) {
                            Text(badge.tier.emoji)
                                .font(.system(size: 32))
                            Text(badge.period)
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(tierColor(badge.tier))
                            Text("\(badge.points) pts")
                                .font(.system(size: 10))
                                .foregroundColor(AppColors.textSecondary)
                        }
                        .frame(width: 80, height: 90)
                        .background(AppColors.surface)
                        .cornerRadius(AppSpacing.cornerRadius)
                    }
                }
            }
        }
    }

    private func tierColor(_ tier: BadgeTier?) -> Color { tier?.color ?? AppColors.accent }

    // MARK: - Customize App
    private var customizeSection: some View {
        ProfileSection(title: "CUSTOMIZE APP") {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: AppSpacing.sm) {
                Button { showReminders = true } label: {
                    SettingCard(title: "Reminders", icon: "bell.fill")
                }
                Button { showCategories = true } label: {
                    SettingCard(title: "Categories", icon: "folder.fill")
                }
            }
        }
    }

    // MARK: - Vocabulary
    private var vocabularySection: some View {
        ProfileSection(title: "YOUR VOCABULARY") {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: AppSpacing.sm) {
                Button { showFavorites = true } label: {
                    SettingCard(title: "Favorites", badge: "\(userProfile.profile.bookmarkedWordIds.count)")
                }
                Button { showLiked = true } label: {
                    SettingCard(title: "Liked", badge: "\(userProfile.profile.likedWordIds.count)")
                }
                Button { showDecks = true } label: {
                    SettingCard(title: "Decks", badge: "\(userProfile.profile.decks.count)")
                }
                Button { showHistory = true } label: {
                    SettingCard(title: "History", badge: "\(userProfile.profile.seenWordIds.count)")
                }
            }
        }
    }
}

// MARK: - Sub-components
private struct ProfileSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(AppColors.textSecondary)
            content
        }
    }
}

private struct SettingCard: View {
    let title: String
    var badge: String? = nil
    var icon: String? = nil
    var locked: Bool = false

    var body: some View {
        HStack(spacing: AppSpacing.xs) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 13))
                    .foregroundColor(locked ? AppColors.locked : AppColors.accent)
                    .frame(width: 18)
            }
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(locked ? AppColors.textSecondary : AppColors.textPrimary)
                .lineLimit(1)
            Spacer()
            if let badge, badge != "0" {
                Text(badge)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(AppColors.textOnAccent)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(AppColors.accent)
                    .cornerRadius(10)
            }
            Image(systemName: locked ? "lock.fill" : "chevron.right")
                .font(.system(size: 11))
                .foregroundColor(locked ? AppColors.locked : AppColors.textSecondary)
        }
        .padding(AppSpacing.sm)
        .frame(height: 50)
        .background(AppColors.surface)
        .cornerRadius(AppSpacing.cornerRadius)
    }
}
