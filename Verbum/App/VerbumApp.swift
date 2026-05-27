import SwiftUI

@main
struct VerbumApp: App {
    @StateObject private var userProfile: UserProfileStore
    @StateObject private var subscriptions: SubscriptionManager
    @StateObject private var auth: AuthService

    init() {
        let store = UserProfileStore()
        _userProfile = StateObject(wrappedValue: store)
        _subscriptions = StateObject(wrappedValue: SubscriptionManager())
        _auth = StateObject(wrappedValue: AuthService(profileStore: store))
    }

    /// Re-publishes the 14-day timeline + snapshot whenever profile/sub state changes.
    @MainActor
    private func republishSharedTimeline() {
        SharedTimelinePublisher.refresh(
            profile: userProfile.profile,
            isPro: subscriptions.isPro,
            translationLang: userProfile.profile.nativeLanguage?.rawValue
        )
    }

    var body: some Scene {
        WindowGroup {
            AppCoordinator()
                .environmentObject(userProfile)
                .environmentObject(subscriptions)
                .environmentObject(auth)
                .environmentObject(GameCenterService.shared)
                .preferredColorScheme(.dark)
                .onAppear {
                    // Kick off Game Center auth — system shows sign-in sheet on first launch.
                    GameCenterService.shared.authenticate()
                    // Publish a fresh 14-day timeline for widget + watch on every launch.
                    SharedTimelinePublisher.refresh(
                        profile: userProfile.profile,
                        isPro: subscriptions.isPro,
                        translationLang: userProfile.profile.nativeLanguage?.rawValue
                    )
                }
                .onReceive(auth.$isSignedIn) { signedIn in
                    guard signedIn else { return }
                    Task { await userProfile.cloudKit.pull(into: userProfile) }
                }
                .onChange(of: subscriptions.isPro) { _ in republishSharedTimeline() }
                .onChange(of: userProfile.profile.level) { _ in republishSharedTimeline() }
                .onChange(of: userProfile.profile.currentStreak) { _ in republishSharedTimeline() }
                .onChange(of: userProfile.profile.wordsLearnedToday) { _ in republishSharedTimeline() }
        }
    }
}
