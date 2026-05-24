import Foundation

/// Single source of truth for word data.
/// Reads and decodes words.json exactly once at launch — all other code reads from here.
final class WordRepository {
    static let shared = WordRepository()

    let all: [Word]

    private init() {
        guard let url  = Bundle.main.url(forResource: "words", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let words = try? JSONDecoder().decode([Word].self, from: data)
        else { all = []; return }
        all = words
    }

    // MARK: - Filtered access (all cheap — no I/O)

    func words(level: WordLevel) -> [Word] {
        all.filter { $0.level == level }
    }

    func words(category: String) -> [Word] {
        all.filter { $0.category.localizedCaseInsensitiveContains(category)
                  || category.localizedCaseInsensitiveContains($0.category) }
    }

    func words(matching query: String) -> [Word] {
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

    func todaysWord() -> Word? {
        guard !all.isEmpty else { return nil }
        let dayIndex = Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 1
        return all[(dayIndex - 1) % all.count]
    }
}
