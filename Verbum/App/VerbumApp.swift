import SwiftUI

@main
struct VerbumApp: App {
    @StateObject private var userProfile = UserProfileStore()

    var body: some Scene {
        WindowGroup {
            AppCoordinator()
                .environmentObject(userProfile)
                .preferredColorScheme(.dark)
        }
    }
}
