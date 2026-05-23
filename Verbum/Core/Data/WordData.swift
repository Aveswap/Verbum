import Foundation

// Namespace for static word-loading helpers.
// Actual data lives in Resources/words.json and is loaded by WordStore.
enum WordData {
    static func loadAll() -> [Word] {
        guard let url = Bundle.main.url(forResource: "words", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let words = try? JSONDecoder().decode([Word].self, from: data)
        else { return [] }
        return words
    }

    static func wordForToday() -> Word? {
        let words = loadAll()
        guard !words.isEmpty else { return nil }
        let dayIndex = Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 1
        return words[(dayIndex - 1) % words.count]
    }
}
