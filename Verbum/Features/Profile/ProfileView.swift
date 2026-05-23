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

    var body: some View {
        NavigationView {
            ZStack {
                AppColors.background.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: AppSpacing.lg) {
                        // Premium card
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

                        // Level test card
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

                        // Customize
                        ProfileSection(title: "CUSTOMIZE APP") {
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: AppSpacing.sm) {
                                ForEach(["Categories", "Reminders", "Voice", "Widgets",
                                          "Lock Screen", "Apple Watch", "Themes", "App Icon"], id: \.self) { item in
                                    SettingCard(title: item)
                                }
                            }
                        }

                        // Vocabulary
                        ProfileSection(title: "YOUR VOCABULARY") {
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: AppSpacing.sm) {
                                Button { showFavorites = true } label: {
                                    SettingCard(title: "Favorites", badge: "\(userProfile.profile.bookmarkedWordIds.count)")
                                }
                                Button { showLiked = true } label: {
                                    SettingCard(title: "Liked", badge: "\(userProfile.profile.likedWordIds.count)")
                                }
                                Button { showPremium = true } label: {
                                    SettingCard(title: "My Words")
                                }
                                Button { showPremium = true } label: {
                                    SettingCard(title: "Collections")
                                }
                                Button { showHistory = true } label: {
                                    SettingCard(title: "History", badge: "\(userProfile.profile.seenWordIds.count)")
                                }
                            }
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
    }
}

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
    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(AppColors.textPrimary)
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
            Image(systemName: "chevron.right")
                .font(.system(size: 11))
                .foregroundColor(AppColors.textSecondary)
        }
        .padding(AppSpacing.sm)
        .frame(height: 50)
        .background(AppColors.surface)
        .cornerRadius(AppSpacing.cornerRadius)
    }
}
