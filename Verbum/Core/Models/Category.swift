import Foundation

struct WordCategory: Identifiable, Codable {
    let id: UUID
    let name: String
    let icon: String
    let isLocked: Bool
}
