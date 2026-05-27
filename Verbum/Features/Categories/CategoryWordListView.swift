import SwiftUI

/// Filtered word list opened when user taps a category or level tile.
struct CategoryWordListView: View {
    enum FilterKind {
        case category(String)
        case categoryGroup(name: String, dbCategories: [String])
        case level(WordLevel)
        case partOfSpeech(String)
        case search(String)

        var title: String {
            switch self {
            case .category(let c):              return c
            case .categoryGroup(let n, _):      return n
            case .level(let l):                 return l.displayName
            case .partOfSpeech(let p):          return p.capitalized
            case .search(let q):                return "\"\(q)\""
            }
        }

        func matches(_ word: Word) -> Bool {
            switch self {
            case .category(let c):
                return word.category == c
            case .categoryGroup(_, let cats):
                return cats.contains(word.category)
            case .level(let l):
                return word.level == l
            case .partOfSpeech(let p):
                return word.partOfSpeech.localizedCaseInsensitiveContains(p)
            case .search(let q):
                return word.text.localizedCaseInsensitiveContains(q) ||
                       word.definition.localizedCaseInsensitiveContains(q) ||
                       word.category.localizedCaseInsensitiveContains(q)
            }
        }
    }

    let filter: FilterKind
    @EnvironmentObject var userProfile: UserProfileStore
    @EnvironmentObject var subscriptions: SubscriptionManager
    private let allWords = WordRepository.shared.all

    /// Filter by chosen kind AND honor the free-pool gate so locked words don't leak
    /// into the list. Premium subscribers see everything at their level.
    private var filtered: [Word] {
        let isPro = subscriptions.isPro
        let userLevel = userProfile.profile.level
        return allWords.filter { word in
            filter.matches(word) &&
            WordAccess.canAccess(word, isPro: isPro, userLevel: userLevel)
        }
    }

    var body: some View {
        WordListView(
            title: filter.title,
            words: filtered,
            emptyIcon: "magnifyingglass",
            emptyMessage: "No words to show here yet. Keep swiping the feed to unlock more."
        )
        .environmentObject(userProfile)
        .environmentObject(subscriptions)
    }
}
