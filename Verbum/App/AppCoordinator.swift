import SwiftUI

struct AppCoordinator: View {
    @EnvironmentObject var userProfile: UserProfileStore

    var body: some View {
        if userProfile.profile.onboardingCompleted {
            WordFeedView()
                .onAppear { userProfile.recordDailyOpen() }
        } else {
            OnboardingFlow()
        }
    }
}
