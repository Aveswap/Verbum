import SwiftUI

struct AppCoordinator: View {
    @EnvironmentObject var userProfile: UserProfileStore
    @EnvironmentObject var auth: AuthService

    var body: some View {
        if userProfile.profile.onboardingCompleted {
            WordFeedView()
                .onAppear {
                    userProfile.recordDailyOpen()
                    Task { await auth.refreshCredentialState() }
                }
        } else {
            OnboardingFlow()
        }
    }
}
