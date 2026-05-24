import SwiftUI

struct StatsView: View {
    @EnvironmentObject var userProfile: UserProfileStore
    @Environment(\.dismiss) private var dismiss

    private var totalWords: Int { WordRepository.shared.totalWordCount }

    var body: some View {
        NavigationView {
            ZStack {
                AppColors.background.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: AppSpacing.lg) {
                        summaryGrid
                        wordsProgressCard
                        personalizationCard
                        weeklyGoalCard
                        profileCard
                    }
                    .padding(AppSpacing.md)
                }
            }
            .navigationTitle("Statistics")
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
    }

    // MARK: - Summary grid
    private var summaryGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: AppSpacing.sm) {
            StatCard(
                value: "\(userProfile.profile.currentStreak)",
                label: "Day Streak 🔥",
                icon: "flame.fill",
                color: .orange
            )
            StatCard(
                value: "\(userProfile.profile.longestStreak)",
                label: "Best Streak",
                icon: "trophy.fill",
                color: .yellow
            )
            StatCard(
                value: "\(userProfile.profile.bookmarkedWordIds.count)",
                label: "Bookmarked",
                icon: "bookmark.fill",
                color: AppColors.accent
            )
            StatCard(
                value: "\(userProfile.profile.likedWordIds.count)",
                label: "Liked",
                icon: "heart.fill",
                color: .red
            )
            StatCard(
                value: "\(userProfile.profile.seenWordIds.count)",
                label: "Words Seen",
                icon: "eye.fill",
                color: .purple
            )
            StatCard(
                value: "\(userProfile.profile.wordsPerWeek)",
                label: "Goal / week",
                icon: "flag.fill",
                color: .orange
            )
            StatCard(
                value: userProfile.profile.level.displayName,
                label: "Level",
                icon: "chart.bar.fill",
                color: .purple
            )
        }
    }

    // MARK: - Words discovered progress
    private var wordsProgressCard: some View {
        let seen = min(userProfile.profile.seenWordIds.count, totalWords)
        let progress = Double(seen) / Double(totalWords)
        return VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Label("Words Discovered", systemImage: "books.vertical.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(AppColors.textSecondary)

            HStack(alignment: .bottom) {
                Text("\(seen)")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundColor(AppColors.textPrimary)
                Text("/ \(totalWords) words")
                    .font(.system(size: 14))
                    .foregroundColor(AppColors.textSecondary)
                    .padding(.bottom, 6)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4).fill(AppColors.surfaceSecondary).frame(height: 8)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(AppColors.accent)
                        .frame(width: geo.size.width * progress, height: 8)
                        .animation(.easeOut(duration: 0.6), value: seen)
                }
            }
            .frame(height: 8)

            Text(seen == totalWords
                 ? "You've discovered all words! Great job!"
                 : "\(totalWords - seen) more to discover")
                .font(.system(size: 12))
                .foregroundColor(AppColors.textSecondary)
        }
        .padding(AppSpacing.md)
        .background(AppColors.surface)
        .cornerRadius(AppSpacing.cornerRadius)
    }

    // MARK: - Personalization progress
    private var personalizationCard: some View {
        let bookmarked = min(userProfile.profile.bookmarkedWordIds.count, 5)
        let remaining = max(5 - bookmarked, 0)
        return VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Label("Personalization", systemImage: "wand.and.stars")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(AppColors.textSecondary)

            Text(remaining > 0
                 ? "Bookmark \(remaining) more word\(remaining == 1 ? "" : "s") to unlock personalized recommendations"
                 : "🎉 Personalized recommendations are active!")
                .font(.system(size: 14))
                .foregroundColor(AppColors.textPrimary)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4).fill(AppColors.surfaceSecondary).frame(height: 8)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(AppColors.accent)
                        .frame(width: geo.size.width * Double(bookmarked) / 5.0, height: 8)
                        .animation(.easeOut(duration: 0.6), value: bookmarked)
                }
            }
            .frame(height: 8)

            Text("\(bookmarked) / 5 words saved")
                .font(.system(size: 12))
                .foregroundColor(AppColors.textSecondary)
        }
        .padding(AppSpacing.md)
        .background(AppColors.surface)
        .cornerRadius(AppSpacing.cornerRadius)
    }

    // MARK: - Weekly goal card
    private var weeklyGoalCard: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Label("Weekly Goal", systemImage: "calendar")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(AppColors.textSecondary)

            HStack(alignment: .bottom) {
                Text("\(userProfile.profile.wordsPerWeek)")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundColor(AppColors.textPrimary)
                Text("words / week")
                    .font(.system(size: 14))
                    .foregroundColor(AppColors.textSecondary)
                    .padding(.bottom, 6)
            }

            // Day progress dots (visual only)
            HStack(spacing: 6) {
                ForEach(["M", "T", "W", "T", "F", "S", "S"], id: \.self) { day in
                    VStack(spacing: 4) {
                        Circle()
                            .fill(AppColors.accent.opacity(0.3))
                            .frame(width: 28, height: 28)
                            .overlay(
                                Text(day).font(.system(size: 11, weight: .medium)).foregroundColor(AppColors.accent)
                            )
                    }
                }
            }
        }
        .padding(AppSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.surface)
        .cornerRadius(AppSpacing.cornerRadius)
    }

    // MARK: - Profile summary card
    private var profileCard: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Label("Your Profile", systemImage: "person.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(AppColors.textSecondary)

            VStack(spacing: 1) {
                ProfileRow(label: "Name", value: userProfile.profile.name.isEmpty ? "Not set" : userProfile.profile.name)
                ProfileRow(label: "Level", value: userProfile.profile.level.displayName)
                ProfileRow(label: "Age", value: userProfile.profile.age?.rawValue ?? "Not set")
                ProfileRow(label: "Notifications", value: userProfile.profile.notificationsEnabled ? "On" : "Off")
            }
            .cornerRadius(AppSpacing.cornerRadius)
        }
        .padding(AppSpacing.md)
        .background(AppColors.surface)
        .cornerRadius(AppSpacing.cornerRadius)
    }
}

// MARK: - Sub-components
struct StatCard: View {
    let value: String
    let label: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(color)
            Text(value)
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(AppColors.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(label)
                .font(.system(size: 12))
                .foregroundColor(AppColors.textSecondary)
        }
        .padding(AppSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.surface)
        .cornerRadius(AppSpacing.cornerRadius)
    }
}

private struct ProfileRow: View {
    let label: String
    let value: String
    var body: some View {
        HStack {
            Text(label).foregroundColor(AppColors.textSecondary).font(.system(size: 14))
            Spacer()
            Text(value).foregroundColor(AppColors.textPrimary).font(.system(size: 14, weight: .medium))
        }
        .padding(.vertical, 8)
        .padding(.horizontal, AppSpacing.sm)
        .background(AppColors.surfaceSecondary)
    }
}
