import Foundation

/// App-wide constants that depend on App Store Connect registration.
///
/// ⚠️ TODO(App Store): replace `appStoreID` with the real numeric ID once the app is
/// registered in App Store Connect. Every store-facing URL derives from it, so this is the
/// single place to update (rate-app link, share/invite link).
enum AppInfo {
    /// Placeholder until registration. The "Rate App" and "Invite" links won't resolve
    /// until this is the real numeric Apple ID (e.g. "1234567890").
    static let appStoreID = "0000000000"

    /// False while `appStoreID` is still the placeholder. Store-facing buttons (Rate / Share /
    /// Invite) hide themselves until a real ID is set, so they can't lead reviewers/users to a
    /// dead App Store page (App Review "broken functionality").
    static var isStoreIDConfigured: Bool { appStoreID != "0000000000" }

    /// Flip to `true` ONLY after the Game Center leaderboards
    /// (`com.verbum.app.quarterly_points`, `com.verbum.app.all_time_points`) actually exist in
    /// App Store Connect. While false, the Game Center / Global Leaderboard UI is hidden so a
    /// reviewer can't open an empty/broken Game Center screen (App Review 2.1 "broken
    /// functionality") — mirrors `isStoreIDConfigured`.
    static let isGameCenterConfigured = false

    /// Flip to `true` ONLY when the real Sign in with Apple / CloudKit services are restored
    /// (the `_LocalDev-Disabled/*.original` implementations + entitlements). While false, the
    /// Account section (Sign-in button, Delete Account) is hidden so a reviewer can never tap the
    /// stubbed sign-in and see "Sign in is disabled in this local development build" — that's an
    /// App Review 2.1/2.3.1 rejection. Mirrors `isGameCenterConfigured`.
    static let isSignInConfigured = false

    /// App Store product page. Used for the friends invite/share link.
    static var appStoreURL: URL {
        // Force-unwrap is safe: the string is built from a digit constant, always a valid URL.
        URL(string: "https://apps.apple.com/app/id\(appStoreID)")!
    }

    /// Deep link that opens the App Store review prompt for this app.
    static var rateURL: URL {
        URL(string: "https://apps.apple.com/app/id\(appStoreID)?action=write-review")!
    }

    /// Handle shown on shareable word cards. The cards are the primary distribution channel
    /// (content-funnel account), so the call-to-action is "follow us", not the not-yet-live
    /// website. ⚠️ Update to the real handle once the social account is registered.
    static let socialHandle = "@verbum.words"

    /// Legal links shown on the paywall. Built once with a safe fallback so there are no
    /// force-unwrapped `URL(string:)!` at call sites (a future typo can't crash the paywall).
    static let privacyURL = URL(string: "https://verbum.app/privacy") ?? URL(fileURLWithPath: "/")
    static let termsURL = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/") ?? URL(fileURLWithPath: "/")
}
