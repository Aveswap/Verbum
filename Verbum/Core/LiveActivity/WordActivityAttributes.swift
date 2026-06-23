import ActivityKit
import Foundation

/// Payload for the "word spotlight" Live Activity — pins a word to the Lock Screen and the
/// Dynamic Island. Shared between the app (which starts/ends it) and the widget extension
/// (which renders it), so it carries plain strings only — no app-model dependency.
struct WordActivityAttributes: ActivityAttributes {
    /// The mutable part. `revealed` lets an `update(...)` animate the definition in/out.
    public struct ContentState: Codable, Hashable {
        var revealed: Bool = true
    }

    let word: String
    let phonetic: String
    let partOfSpeech: String   // already abbreviated, e.g. "(n.)"
    let definition: String
    let wordID: String          // for the verbum://word/<id> deep link on tap
}
