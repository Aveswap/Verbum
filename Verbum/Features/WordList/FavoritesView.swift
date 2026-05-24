import SwiftUI

struct FavoritesView: View {
    @EnvironmentObject var userProfile: UserProfileStore

    private var bookmarked: [Word] {
        WordRepository.shared.words(ids: userProfile.profile.bookmarkedWordIds)
    }

    var body: some View {
        WordListView(
            title: "Favorites",
            words: bookmarked,
            emptyIcon: "bookmark",
            emptyMessage: "Bookmark words while reading\nto see them here"
        )
        .environmentObject(userProfile)
    }
}
