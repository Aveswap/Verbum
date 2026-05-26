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

    func isNew(for seenIds: Set<UUID>) -> Bool {
        !seenIds.contains(id)
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
