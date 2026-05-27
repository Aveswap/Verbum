import Foundation

struct UserProfile: Codable {
    var name: String = ""
    var age: AgeRange? = nil
    var gender: Gender? = nil
    var nativeLanguage: NativeLanguage? = nil
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
    case ukrainian  = "uk"
    case spanish    = "es"
    case french     = "fr"
    case german     = "de"
    case portuguese = "pt"
    case italian    = "it"
    case polish     = "pl"
    case chinese    = "zh"
    case japanese   = "ja"
    case korean     = "ko"
    case arabic     = "ar"
    case turkish    = "tr"
    case hindi      = "hi"
    case other      = "other"

    var displayName: String {
        switch self {
        case .ukrainian:  return "Ukrainian 🇺🇦"
        case .spanish:    return "Spanish 🇪🇸"
        case .french:     return "French 🇫🇷"
        case .german:     return "German 🇩🇪"
        case .portuguese: return "Portuguese 🇧🇷"
        case .italian:    return "Italian 🇮🇹"
        case .polish:     return "Polish 🇵🇱"
        case .chinese:    return "Chinese 🇨🇳"
        case .japanese:   return "Japanese 🇯🇵"
        case .korean:     return "Korean 🇰🇷"
        case .arabic:     return "Arabic 🇸🇦"
        case .turkish:    return "Turkish 🇹🇷"
        case .hindi:      return "Hindi 🇮🇳"
        case .other:      return "Other"
        }
    }
}
