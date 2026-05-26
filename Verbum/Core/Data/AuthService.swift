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

    func signIn() {
        let provider = ASAuthorizationAppleIDProvider()
        let request  = provider.createRequest()
        request.requestedScopes = [.fullName, .email]

        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self
        controller.performRequests()
    }

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

// MARK: - ASAuthorizationControllerDelegate

extension AuthService: ASAuthorizationControllerDelegate {
    nonisolated func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        guard let cred = authorization.credential as? ASAuthorizationAppleIDCredential else { return }
        Task { @MainActor in
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
        }
    }

    nonisolated func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithError error: Error
    ) {
        Task { @MainActor in
            let nsErr = error as NSError
            if nsErr.code != 1001 {
                self.error = error.localizedDescription
            }
        }
    }
}

// MARK: - ASAuthorizationControllerPresentationContextProviding

extension AuthService: ASAuthorizationControllerPresentationContextProviding {
    nonisolated func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow } ?? ASPresentationAnchor()
    }
}
