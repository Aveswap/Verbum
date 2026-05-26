import Foundation

/// Single source of truth for word data.
/// Uses local SQLite (WordDatabase) when available; falls back to the bundled words.json.
/// After the database downloads, call reloadFromDatabase() to switch sources without a restart.
final class WordRepository {
    static let shared = WordRepository()

    // First 200 words for the swipe feed; all list/category views use query methods directly.
    private(set) var all: [Word] = []

    /// Total word count across the active source (DB or bundle).
    var totalWordCount: Int {
        WordDatabase.shared.isAvailable ? WordDatabase.shared.totalCount() : all.count
    }

    private init() {
        load()
    }

    // MARK: - Source switching

    private func load() {
        if WordDatabase.shared.isAvailable {
            all = WordDatabase.shared.fetchWords(limit: 0)
        } else {
            all = loadBundle()
        }
    }

    func reloadFromDatabase() {
        guard WordDatabase.shared.isAvailable else { return }
        all = WordDatabase.shared.fetchWords(limit: 0)
    }

    // MARK: - Filtered access

    func words(level: WordLevel) -> [Word] {
        if WordDatabase.shared.isAvailable {
            return WordDatabase.shared.fetchWords(level: level)
        }
        return all.filter { $0.level == level }
    }

    func words(category: String) -> [Word] {
        if WordDatabase.shared.isAvailable {
            return WordDatabase.shared.search(query: category, limit: 300)
        }
        return all.filter {
            $0.category.localizedCaseInsensitiveContains(category)
            || category.localizedCaseInsensitiveContains($0.category)
        }
    }

    func words(matching query: String) -> [Word] {
        if WordDatabase.shared.isAvailable {
            return WordDatabase.shared.search(query: query)
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
            fetched = WordDatabase.shared.fetchWords(ids: ids)
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
            return WordDatabase.shared.todaysWord()
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
