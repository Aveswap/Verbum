import Foundation

/// Loads `translations.json` from the app bundle into memory.
/// Used as a fallback by `WordDatabase.translation(wordId:lang:)` when the
/// downloaded SQLite DB is not yet available.
final class TranslationStore {
    static let shared = TranslationStore()

    private var cache: [String: [String: WordDatabase.Translation]] = [:]

    private init() {
        guard
            let url  = Bundle.main.url(forResource: "translations", withExtension: "json"),
            let data = try? Data(contentsOf: url),
            let root = try? JSONSerialization.jsonObject(with: data)
                           as? [String: [String: [String: String]]]
        else { return }

        for (lang, entries) in root {
            cache[lang] = Dictionary(
                uniqueKeysWithValues: entries.compactMap { wordId, fields in
                    guard let def = fields["d"] else { return nil }
                    let key   = wordId.lowercased()
                    let value = WordDatabase.Translation(definition: def, example: fields["e"])
                    return (key, value)
                }
            )
        }
    }

    func translation(wordId: UUID, lang: String) -> WordDatabase.Translation? {
        cache[lang]?[wordId.uuidString.lowercased()]
    }
}
