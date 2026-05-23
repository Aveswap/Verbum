import SwiftUI

struct FavoritesView: View {
    @EnvironmentObject var userProfile: UserProfileStore
    private let allWords = WordData.loadAll()

    private var bookmarked: [Word] {
        let ids = userProfile.profile.bookmarkedWordIds
        return allWords.filter { ids.contains($0.id) }
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
