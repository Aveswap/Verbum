import SwiftUI
import CoreSpotlight

@main
struct VerbumApp: App {
    @StateObject private var userProfile: UserProfileStore
    @StateObject private var subscriptions: SubscriptionManager
    @StateObject private var auth: AuthService
    @StateObject private var language = LanguageManager.shared
    @Environment(\.scenePhase) private var scenePhase

    init() {
        let store = UserProfileStore()
        // Resolve the vocabulary language BEFORE any UI builds, so onboarding (word-check),
        // notifications, and the feed all use the device/stored language from the first frame
        // — not English-until-the-feed-appears. applyWordLanguage() also bootstraps the UI
        // language (LanguageManager) to the same value.
        store.applyWordLanguage()
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
                .environmentObject(language)
                // Format numbers/dates in the UI language, and rebuild the whole tree when it
                // changes so every Text re-resolves against the new .lproj (live switch).
                .environment(\.locale, language.locale)
                .id(language.language)
                .preferredColorScheme(.dark)
                .onAppear {
                    // Publish a fresh 14-day timeline for widget + watch on every launch.
                    // (Game Center auth is deferred to the feed so its sheet can't interrupt
                    // onboarding — see AppCoordinator.)
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
                // isPro changes the word pool → rebuild the full 14-day timeline, and re-index
                // Spotlight so paid definitions appear (Pro) or are re-locked (lapse).
                .onChange(of: subscriptions.isPro) { isPro in
                    republishSharedTimeline()
                    SpotlightIndexer.indexIfNeeded(
                        words: WordRepository.shared.all,
                        freeIds: Set(WordAccess.freePool().map(\.id)),
                        isPro: isPro,
                        version: WordDatabase.bundledDBVersion
                    )
                }
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
