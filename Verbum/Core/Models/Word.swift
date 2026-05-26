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
    let isNew: Bool
    let etymology: String?
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
