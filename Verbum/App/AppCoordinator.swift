import SwiftUI

struct AppCoordinator: View {
    @EnvironmentObject var userProfile: UserProfileStore
    @EnvironmentObject var auth: AuthService
    @EnvironmentObject var subscriptions: SubscriptionManager

    var body: some View {
        ZStack(alignment: .top) {
            content

            if subscriptions.subscriptionEnded {
                SubscriptionEndedBanner { subscriptions.subscriptionEnded = false }
                    .padding(.horizontal, AppSpacing.md)
                    .padding(.top, AppSpacing.sm)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(1)
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: subscriptions.subscriptionEnded)
    }

    @ViewBuilder
    private var content: some View {
        if userProfile.profile.onboardingCompleted {
            WordFeedView()
                .onAppear {
                    NotificationManager.scheduleStreakReminder(
                        currentStreak: userProfile.profile.currentStreak,
                        lastOpened: userProfile.profile.lastOpenedDate
                    )
                    userProfile.recordDailyOpen()
                    Task { await auth.refreshCredentialState() }
                }
        } else {
            OnboardingFlow()
        }
    }
}

/// Soft, non-blocking banner shown once when a Pro subscription lapses. Auto-dismisses.
private struct SubscriptionEndedBanner: View {
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: AppSpacing.sm) {
            Image(systemName: "crown")
                .font(.system(size: 18))
                .foregroundColor(AppColors.accent)
            VStack(alignment: .leading, spacing: 2) {
                Text("Your subscription has ended")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(AppColors.textPrimary)
                Text("Renew anytime to unlock every word again.")
                    .font(.system(size: 13))
                    .foregroundColor(AppColors.textSecondary)
            }
            Spacer()
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(AppColors.textSecondary)
            }
        }
        .padding(AppSpacing.md)
        .background(AppColors.surface)
        .cornerRadius(AppSpacing.cornerRadius)
        .shadow(color: .black.opacity(0.3), radius: 12, y: 4)
        .task {
            // Auto-dismiss after a few seconds so it stays "soft".
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            onDismiss()
        }
    }
}
