import SwiftUI

struct HistoryView: View {
    @EnvironmentObject var userProfile: UserProfileStore

    private var seen: [Word] {
        // seenWordIds is oldest-first; reverse so most recent appears at top
        WordRepository.shared.words(ids: userProfile.profile.seenWordIds.reversed())
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
