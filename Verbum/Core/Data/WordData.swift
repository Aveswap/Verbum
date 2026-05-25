import Foundation

// Legacy namespace — delegates to WordRepository (no extra I/O).
enum WordData {
    static func loadAll() -> [Word] { WordRepository.shared.all }
}
