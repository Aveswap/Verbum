import AuthenticationServices

// ⚠️ LOCAL-DEV STUB — Sign in with Apple disabled for Personal Team builds (no paid Developer Program).
// Original full implementation preserved at: _LocalDev-Disabled/AuthService.swift.original
// Restore before release: replace this file with the original and re-enable the Apple Sign In capability.
// SettingsView's SignInWithAppleButton still renders, but tapping shows a friendly local-dev error.

@MainActor
final class AuthService: NSObject, ObservableObject {

    @Published private(set) var isSignedIn: Bool = false
    @Published private(set) var error: String? = nil

    func clearError() { error = nil }

    private weak var profileStore: UserProfileStore?

    init(profileStore: UserProfileStore) {
        self.profileStore = profileStore
        super.init()
    }

    func handleSignInResult(_ result: Result<ASAuthorization, Error>) {
        // No-op in local dev; surface a friendly hint instead of an Apple "Unknown" error.
        error = "Sign in is disabled in this local development build."
    }

    func signOut() {
        profileStore?.profile.appleUserID = nil
        profileStore?.saveNow()
        isSignedIn = false
    }

    /// Deletes local data only (no CloudKit zone to wipe in stub mode). Always reports success.
    func deleteAccount(completion: @escaping (Bool) -> Void = { _ in }) {
        guard let store = profileStore else { completion(false); return }
        store.deleteAllLocalData()
        isSignedIn = false
        error = nil
        completion(true)
    }

    func refreshCredentialState() async {
        isSignedIn = false
    }
}
