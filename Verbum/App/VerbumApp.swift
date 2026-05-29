import SwiftUI
import CoreSpotlight

@main
struct VerbumApp: App {
    @StateObject private var userProfile: UserProfileStore
    @StateObject private var subscriptions: SubscriptionManager
    @StateObject private var auth: AuthService
    @Environment(\.scenePhase) private var scenePhase

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
            isPro: subscriptions.isPro
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
                        isPro: subscriptions.isPro
                    )
                }
                .onReceive(auth.$isSignedIn) { signedIn in
                    guard signedIn else { return }
                    Task { await userProfile.cloudKit.pull(into: userProfile) }
                }
                .onContinueUserActivity(CSSearchableItemActionType) { activity in
                    // User tapped a Spotlight result — deep-link to that word's detail.
                    if let id = SpotlightIndexer.wordId(from: activity) {
                        NotificationCenter.default.post(name: .openWord, object: id)
                    }
                }
                .onChange(of: scenePhase) { phase in
                    // Pull on every foreground (not just at sign-in) so edits made on another
                    // device show up here without re-authenticating. Cheap: networked + LWW merge.
                    guard phase == .active, userProfile.profile.appleUserID != nil else { return }
                    Task { await userProfile.cloudKit.pull(into: userProfile) }
                }
                // isPro / level change the word pool → rebuild the full 14-day timeline.
                .onChange(of: subscriptions.isPro) { _ in republishSharedTimeline() }
                .onChange(of: userProfile.profile.level) { _ in republishSharedTimeline() }
                // Streak / daily counter only affect the snapshot — skip the 14 DB reads
                // a full timeline rebuild would do on every single swipe.
                .onChange(of: userProfile.profile.currentStreak) { _ in
                    SharedTimelinePublisher.refreshSnapshotOnly(profile: userProfile.profile, isPro: subscriptions.isPro)
                }
                .onChange(of: userProfile.profile.wordsLearnedToday) { _ in
                    SharedTimelinePublisher.refreshSnapshotOnly(profile: userProfile.profile, isPro: subscriptions.isPro)
                }
        }
    }
}
