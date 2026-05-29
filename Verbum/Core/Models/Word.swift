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
    let level: WordLevel
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

    init(
        id: UUID, text: String, phonetic: String, partOfSpeech: String,
        definition: String, exampleSentence: String?, synonyms: [String],
        category: String, level: WordLevel, isNew: Bool, etymology: String?,
        frequencyRank: Int? = nil, antonyms: [String] = [],
        collocations: [String] = [], register: WordRegister? = nil,
        domainTags: [String] = [], language: String = "en"
    ) {
        self.id = id; self.text = text; self.phonetic = phonetic
        self.partOfSpeech = partOfSpeech; self.definition = definition
        self.exampleSentence = exampleSentence; self.synonyms = synonyms
        self.category = category; self.level = level; self.isNew = isNew
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
        level           = try c.decodeIfPresent(WordLevel.self, forKey: .level) ?? .beginner
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
        case .formal:   return "Formal"
        case .informal: return "Informal"
        case .neutral:  return "Neutral"
        case .slang:    return "Slang"
        case .archaic:  return "Archaic"
        }
    }
}

enum WordLevel: String, Codable, CaseIterable {
    case beginner, intermediate, expert

    var displayName: String {
        switch self {
        case .beginner:     return "Beginner"
        case .intermediate: return "Intermediate"
        case .expert:       return "Expert"
        }
    }
}
