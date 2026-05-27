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
                        streakHeroCard
                        wordsProgressCard
                        statsGrid
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

    // MARK: - Streak hero card (full-width)
    private var streakHeroCard: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Current Streak")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white.opacity(0.8))
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("\(userProfile.profile.currentStreak)")
                        .font(.system(size: 64, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Text("days")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                        .padding(.bottom, 8)
                }
                HStack(spacing: AppSpacing.sm) {
                    Text("Best: \(userProfile.profile.longestStreak) days")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                    if userProfile.profile.streakFreezes > 0 {
                        HStack(spacing: 2) {
                            Image(systemName: "snowflake")
                                .font(.system(size: 11, weight: .bold))
                            Text("\(userProfile.profile.streakFreezes)")
                                .font(.system(size: 13, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.white.opacity(0.2))
                        .cornerRadius(8)
                    }
                }
            }
            Spacer()
            Text("🔥")
                .font(.system(size: 64))
        }
        .padding(.horizontal, AppSpacing.lg)
        .padding(.vertical, AppSpacing.lg)
        .frame(maxWidth: .infinity)
        .background(
            LinearGradient(
                colors: [Color.orange, Color(hex: "#FF6B00")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(AppSpacing.cornerRadius)
    }

    // MARK: - Summary stats grid
    private var statsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: AppSpacing.sm) {
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

    // MARK: - Bookmarks card
    private var bookmarksCard: some View {
        let bookmarked = userProfile.profile.bookmarkedWordIds.count
        let liked = userProfile.profile.likedWordIds.count
        return VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Label("Saved Words", systemImage: "bookmark.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(AppColors.textSecondary)

            HStack(spacing: AppSpacing.lg) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(bookmarked)")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(AppColors.textPrimary)
                    Text("Bookmarked")
                        .font(.system(size: 12))
                        .foregroundColor(AppColors.textSecondary)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(liked)")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(AppColors.textPrimary)
                    Text("Liked")
                        .font(.system(size: 12))
                        .foregroundColor(AppColors.textSecondary)
                }
            }
        }
        .padding(AppSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.surface)
        .cornerRadius(AppSpacing.cornerRadius)
    }

    // MARK: - Weekly goal card
    private var weeklyGoalCard: some View {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let openedDays = Set(userProfile.profile.dailyOpens.map { cal.startOfDay(for: $0) })
        // Generate Mon–Sun of the current week
        let weekday = cal.component(.weekday, from: today)
        let daysFromMon = (weekday + 5) % 7  // Mon=0, Sun=6
        let monday = cal.date(byAdding: .day, value: -daysFromMon, to: today)!
        let weekDays = (0..<7).compactMap { cal.date(byAdding: .day, value: $0, to: monday) }
        let labels = ["M", "T", "W", "T", "F", "S", "S"]
        let openedCount = weekDays.filter { openedDays.contains($0) }.count

        return VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Label("This Week", systemImage: "calendar")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(AppColors.textSecondary)

            HStack(alignment: .bottom) {
                Text("\(openedCount)")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundColor(AppColors.textPrimary)
                Text("/ 7 days opened")
                    .font(.system(size: 14))
                    .foregroundColor(AppColors.textSecondary)
                    .padding(.bottom, 6)
            }

            HStack(spacing: 6) {
                ForEach(Array(zip(labels, weekDays)), id: \.1) { label, day in
                    let isOpened = openedDays.contains(day)
                    let isToday = cal.isDate(day, inSameDayAs: today)
                    VStack(spacing: 4) {
                        Circle()
                            .fill(isOpened ? AppColors.accent : AppColors.accent.opacity(0.15))
                            .frame(width: 28, height: 28)
                            .overlay(
                                Text(label)
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(isOpened ? AppColors.textOnAccent : AppColors.accent)
                            )
                            .overlay(
                                Circle().stroke(AppColors.accent, lineWidth: isToday ? 2 : 0)
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
