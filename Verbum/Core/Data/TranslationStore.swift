import Foundation

struct WordTranslation: Codable {
    let d: String   // definition translation
    let e: String?  // example sentence translation
}

/// Provides translated definitions and examples.
/// Source priority: local SQLite DB (50k words) → bundled translations.json (150 words).
/// Both sources share the same public API — callers need no changes.
final class TranslationStore {
    static let shared = TranslationStore()

    // Bundle fallback: loaded once, used when DB is absent
    private var bundleData: [String: [String: WordTranslation]] = [:]

    private init() {
        loadBundle()
        // When the full DB finishes installing, bundle data can be freed
        NotificationCenter.default.addObserver(
            forName: .wordDatabaseInstalled, object: nil, queue: .main
        ) { [weak self] _ in
            self?.bundleData = [:]
        }
    }

    // MARK: - Public API

    func definition(wordId: UUID, language: String) -> String? {
        if WordDatabase.shared.isAvailable {
            return WordDatabase.shared.translation(wordId: wordId, lang: language)?.definition
        }
        return bundleData[language]?[wordId.uuidString.lowercased()]?.d
    }

    func example(wordId: UUID, language: String) -> String? {
        if WordDatabase.shared.isAvailable {
            return WordDatabase.shared.translation(wordId: wordId, lang: language)?.example
        }
        return bundleData[language]?[wordId.uuidString.lowercased()]?.e
    }

    // MARK: - Supported languages

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

    // MARK: - Bundle

    private func loadBundle() {
        guard let url  = Bundle.main.url(forResource: "translations", withExtension: "json"),
              let data = try? Data(contentsOf: url)
        else { return }
        bundleData = (try? JSONDecoder()
            .decode([String: [String: WordTranslation]].self, from: data)) ?? [:]
    }
}
