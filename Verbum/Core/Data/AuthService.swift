import AuthenticationServices

/// Handles Sign in with Apple authentication.
/// Works standalone — no backend required. The stable Apple `user` ID
/// is stored in UserProfile; email is cached in Keychain (returned only once by Apple).
@MainActor
final class AuthService: NSObject, ObservableObject {

    @Published private(set) var isSignedIn: Bool = false
    @Published private(set) var error: String? = nil

    private static let emailKey = "appleEmail"
    private weak var profileStore: UserProfileStore?

    init(profileStore: UserProfileStore) {
        self.profileStore = profileStore
        super.init()
        Task { await refreshCredentialState() }
    }

    // MARK: - Sign In

    /// Single sign-in entry point. SettingsView's SwiftUI `SignInWithAppleButton` hands its
    /// `Result` here. (The old delegate/presentation-context path was a duplicate and unused.)
    func handleSignInResult(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            guard let cred = authorization.credential as? ASAuthorizationAppleIDCredential else { return }
            profileStore?.profile.appleUserID = cred.user
            if let given = cred.fullName?.givenName, profileStore?.profile.name.isEmpty == true {
                profileStore?.profile.name = given
            }
            if let email = cred.email {
                KeychainHelper.set(email, for: Self.emailKey)
            }
            profileStore?.saveNow()
            isSignedIn = true
            error = nil
        case .failure(let err):
            let nsErr = err as NSError
            if nsErr.code != 1001 {
                self.error = err.localizedDescription
            }
        }
    }

    // MARK: - Sign Out

    func signOut() {
        profileStore?.profile.appleUserID = nil
        profileStore?.saveNow()
        isSignedIn = false
    }

    // MARK: - Delete Account

    func deleteAccount() {
        Task {
            await profileStore?.cloudKit.deleteZone()
            profileStore?.deleteAllLocalData()
            isSignedIn = false
            error = nil
        }
    }

    // MARK: - Credential state check

    func refreshCredentialState() async {
        guard let userID = profileStore?.profile.appleUserID else {
            isSignedIn = false
            return
        }
        let provider = ASAuthorizationAppleIDProvider()
        let state = try? await provider.credentialState(forUserID: userID)
        isSignedIn = state == .authorized
        if state == .revoked || state == .notFound {
            profileStore?.profile.appleUserID = nil
            profileStore?.saveNow()
        }
    }
}
