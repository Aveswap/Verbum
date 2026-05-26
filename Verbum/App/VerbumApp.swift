import SwiftUI

@main
struct VerbumApp: App {
    @StateObject private var userProfile: UserProfileStore
    @StateObject private var subscriptions = SubscriptionManager()
    @StateObject private var auth: AuthService

    init() {
        let store = UserProfileStore()
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
                .preferredColorScheme(.dark)
                .onReceive(auth.$isSignedIn) { signedIn in
                    guard signedIn else { return }
                    Task { await userProfile.cloudKit.pull(into: userProfile) }
                }
        }
    }
}
