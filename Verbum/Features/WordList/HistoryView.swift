import SwiftUI

struct HistoryView: View {
    @EnvironmentObject var userProfile: UserProfileStore
    private let allWords = WordData.loadAll()

    private var seen: [Word] {
        // Preserve seen order (most recent last → show reversed)
        let ids = userProfile.profile.seenWordIds
        let wordMap = Dictionary(uniqueKeysWithValues: allWords.map { ($0.id, $0) })
        return ids.compactMap { wordMap[$0] }.reversed()
    }

    var body: some View {
        WordListView(
            title: "History",
            words: seen,
            emptyIcon: "clock",
            emptyMessage: "Words you've swiped through\nwill appear here"
        )
        .environmentObject(userProfile)
    }
}
