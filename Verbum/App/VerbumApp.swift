import SwiftUI

@main
struct VerbumApp: App {
    @StateObject private var userProfile = UserProfileStore()
    @StateObject private var subscriptions = SubscriptionManager()

    var body: some Scene {
        WindowGroup {
            AppCoordinator()
                .environmentObject(userProfile)
                .environmentObject(subscriptions)
                .preferredColorScheme(.dark)
        }
    }
}
