import ActivityKit
import Foundation

/// Payload for the Rush challenge Live Activity — pins the 60-second countdown and live score
/// to the Dynamic Island / Lock Screen while the player is in a Rush run.
///
/// `endDate` is the absolute deadline so the widget can render a self-updating timer via
/// `Text(timerInterval:)` without needing per-second pushes; we only update on score changes.
struct RushActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var score: Int
        var endDate: Date
    }
}
