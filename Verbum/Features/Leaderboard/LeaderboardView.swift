import SwiftUI

struct LeaderboardView: View {
    @EnvironmentObject var userProfile: UserProfileStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ZStack {
                AppColors.background.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: AppSpacing.md) {
                        quarterCard
                        streakCard
                        progressCard
                        if !userProfile.profile.earnedBadges.isEmpty {
                            badgesCard
                        }
                        milestoneCard
                    }
                    .padding(AppSpacing.md)
                }
            }
            .navigationTitle("My Progress")
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

    // MARK: - Quarter Points + Badge

    private var quarterCard: some View {
        let tier = UserProfileStore.badgeTier(for: userProfile.profile.quarterlyPoints)
        return VStack(spacing: AppSpacing.sm) {
            HStack(spacing: AppSpacing.md) {
                ZStack {
                    Circle()
                        .fill(tierColor(tier).opacity(0.15))
                        .frame(width: 64, height: 64)
                    if let tier {
                        Text(tier.emoji).font(.system(size: 32))
                    } else {
                        Image(systemName: "star.circle")
                            .font(.system(size: 28))
                            .foregroundColor(AppColors.accent)
                    }
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(tier.map { "\($0.emoji) \($0.label) Badge" } ?? "No Badge Yet")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(tier == nil ? AppColors.textPrimary : tierColor(tier))
                    Text("Q\(currentQuarter()) \(currentYear()) — resets quarterly")
                        .font(.system(size: 12))
                        .foregroundColor(AppColors.textSecondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(userProfile.profile.quarterlyPoints)")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(AppColors.accent)
                    Text("pts")
                        .font(.system(size: 11))
                        .foregroundColor(AppColors.textSecondary)
                }
            }
            badgeProgressBar(pts: userProfile.profile.quarterlyPoints, tier: tier)
        }
        .padding(AppSpacing.md)
        .background(AppColors.surface)
        .cornerRadius(AppSpacing.cornerRadius)
    }

    @ViewBuilder
    private func badgeProgressBar(pts: Int, tier: BadgeTier?) -> some View {
        if tier != .gold {
            let next = nextTarget(current: tier)
            let progress = min(1.0, Double(pts) / Double(next.pts))
            VStack(spacing: 4) {
                HStack {
                    Text("Next: \(next.tier.emoji) \(next.tier.label) at \(next.pts) pts")
                        .font(.system(size: 11))
                        .foregroundColor(AppColors.textSecondary)
                    Spacer()
                    Text("\(pts)/\(next.pts)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(tierColor(next.tier))
                }
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3).fill(AppColors.background).frame(height: 6)
                        RoundedRectangle(cornerRadius: 3)
                            .fill(tierColor(next.tier))
                            .frame(width: geo.size.width * progress, height: 6)
                            .animation(.easeOut, value: progress)
                    }
                }
                .frame(height: 6)
            }
        }
    }

    // MARK: - Streak

    private var streakCard: some View {
        StatRow2Col(
            left: StatCell(icon: "flame.fill", color: .orange,
                           value: "\(userProfile.profile.currentStreak)",
                           label: "Current Streak", unit: "days"),
            right: StatCell(icon: "trophy.fill", color: Color(red: 1, green: 0.84, blue: 0),
                            value: "\(userProfile.profile.longestStreak)",
                            label: "Best Streak", unit: "days")
        )
    }

    // MARK: - Progress

    private var progressCard: some View {
        let seen = userProfile.profile.seenWordIds.count
        let total = WordRepository.shared.totalWordCount
        let pct = total > 0 ? Int(Double(seen) / Double(total) * 100) : 0
        return StatRow2Col(
            left: StatCell(icon: "book.fill", color: AppColors.accent,
                           value: "\(seen)",
                           label: "Words Seen", unit: "of \(total)"),
            right: StatCell(icon: "star.fill", color: .purple,
                            value: "\(pct)%",
                            label: "Completed", unit: "of library")
        )
    }

    // MARK: - Milestones

    private var milestoneCard: some View {
        let pts = userProfile.profile.totalPoints
        let seen = userProfile.profile.seenWordIds.count
        let streak = userProfile.profile.currentStreak

        let milestones: [(icon: String, label: String, done: Bool)] = [
            ("flame",        "7-day streak",         streak >= 7),
            ("flame.fill",   "30-day streak",        streak >= 30),
            ("book",         "See 50 words",          seen >= 50),
            ("book.fill",    "See 250 words",         seen >= 250),
            ("bolt",         "Earn 100 pts",          pts >= 100),
            ("bolt.fill",    "Earn 1,000 pts",        pts >= 1000),
        ]

        return VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("MILESTONES")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(AppColors.textSecondary)
            ForEach(milestones, id: \.label) { m in
                HStack(spacing: AppSpacing.sm) {
                    Image(systemName: m.done ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(m.done ? AppColors.accent : AppColors.textSecondary)
                    Image(systemName: m.icon)
                        .font(.system(size: 13))
                        .foregroundColor(m.done ? AppColors.textPrimary : AppColors.textSecondary)
                        .frame(width: 18)
                    Text(m.label)
                        .font(.system(size: 14))
                        .foregroundColor(m.done ? AppColors.textPrimary : AppColors.textSecondary)
                    Spacer()
                }
                .padding(.vertical, 4)
            }
        }
        .padding(AppSpacing.md)
        .background(AppColors.surface)
        .cornerRadius(AppSpacing.cornerRadius)
    }

    // MARK: - Badges earned

    private var badgesCard: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("EARNED BADGES")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(AppColors.textSecondary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AppSpacing.sm) {
                    ForEach(userProfile.profile.earnedBadges.sorted { $0.date > $1.date }) { badge in
                        VStack(spacing: 6) {
                            Text(badge.tier.emoji).font(.system(size: 30))
                            Text(badge.period)
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(tierColor(badge.tier))
                            Text("\(badge.points) pts")
                                .font(.system(size: 10))
                                .foregroundColor(AppColors.textSecondary)
                        }
                        .frame(width: 78, height: 86)
                        .background(AppColors.background)
                        .cornerRadius(AppSpacing.cornerRadius)
                    }
                }
            }
        }
        .padding(AppSpacing.md)
        .background(AppColors.surface)
        .cornerRadius(AppSpacing.cornerRadius)
    }

    // MARK: - Helpers

    private func nextTarget(current: BadgeTier?) -> (tier: BadgeTier, pts: Int) {
        switch current {
        case nil:    return (.bronze, 200)
        case .bronze: return (.silver, 400)
        default:     return (.gold, 900)
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

    private func currentQuarter() -> Int {
        (Calendar.current.component(.month, from: Date()) - 1) / 3 + 1
    }

    private func currentYear() -> Int {
        Calendar.current.component(.year, from: Date())
    }
}

// MARK: - Sub-components

private struct StatRow2Col: View {
    let left: StatCell
    let right: StatCell
    var body: some View {
        HStack(spacing: AppSpacing.sm) {
            left
            right
        }
    }
}

private struct StatCell: View {
    let icon: String
    let color: Color
    let value: String
    let label: String
    let unit: String

    var body: some View {
        HStack(spacing: AppSpacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 22))
                .foregroundColor(color)
                .frame(width: 30)
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(AppColors.textPrimary)
                Text(label)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(AppColors.textSecondary)
                Text(unit)
                    .font(.system(size: 10))
                    .foregroundColor(AppColors.textSecondary.opacity(0.7))
            }
            Spacer()
        }
        .padding(AppSpacing.md)
        .background(AppColors.surface)
        .cornerRadius(AppSpacing.cornerRadius)
        .frame(maxWidth: .infinity)
    }
}
