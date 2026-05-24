import SwiftUI

/// Filtered word list opened when user taps a category or level tile.
struct CategoryWordListView: View {
    enum FilterKind {
        case category(String)
        case level(WordLevel)
        case partOfSpeech(String)
        case search(String)

        var title: String {
            switch self {
            case .category(let c):     return c
            case .level(let l):        return l.displayName
            case .partOfSpeech(let p): return p.capitalized
            case .search(let q):       return "\"\(q)\""
            }
        }

        func matches(_ word: Word) -> Bool {
            switch self {
            case .category(let c):
                return word.category.localizedCaseInsensitiveContains(c) ||
                       c.localizedCaseInsensitiveContains(word.category)
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
    private let allWords = WordRepository.shared.all

    private var filtered: [Word] {
        allWords.filter { filter.matches($0) }
    }

    var body: some View {
        WordListView(
            title: filter.title,
            words: filtered,
            emptyIcon: "magnifyingglass",
            emptyMessage: "No words found in this category yet.\nMore coming soon!"
        )
        .environmentObject(userProfile)
    }
}
