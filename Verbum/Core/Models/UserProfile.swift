import Foundation

struct UserProfile: Codable {
    var name: String = ""
    var age: AgeRange? = nil
    var gender: Gender? = nil
    var nativeLanguage: NativeLanguage? = nil  // deprecated: translations removed; kept for Codable back-compat
    /// Active vocabulary language (BCP-47 base code, e.g. "en", "uk"). Empty = not yet resolved
    /// (defaults to the device language on first launch). Local-only — intentionally NOT synced
    /// via CloudKit, since the right default can differ per device (OS language).
    var wordLanguage: String = ""
    var level: WordLevel = .beginner
    var appleUserID: String? = nil  // stable Sign in with Apple identifier
    var wordsPerWeek: Int = 30
    var notificationsEnabled: Bool = false
    var notificationCount: Int = 3
    var notificationStart: String = "09:00"
    var notificationEnd: String = "22:00"
    var selectedTheme: AppTheme = .dark
    var onboardingCompleted: Bool = false
    var bookmarkedWordIds: [UUID] = []
    var likedWordIds: [UUID] = []
    var currentStreak: Int = 0
    var longestStreak: Int = 0
    var lastOpenedDate: Date? = nil
    var streakTimezone: String? = nil  // IANA identifier; locked at first daily open
    var profileUpdatedAt: Date = .distantPast  // bumped on every change; used for CloudKit record recency
    var settingsUpdatedAt: Date = .distantPast // bumped ONLY when a user-editable scalar changes; used for scalar LWW merge
    var streakFreezes: Int = 0         // available freezes; +1 per 7-day streak milestone
    var streakFreezeUsedDates: [Date] = []
    var seenWordIds: [UUID] = []
    var totalPoints: Int = 0
    var quarterlyPoints: Int = 0
    var quarterlyResetDate: Date = Date()
    var earnedBadges: [EarnedBadge] = []

    // Practice gate — resets at local midnight each day
    var practiceGamesPlayedToday: Int = 0
    var practiceGamesDate: Date = .distantPast

    // Daily opens: up to one date per calendar day, trimmed to last 7 days
    var dailyOpens: [Date] = []

    // Daily learning goal — words swiped per day before celebration
    var dailyGoal: Int = 5
    var wordsLearnedToday: Int = 0
    var wordsLearnedDate: Date = .distantPast

    // Word mastery: 0 (unseen) → 5 (mastered). +1 on quiz correct, -1 on quiz wrong.
    // Keyed by word UUID as string for Codable compatibility.
    var wordMastery: [String: Int] = [:]

    // Custom decks created by the user (e.g. "Travel words", "SAT prep")
    var decks: [WordDeck] = []

    // FSRS-5 review state keyed by word UUID string
    var reviews: [String: WordReview] = [:]

    // Challenge high scores keyed by ChallengeKind rawValue
    var challengeHighScores: [String: Int] = [:]

    static let freePracticeLimit = 3
}

/// Per-word FSRS-5 spaced-repetition state.
/// Updated on every quiz answer; controls when the word resurfaces in the feed.
struct WordReview: Codable, Hashable {
    var stability: Double          // S — interval in days where retention drops to 90%
    var difficulty: Double         // D — 1...10
    var elapsedDays: Double        // days between last and current review
    var scheduledDays: Double      // interval that was scheduled at last review
    var reps: Int                  // total successful reviews
    var lapses: Int                // times rated "again" after a successful review
    var state: ReviewState
    var lastReview: Date?
    var dueDate: Date              // when the word is next eligible for review

    enum ReviewState: String, Codable { case new, learning, review, relearning }

    /// Convenience initializer for a brand-new (never reviewed) card.
    static func newCard(now: Date = Date()) -> WordReview {
        WordReview(
            stability: 0, difficulty: 0,
            elapsedDays: 0, scheduledDays: 0,
            reps: 0, lapses: 0,
            state: .new, lastReview: nil,
            dueDate: now
        )
    }
}

struct WordDeck: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var name: String
    var icon: String       // SF Symbol name
    var wordIds: [UUID]
    var createdAt: Date = Date()
}

enum AgeRange: String, Codable, CaseIterable {
    case teen       = "13-17"
    case youngAdult = "18-24"
    case adult1     = "25-34"
    case adult2     = "35-44"
    case adult3     = "45-54"
    case senior     = "55+"
}

enum Gender: String, Codable, CaseIterable {
    case male          = "Male"
    case female        = "Female"
    case preferNotToSay = "Prefer not to say"
}

enum AppTheme: String, Codable, CaseIterable {
    case dark

    var displayName: String { "Dark" }
}

enum NativeLanguage: String, Codable, CaseIterable {
    // Supported translation languages — phase 1 ships uk only; de/it/fr follow.
    // Other locales decode to nil (Codable optional) and the user is treated as
    // having no native language selected — translation UI gracefully omits.
    case ukrainian = "uk"
    case german    = "de"
    case italian   = "it"
    case french    = "fr"
    case other     = "other"

    var displayName: String {
        switch self {
        case .ukrainian: return "Ukrainian 🇺🇦"
        case .german:    return "German 🇩🇪"
        case .italian:   return "Italian 🇮🇹"
        case .french:    return "French 🇫🇷"
        case .other:     return "Other"
        }
    }
}
