import SwiftUI

struct LeaderboardView: View {
    @EnvironmentObject var userProfile: UserProfileStore
    @Environment(\.dismiss) private var dismiss

    private var entries: [LeaderboardEntry] {
        LeaderboardStore.shared.visibleEntries(
            userPoints: userProfile.profile.quarterlyPoints,
            userName: userProfile.profile.name
        )
    }

    private var userRank: Int {
        LeaderboardStore.shared.rank(for: userProfile.profile.quarterlyPoints)
    }

    private var userTier: BadgeTier? {
        LeaderboardStore.shared.badgeTier(for: userRank)
    }

    private var total: Int { LeaderboardStore.shared.totalUsers() }

    var body: some View {
        NavigationView {
            ZStack {
                AppColors.background.ignoresSafeArea()

                VStack(spacing: 0) {
                    rankCard
                    Divider().background(AppColors.surface)
                    leaderboardList
                }
            }
            .navigationTitle("Leaderboard")
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

    // MARK: - Rank Card

    private var rankCard: some View {
        VStack(spacing: AppSpacing.sm) {
            HStack(spacing: AppSpacing.md) {
                // Badge / rank
                ZStack {
                    Circle()
                        .fill(tierColor(userTier).opacity(0.15))
                        .frame(width: 64, height: 64)
                    if let tier = userTier {
                        Text(tier.emoji)
                            .font(.system(size: 32))
                    } else {
                        Text("#\(userRank)")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(AppColors.textPrimary)
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(userProfile.profile.name.isEmpty ? "Your Rank" : userProfile.profile.name)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(AppColors.textPrimary)

                    Text("Rank \(userRank) of \(total)")
                        .font(.system(size: 13))
                        .foregroundColor(AppColors.textSecondary)

                    if let tier = userTier {
                        Text("\(tier.emoji) \(tier.label) badge this quarter")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(tierColor(tier))
                    } else {
                        Text("Reach top 30% for a badge")
                            .font(.system(size: 12))
                            .foregroundColor(AppColors.textSecondary)
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(userProfile.profile.quarterlyPoints)")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(AppColors.accent)
                    Text("pts this quarter")
                        .font(.system(size: 11))
                        .foregroundColor(AppColors.textSecondary)
                }
            }
            .padding(AppSpacing.lg)

            // Progress to next badge
            nextBadgeProgress
        }
        .background(AppColors.surface)
    }

    @ViewBuilder
    private var nextBadgeProgress: some View {
        let pts = userProfile.profile.quarterlyPoints
        if userRank > 100, let info = nextBadgeTarget() {
            let progress = min(1.0, Double(pts) / Double(info.target))
            VStack(spacing: 4) {
                HStack {
                    Text("Progress to \(info.tier.emoji) \(info.tier.label)")
                        .font(.system(size: 11))
                        .foregroundColor(AppColors.textSecondary)
                    Spacer()
                    Text("\(pts)/\(info.target) pts")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(tierColor(info.tier))
                }
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(AppColors.background)
                            .frame(height: 6)
                        RoundedRectangle(cornerRadius: 4)
                            .fill(tierColor(info.tier))
                            .frame(width: geo.size.width * progress, height: 6)
                    }
                }
                .frame(height: 6)
            }
            .padding(.horizontal, AppSpacing.lg)
            .padding(.bottom, AppSpacing.md)
        }
    }

    private func nextBadgeTarget() -> (tier: BadgeTier, target: Int)? {
        if userRank > 300 { return (.bronze, pointsForRank(300)) }
        if userRank > 200 { return (.silver, pointsForRank(200)) }
        if userRank > 100 { return (.gold,   pointsForRank(100)) }
        return nil
    }

    private func pointsForRank(_ rank: Int) -> Int {
        // Approximate points needed for that rank from the simulated pool
        switch rank {
        case 100: return 900
        case 200: return 400
        case 300: return 200
        default:  return 0
        }
    }

    // MARK: - List

    private var leaderboardList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                // Section header
                HStack {
                    Text("Q\(currentQuarter()) Leaderboard")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(AppColors.textSecondary)
                    Spacer()
                    Text("Resets quarterly")
                        .font(.system(size: 11))
                        .foregroundColor(AppColors.textSecondary)
                }
                .padding(.horizontal, AppSpacing.lg)
                .padding(.vertical, AppSpacing.sm)

                // Gap row if user is not near top
                if userRank > 6 {
                    HStack {
                        Spacer()
                        Text("• • •")
                            .foregroundColor(AppColors.textSecondary)
                        Spacer()
                    }
                    .padding(.vertical, AppSpacing.sm)
                }

                ForEach(entries) { entry in
                    LeaderboardRow(entry: entry)
                    Divider()
                        .background(AppColors.surface.opacity(0.5))
                        .padding(.leading, AppSpacing.lg)
                }

                // Footer
                VStack(spacing: AppSpacing.sm) {
                    Text("🌍 \(total) learners worldwide")
                        .font(.system(size: 12))
                        .foregroundColor(AppColors.textSecondary)
                    Text("Leaderboard resets every 3 months.\nBadges are kept in your profile forever.")
                        .font(.system(size: 11))
                        .foregroundColor(AppColors.textSecondary.opacity(0.6))
                        .multilineTextAlignment(.center)
                }
                .padding(AppSpacing.xl)
            }
        }
    }

    private func currentQuarter() -> Int {
        (Calendar.current.component(.month, from: Date()) - 1) / 3 + 1
    }

    private func tierColor(_ tier: BadgeTier?) -> Color {
        switch tier {
        case .gold:   return Color(red: 1.0, green: 0.84, blue: 0)
        case .silver: return Color(red: 0.75, green: 0.75, blue: 0.75)
        case .bronze: return Color(red: 0.8, green: 0.5, blue: 0.2)
        case nil:     return AppColors.accent
        }
    }
}

// MARK: - Row

private struct LeaderboardRow: View {
    let entry: LeaderboardEntry

    var body: some View {
        HStack(spacing: AppSpacing.md) {
            // Rank
            ZStack {
                if entry.rank <= 3 {
                    Text(["🥇","🥈","🥉"][entry.rank - 1])
                        .font(.system(size: 20))
                } else {
                    Text("#\(entry.rank)")
                        .font(.system(size: 14, weight: entry.isCurrentUser ? .bold : .regular))
                        .foregroundColor(entry.isCurrentUser ? AppColors.accent : AppColors.textSecondary)
                }
            }
            .frame(width: 36)

            // Name
            Text(entry.name)
                .font(.system(size: 15, weight: entry.isCurrentUser ? .semibold : .regular))
                .foregroundColor(entry.isCurrentUser ? AppColors.textPrimary : AppColors.textPrimary.opacity(0.8))

            if entry.isCurrentUser {
                Text("(you)")
                    .font(.system(size: 12))
                    .foregroundColor(AppColors.accent)
            }

            Spacer()

            if let badge = entry.badge {
                Text(badge.emoji)
                    .font(.system(size: 14))
            }

            Text("\(entry.points)")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(entry.isCurrentUser ? AppColors.accent : AppColors.textPrimary)
                + Text(" pts")
                .font(.system(size: 11))
                .foregroundColor(AppColors.textSecondary)
        }
        .padding(.horizontal, AppSpacing.lg)
        .padding(.vertical, 12)
        .background(entry.isCurrentUser ? AppColors.accent.opacity(0.08) : Color.clear)
    }
}
