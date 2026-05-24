import SwiftUI

struct LikedView: View {
    @EnvironmentObject var userProfile: UserProfileStore
    private let allWords = WordRepository.shared.all

    private var liked: [Word] {
        let ids = userProfile.profile.likedWordIds
        return allWords.filter { ids.contains($0.id) }
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
