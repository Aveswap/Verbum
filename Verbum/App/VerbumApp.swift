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
                    // Publish a fresh rotating word timeline for widget + watch on every launch.
                    // (Game Center auth is deferred to the feed so its sheet can't interrupt
                    // onboarding — see AppCoordinator.)
                    SharedTimelinePublisher.refresh(
                        profile: userProfile.profile,
                        isPro: subscriptions.isPro
                    )
                    // Re-issue the daily word notifications so they reflect the current catalogue
                    // and language — this also clears stale notifications scheduled by an older
                    // build (e.g. German words left over from before the English-only catalogue).
                    if userProfile.profile.notificationsEnabled {
                        NotificationManager.reschedule(
                            count: userProfile.profile.notificationCount,
                            startHour: NotificationManager.hoursFrom(userProfile.profile.notificationStart),
                            endHour: NotificationManager.hoursFrom(userProfile.profile.notificationEnd),
                            seenIds: Set(userProfile.profile.seenWordIds),
                            calendar: userProfile.dayCalendar
                        )
                    }
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
                .onOpenURL { url in
                    // Widget tap: verbum://word/<uuid> → open that word's detail.
                    guard url.scheme == "verbum", url.host == "word",
                          let id = UUID(uuidString: url.lastPathComponent) else { return }
                    NotificationCenter.default.post(name: .openWord, object: id)
                }
                .onChange(of: scenePhase) { phase in
                    guard phase == .active else { return }
                    // Re-anchor the widget's rotating timeline to "now" + current seen state on
                    // every foreground, so words keep rotating even if the app isn't opened daily.
                    republishSharedTimeline()
                    // Pull on every foreground (not just at sign-in) so edits made on another
                    // device show up here without re-authenticating. Cheap: networked + LWW merge.
                    if userProfile.profile.appleUserID != nil {
                        Task { await userProfile.cloudKit.pull(into: userProfile) }
                    }
                }
                // isPro changes the word pool → rebuild the rotating timeline, and re-index
                // Spotlight so paid definitions appear (Pro) or are re-locked (lapse).
                .onChange(of: subscriptions.isPro) { isPro in
                    republishSharedTimeline()
                    SpotlightIndexer.indexIfNeeded(
                        words: WordRepository.shared.all,
                        freeIds: Set(WordAccess.freePool().map(\.id)),
                        isPro: isPro,
                        language: WordRepository.shared.activeLanguage,
                        version: WordDatabase.bundledDBVersion
                    )
                }
                // Streak / daily counter only affect the snapshot — skip rebuilding the whole
                // rotating word timeline on every single swipe.
                .onChange(of: userProfile.profile.currentStreak) { _ in
                    SharedTimelinePublisher.refreshSnapshotOnly(profile: userProfile.profile, isPro: subscriptions.isPro)
                }
                .onChange(of: userProfile.profile.wordsLearnedToday) { _ in
                    SharedTimelinePublisher.refreshSnapshotOnly(profile: userProfile.profile, isPro: subscriptions.isPro)
                }
                // dailyGoal feeds the snapshot's "x of N learned"; notificationCount drives how
                // many "words of the day" the widget rotates through (shared with notifications).
                // Either change → rebuild the full timeline, not just the snapshot.
                .onChange(of: userProfile.profile.dailyGoal) { _ in republishSharedTimeline() }
                .onChange(of: userProfile.profile.notificationCount) { _ in republishSharedTimeline() }
        }
    }
}
