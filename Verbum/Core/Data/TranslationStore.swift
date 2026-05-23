import Foundation

struct WordTranslation: Codable {
    let d: String   // definition translation
    let e: String?  // example sentence translation
}

final class TranslationStore {
    static let shared = TranslationStore()

    private var data: [String: [String: WordTranslation]] = [:]

    private init() {
        guard let url = Bundle.main.url(forResource: "translations", withExtension: "json"),
              let jsonData = try? Data(contentsOf: url) else { return }
        data = (try? JSONDecoder().decode([String: [String: WordTranslation]].self, from: jsonData)) ?? [:]
    }

    func definition(wordId: UUID, language: String) -> String? {
        data[language]?[wordId.uuidString.lowercased()]?.d
    }

    func example(wordId: UUID, language: String) -> String? {
        data[language]?[wordId.uuidString.lowercased()]?.e
    }

    static let supportedLanguages: [(code: String, name: String)] = [
        ("en", "English only"),
        ("uk", "Українська"),
        ("es", "Español"),
        ("de", "Deutsch"),
        ("fr", "Français"),
        ("pl", "Polski"),
        ("it", "Italiano"),
        ("pt", "Português"),
    ]
}
