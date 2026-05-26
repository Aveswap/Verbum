import SwiftUI

struct AppCoordinator: View {
    @EnvironmentObject var userProfile: UserProfileStore
    @EnvironmentObject var auth: AuthService

    var body: some View {
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
