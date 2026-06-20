import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var userProfile: UserProfileStore
    @EnvironmentObject var subscriptions: SubscriptionManager
    @EnvironmentObject var auth: AuthService
    @Environment(\.dismiss) private var dismiss
    @State private var showSettings = false
    @State private var showFavorites = false
    @State private var showHistory = false
    @State private var showPremium = false
    @State private var showLiked = false
    @State private var showPractice = false

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
                        practiceCard
                        vocabularySection
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
        .sheet(isPresented: $showPremium)    { PremiumSheet().environmentObject(subscriptions) }
        .sheet(isPresented: $showPractice) {
            PracticeMenuView().environmentObject(userProfile).environmentObject(subscriptions)
        }
    }

    // MARK: - Practice (games hub)
    private var practiceCard: some View {
        Button { showPractice = true } label: {
            HStack(spacing: AppSpacing.md) {
                Image(systemName: "gamecontroller.fill")
                    .font(.system(size: 24))
                    .foregroundColor(AppColors.textOnAccent)
                    .frame(width: 48, height: 48)
                    .background(AppColors.accent)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Practice")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(AppColors.textPrimary)
                    Text("Games, challenges & words you'll soon forget")
                        .font(.system(size: 13))
                        .foregroundColor(AppColors.textSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundColor(AppColors.textSecondary)
            }
            .padding(AppSpacing.md)
            .background(AppColors.surface)
            .cornerRadius(AppSpacing.cornerRadius)
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
