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

    /// App Store product page. Used for the friends invite/share link.
    static var appStoreURL: URL {
        // Force-unwrap is safe: the string is built from a digit constant, always a valid URL.
        URL(string: "https://apps.apple.com/app/id\(appStoreID)")!
    }

    /// Deep link that opens the App Store review prompt for this app.
    static var rateURL: URL {
        URL(string: "https://apps.apple.com/app/id\(appStoreID)?action=write-review")!
    }
}
