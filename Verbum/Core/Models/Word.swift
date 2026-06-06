import Foundation

struct Word: Identifiable, Codable {
    let id: UUID
    let text: String
    let phonetic: String
    let partOfSpeech: String
    let definition: String
    let exampleSentence: String?
    let synonyms: [String]
    let category: String
    let isNew: Bool  // deprecated: use isNew(for:) — kept for Codable compatibility
    let etymology: String?

    /// Which vocabulary catalogue this word belongs to (BCP-47 base code, e.g. "en", "uk").
    /// The app teaches one language at a time; catalogues are parallel by concept.
    let language: String

    // Enrichment fields (v2 schema — absent in v1 JSON/DB rows)
    let frequencyRank: Int?
    let antonyms: [String]
    let collocations: [String]
    let register: WordRegister?
    let domainTags: [String]

    func isNew(for seenIds: Set<UUID>) -> Bool {
        !seenIds.contains(id)
    }

    /// `partOfSpeech` is stored canonically in English ("noun"/"verb"/"adjective"/"adverb") for
    /// every catalogue, so the label is localized at display time (e.g. uk → "іменник",
    /// de → "Substantiv"). Falls back to the raw value for any unmapped value.
    var localizedPartOfSpeech: String {
        let key = partOfSpeech.lowercased()
        guard ["noun", "verb", "adjective", "adverb"].contains(key) else { return partOfSpeech }
        return NSLocalizedString(key, comment: "part of speech")
    }

    /// `category` is stored canonically in English ("Science", "Emotions", …) for every catalogue;
    /// localized at display. Unknown categories fall back to the raw value.
    var localizedCategory: String {
        category.isEmpty ? category : NSLocalizedString(category, comment: "word category")
    }

    init(
        id: UUID, text: String, phonetic: String, partOfSpeech: String,
        definition: String, exampleSentence: String?, synonyms: [String],
        category: String, isNew: Bool, etymology: String?,
        frequencyRank: Int? = nil, antonyms: [String] = [],
        collocations: [String] = [], register: WordRegister? = nil,
        domainTags: [String] = [], language: String = "en"
    ) {
        self.id = id; self.text = text; self.phonetic = phonetic
        self.partOfSpeech = partOfSpeech; self.definition = definition
        self.exampleSentence = exampleSentence; self.synonyms = synonyms
        self.category = category; self.isNew = isNew
        self.etymology = etymology; self.frequencyRank = frequencyRank
        self.antonyms = antonyms; self.collocations = collocations
        self.register = register; self.domainTags = domainTags
        self.language = language
    }

    // Graceful decode — missing enrichment keys default to empty/nil
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id              = try c.decode(UUID.self, forKey: .id)
        text            = try c.decode(String.self, forKey: .text)
        phonetic        = try c.decodeIfPresent(String.self, forKey: .phonetic) ?? ""
        partOfSpeech    = try c.decodeIfPresent(String.self, forKey: .partOfSpeech) ?? ""
        definition      = try c.decode(String.self, forKey: .definition)
        exampleSentence = try c.decodeIfPresent(String.self, forKey: .exampleSentence)
        synonyms        = try c.decodeIfPresent([String].self, forKey: .synonyms) ?? []
        category        = try c.decodeIfPresent(String.self, forKey: .category) ?? ""
        isNew           = try c.decodeIfPresent(Bool.self, forKey: .isNew) ?? false
        etymology       = try c.decodeIfPresent(String.self, forKey: .etymology)
        frequencyRank   = try c.decodeIfPresent(Int.self, forKey: .frequencyRank)
        antonyms        = try c.decodeIfPresent([String].self, forKey: .antonyms) ?? []
        collocations    = try c.decodeIfPresent([String].self, forKey: .collocations) ?? []
        register        = try c.decodeIfPresent(WordRegister.self, forKey: .register)
        domainTags      = try c.decodeIfPresent([String].self, forKey: .domainTags) ?? []
        language        = try c.decodeIfPresent(String.self, forKey: .language) ?? "en"
    }
}

enum WordRegister: String, Codable, CaseIterable {
    case formal, informal, neutral, slang, archaic

    var displayName: String {
        switch self {
        case .formal:   return NSLocalizedString("Formal", comment: "register")
        case .informal: return NSLocalizedString("Informal", comment: "register")
        case .neutral:  return NSLocalizedString("Neutral", comment: "register")
        case .slang:    return NSLocalizedString("Slang", comment: "register")
        case .archaic:  return NSLocalizedString("Archaic", comment: "register")
        }
    }
}

