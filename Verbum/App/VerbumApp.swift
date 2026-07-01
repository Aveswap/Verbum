import SwiftUI
import CoreSpotlight
import UserNotifications

/// AppDelegate exists solely so we can install a `UNUserNotificationCenterDelegate` — without
/// it, tapping a word-of-the-day notification just launches the app generically and the
/// payload (`userInfo["wordId"]`) is lost.
final class VerbumAppDelegate: NSObject, UIApplicationDelegate, @preconcurrency UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    /// Show the banner even when the app is in the foreground — otherwise iOS suppresses it
    /// silently and the user wonders why "notifications stopped working" mid-session.
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound, .badge])
    }

    /// Notification tapped → deep-link to the exact word the body described.
    /// WordFeedView listens for `.openWord` and presents `WordDetailView` for that id.
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        if let raw = response.notification.request.content.userInfo["wordId"] as? String,
           let id = UUID(uuidString: raw) {
            // Cold-launch path: WordFeedView's `.onReceive(.openWord)` may not be wired up
            // yet, so also stash the id for the feed to drain in its first `.onAppear`.
            Task { @MainActor in NotificationManager.pendingDeepLinkWordId = id }
            NotificationCenter.default.post(name: .openWord, object: id)
        }
        completionHandler()
    }
}

@main
struct VerbumApp: App {
    @UIApplicationDelegateAdaptor(VerbumAppDelegate.self) private var appDelegate
    @StateObject private var userProfile: UserProfileStore
    @StateObject private var subscriptions: SubscriptionManager
    @StateObject private var auth: AuthService
    @StateObject private var language = LanguageManager.shared
    @Environment(\.scenePhase) private var scenePhase
    /// Epoch seconds of the last notification reschedule — throttles `rescheduleNotificationsIfNeeded()`
    /// to once per calendar day so a burst of foregroundings doesn't churn UNUserNotificationCenter.
    @AppStorage("verbum.lastNotifRescheduleAt") private var lastNotifRescheduleAt: Double = 0

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
                    // (Game Center auth is deferred to the feed so its sheet can't interrupt
                    // onboarding — see AppCoordinator.)
                    rescheduleNotificationsIfNeeded()
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
                    // External deep link: verbum://word/<uuid> → open that word's detail.
                    guard url.scheme == "verbum", url.host == "word",
                          let id = UUID(uuidString: url.lastPathComponent) else { return }
                    NotificationCenter.default.post(name: .openWord, object: id)
                }
                .onChange(of: scenePhase) { phase in
                    guard phase == .active else { return }
                    // Pull on every foreground (not just at sign-in) so edits made on another
                    // device show up here without re-authenticating. Cheap: networked + LWW merge.
                    if userProfile.profile.appleUserID != nil {
                        Task { await userProfile.cloudKit.pull(into: userProfile) }
                    }
                    // The rolling notification window (see NotificationManager.reschedule) only
                    // needs refreshing once a day — SwiftUI's root `.onAppear` alone doesn't refire
                    // on mere foregrounding, so without this a user who never force-quits the app
                    // would keep the window from advancing/rotating.
                    rescheduleNotificationsIfNeeded()
                }
                // isPro changes the word pool → re-index Spotlight so paid definitions appear
                // (Pro) or are re-locked (lapse).
                .onChange(of: subscriptions.isPro) { isPro in
                    SpotlightIndexer.indexIfNeeded(
                        words: WordRepository.shared.all,
                        freeIds: Set(WordAccess.freePool().map(\.id)),
                        isPro: isPro,
                        language: WordRepository.shared.activeLanguage,
                        version: WordDatabase.bundledDBVersion
                    )
                }
        }
    }

    /// Re-issues the rolling notification window (see NotificationManager.reschedule) at most once
    /// per calendar day. Called from both cold launch and every foreground, so a returning user's
    /// window keeps advancing/rotating without spamming UNUserNotificationCenter on rapid
    /// background/foreground cycles within the same day.
    private func rescheduleNotificationsIfNeeded() {
        guard userProfile.profile.notificationsEnabled else { return }
        let last = Date(timeIntervalSince1970: lastNotifRescheduleAt)
        guard !userProfile.dayCalendar.isDateInToday(last) else { return }
        lastNotifRescheduleAt = Date().timeIntervalSince1970
        NotificationManager.reschedule(
            count: userProfile.profile.notificationCount,
            startHour: NotificationManager.hoursFrom(userProfile.profile.notificationStart),
            endHour: NotificationManager.hoursFrom(userProfile.profile.notificationEnd),
            seenIds: Set(userProfile.profile.seenWordIds),
            // A generous pool (not just today's slot count) so the day-to-day rotation actually
            // surfaces different WORDS over time, not just the same few reordered.
            personalWords: userProfile.reminderWords(limit: 50),
            calendar: userProfile.dayCalendar
        )
    }
}
