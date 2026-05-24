import SwiftUI

struct LikedView: View {
    @EnvironmentObject var userProfile: UserProfileStore

    private var liked: [Word] {
        WordRepository.shared.words(ids: userProfile.profile.likedWordIds)
    }

    var body: some View {
        WordListView(
            title: "Liked Words",
            words: liked,
            emptyIcon: "heart",
            emptyMessage: "Like words while reading\nto see them here"
        )
        .environmentObject(userProfile)
    }
}
