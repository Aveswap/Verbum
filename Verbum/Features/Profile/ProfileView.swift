import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var userProfile: UserProfileStore
    @Environment(\.dismiss) private var dismiss
    @State private var showSettings = false
    @State private var showFavorites = false
    @State private var showHistory = false
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
                        premiumCard
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
        .sheet(isPresented: $showSettings)   { SettingsView().environmentObject(userProfile) }
        .sheet(isPresented: $showFavorites)  { FavoritesView().environmentObject(userProfile) }
        .sheet(isPresented: $showLiked)      { LikedView().environmentObject(userProfile) }
        .sheet(isPresented: $showHistory)    { HistoryView().environmentObject(userProfile) }
        .sheet(isPresented: $showPremium)    { PremiumSheet() }
        .sheet(isPresented: $showLevelTest)  { LevelTestView().environmentObject(userProfile) }
        .sheet(isPresented: $showReminders) {
            NavigationView { NotificationSettingsView().environmentObject(userProfile) }
                .preferredColorScheme(.dark)
        }
        .sheet(isPresented: $showLeaderboard) {
            LeaderboardView().environmentObject(userProfile)
        }
    }

    // MARK: - Premium Card
    private var premiumCard: some View {
        Button { showPremium = true } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Go Premium")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(AppColors.textOnAccent)
                    Text("Unlock all words, games & themes")
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

    private var pointsCard: some View {
        let rank = LeaderboardStore.shared.rank(for: userProfile.profile.quarterlyPoints)
        let tier = LeaderboardStore.shared.badgeTier(for: rank)

        return Button { showLeaderboard = true } label: {
            HStack(spacing: AppSpacing.md) {
                ZStack {
                    Circle()
                        .fill(tierColor(tier).opacity(0.15))
                        .frame(width: 52, height: 52)
                    if let tier {
                        Text(tier.emoji)
                            .font(.system(size: 26))
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
                    Text("Rank #\(rank) this quarter")
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

    private func tierColor(_ tier: BadgeTier?) -> Color {
        switch tier {
        case .gold:   return Color(red: 1.0, green: 0.84, blue: 0)
        case .silver: return Color(red: 0.75, green: 0.75, blue: 0.75)
        case .bronze: return Color(red: 0.8, green: 0.5, blue: 0.2)
        case nil:     return AppColors.accent
        }
    }

    // MARK: - Customize App
    private var customizeSection: some View {
        ProfileSection(title: "CUSTOMIZE APP") {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: AppSpacing.sm) {
                Button { showReminders = true } label: {
                    SettingCard(title: "Reminders", icon: "bell.fill")
                }
                Button { showPremium = true } label: {
                    SettingCard(title: "Themes", icon: "paintpalette.fill", locked: true)
                }
                Button { showPremium = true } label: {
                    SettingCard(title: "Voice", icon: "speaker.wave.2.fill", locked: true)
                }
                Button { showPremium = true } label: {
                    SettingCard(title: "Widgets", icon: "square.grid.2x2.fill", locked: true)
                }
                Button { showPremium = true } label: {
                    SettingCard(title: "Categories", icon: "folder.fill", locked: true)
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
                Button { showPremium = true } label: {
                    SettingCard(title: "My Words", locked: true)
                }
                Button { showPremium = true } label: {
                    SettingCard(title: "Collections", locked: true)
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
