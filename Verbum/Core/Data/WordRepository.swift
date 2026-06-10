import Foundation
import Combine

/// Single source of truth for word data.
/// Uses local SQLite (WordDatabase) when available; falls back to the bundled words.json.
/// After the database downloads, call reloadFromDatabase() to switch sources without a restart.
///
/// Design note: the whole catalog is deliberately materialized into `all` and kept resident
/// for the app's lifetime. At ~1000 words this is a small, steady footprint and lets the feed
/// / WordAccess / categories read synchronously without per-access SQLite round-trips. The
/// DB's filtered query methods (words(category:), search…) are used for the
/// targeted fetches that shouldn't pull the full catalog. If the catalog grows much larger,
/// revisit this and query on demand instead.
@MainActor
final class WordRepository: ObservableObject {
    static let shared = WordRepository()

    /// Words of the currently-active language only. The app teaches one language at a time.
    @Published private(set) var all: [Word] = []

    /// Active vocabulary language (BCP-47 base code). Drives every read below. Set from the
    /// user's profile at launch (which defaults to the device language) — see setLanguage(_:).
    private(set) var activeLanguage: String = "en"

    /// Total word count in the active language. `all` is already the fully materialized
    /// active-language catalogue, so this is O(1) — no need to re-fetch every row from SQLite.
    var totalWordCount: Int { all.count }

    /// Language codes that have a catalogue (≥1 word). Drives the in-app switcher.
    func availableLanguages() -> [String] {
        let langs = WordDatabase.shared.isAvailable
            ? WordDatabase.shared.availableLanguages()
            : Array(Set(all.map(\.language)))
        return langs.isEmpty ? ["en"] : langs
    }

    private init() {
        load()
    }

    // MARK: - Source switching

    /// Switches the active vocabulary language and reloads the catalogue. No-op if unchanged.
    func setLanguage(_ language: String) {
        guard language != activeLanguage else { return }
        activeLanguage = language
        load()
    }

    private func load() {
        if WordDatabase.shared.isAvailable {
            all = WordDatabase.shared.fetchWords(language: activeLanguage)
        } else {
            all = loadBundle().filter { $0.language == activeLanguage }
        }
        WordAccess.invalidate()  // catalog changed — drop memoized free pools
        // Index the conservative free-user view (locked words carry no definition). VerbumApp
        // re-indexes with full descriptions when the user is/becomes Pro.
        // Deferred to the next runloop tick because `WordAccess.freePool()` reads
        // `WordRepository.shared.all` — calling it inline during the singleton's first-time
        // init re-enters the same `dispatch_once`, which traps as a recursive init deadlock.
        let snapshot = all
        DispatchQueue.main.async {
            SpotlightIndexer.indexIfNeeded(
                words: snapshot,
                freeIds: Set(WordAccess.freePool().map(\.id)),
                isPro: false,
                version: WordDatabase.bundledDBVersion
            )
        }
    }

    func reloadFromDatabase() {
        guard WordDatabase.shared.isAvailable else { return }
        load()
    }

    // MARK: - Filtered access (scoped to the active language)

    func words(category: String) -> [Word] {
        if WordDatabase.shared.isAvailable {
            return WordDatabase.shared.fetchWords(category: category, language: activeLanguage)
        }
        return all.filter { $0.category == category }
    }

    func allCategories() -> [String] {
        if WordDatabase.shared.isAvailable {
            return WordDatabase.shared.allCategories(language: activeLanguage)
        }
        return Array(Set(all.map(\.category))).sorted().filter { !$0.isEmpty }
    }

    func words(matching query: String) -> [Word] {
        if WordDatabase.shared.isAvailable {
            return WordDatabase.shared.search(query: query, language: activeLanguage)
        }
        let q = query.lowercased()
        return all.filter {
            $0.text.lowercased().contains(q)
            || $0.definition.lowercased().contains(q)
            || $0.category.lowercased().contains(q)
        }
    }

    func word(id: UUID) -> Word? {
        all.first { $0.id == id }
    }

    /// Fetch words by IDs, preserving the order of the input array.
    /// Uses SQLite batch lookup when DB is available, falls back to in-memory.
    func words(ids: [UUID]) -> [Word] {
        guard !ids.isEmpty else { return [] }
        let fetched: [Word]
        if WordDatabase.shared.isAvailable {
            // Scope to the active language so saved lists (decks/favorites/history) show only
            // the current catalogue's words after a language switch.
            fetched = WordDatabase.shared.fetchWords(ids: ids, language: activeLanguage)
        } else {
            let dict = Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0) })
            fetched = ids.compactMap { dict[$0] }
            return fetched
        }
        let dict = Dictionary(uniqueKeysWithValues: fetched.map { ($0.id, $0) })
        return ids.compactMap { dict[$0] }
    }

    func todaysWord() -> Word? {
        if WordDatabase.shared.isAvailable {
            return WordDatabase.shared.todaysWord(language: activeLanguage)
        }
        guard !all.isEmpty else { return nil }
        let dayIndex = Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 1
        return all[(dayIndex - 1) % all.count]
    }

    // MARK: - Bundle fallback

    private func loadBundle() -> [Word] {
        guard let url   = Bundle.main.url(forResource: "words", withExtension: "json"),
              let data  = try? Data(contentsOf: url),
              let words = try? JSONDecoder().decode([Word].self, from: data)
        else { return [] }
        return words
    }
}
