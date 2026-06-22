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
    var appleUserID: String? = nil  // stable Sign in with Apple identifier
    var wordsPerWeek: Int = 30
    var notificationsEnabled: Bool = false
    var notificationCount: Int = 3
    var notificationStart: String = "09:00"
    var notificationEnd: String = "22:00"
    var selectedTheme: AppTheme = .dark
    var onboardingCompleted: Bool = false
    // Gameplay is opt-in. When false (default) the feed is pure: no batch quiz after 5 swipes,
    // and the gamification surfaces (Practice games, streaks, badges, ranking) stay out of the way.
    var quizEnabled: Bool = false
    // First time the app was opened — anchors the 7-day free-games trial. Synced (earliest wins)
    // so the trial doesn't reset on a new device.
    var firstLaunchDate: Date? = nil
    var bookmarkedWordIds: [UUID] = []
    var likedWordIds: [UUID] = []
    // Last-toggle time per word id (uuidString → date) for like/bookmark. Powers a per-id
    // last-write-wins CloudKit merge, so un-liking / un-bookmarking on one device isn't
    // resurrected by another device's stale union. Bounded by catalogue size.
    var likeChangedAt: [String: Date] = [:]
    var bookmarkChangedAt: [String: Date] = [:]
    // Personal lexicon = bookmarked words, reframed as words the user "claims". `wordNotes` holds
    // the user's own "why this word is mine" line per word id (uuidString → note); `noteChangedAt`
    // powers a per-key last-write-wins CloudKit merge so an edit/clear on one device isn't lost.
    var wordNotes: [String: String] = [:]
    var noteChangedAt: [String: Date] = [:]
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
    // Tombstones for decks the user deleted, so a stale copy on another device can't resurrect
    // them through the union merge. (Append-only; decks are few, so this stays tiny.)
    var deletedDeckIds: [UUID] = []

    // FSRS-4.5 review state keyed by word UUID string
    var reviews: [String: WordReview] = [:]

    // Challenge high scores keyed by ChallengeKind rawValue
    var challengeHighScores: [String: Int] = [:]

    init() {}

    /// Graceful decode — every key is optional-with-default. Without this, the *synthesized*
    /// decoder throws `keyNotFound` for any non-optional field missing from older persisted JSON,
    /// and `UserProfileStore`'s `try?` then silently falls back to a blank `UserProfile()` —
    /// wiping streak, bookmarks, notes and points the first time a shipped build adds a field.
    /// Mirrors the same defaults as the property initialisers above.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        name = try c.decodeIfPresent(String.self, forKey: .name) ?? ""
        age = try c.decodeIfPresent(AgeRange.self, forKey: .age)
        gender = try c.decodeIfPresent(Gender.self, forKey: .gender)
        nativeLanguage = try c.decodeIfPresent(NativeLanguage.self, forKey: .nativeLanguage)
        wordLanguage = try c.decodeIfPresent(String.self, forKey: .wordLanguage) ?? ""
        appleUserID = try c.decodeIfPresent(String.self, forKey: .appleUserID)
        wordsPerWeek = try c.decodeIfPresent(Int.self, forKey: .wordsPerWeek) ?? 30
        notificationsEnabled = try c.decodeIfPresent(Bool.self, forKey: .notificationsEnabled) ?? false
        notificationCount = try c.decodeIfPresent(Int.self, forKey: .notificationCount) ?? 3
        notificationStart = try c.decodeIfPresent(String.self, forKey: .notificationStart) ?? "09:00"
        notificationEnd = try c.decodeIfPresent(String.self, forKey: .notificationEnd) ?? "22:00"
        selectedTheme = try c.decodeIfPresent(AppTheme.self, forKey: .selectedTheme) ?? .dark
        onboardingCompleted = try c.decodeIfPresent(Bool.self, forKey: .onboardingCompleted) ?? false
        quizEnabled = try c.decodeIfPresent(Bool.self, forKey: .quizEnabled) ?? false
        firstLaunchDate = try c.decodeIfPresent(Date.self, forKey: .firstLaunchDate)
        bookmarkedWordIds = try c.decodeIfPresent([UUID].self, forKey: .bookmarkedWordIds) ?? []
        likedWordIds = try c.decodeIfPresent([UUID].self, forKey: .likedWordIds) ?? []
        likeChangedAt = try c.decodeIfPresent([String: Date].self, forKey: .likeChangedAt) ?? [:]
        bookmarkChangedAt = try c.decodeIfPresent([String: Date].self, forKey: .bookmarkChangedAt) ?? [:]
        wordNotes = try c.decodeIfPresent([String: String].self, forKey: .wordNotes) ?? [:]
        noteChangedAt = try c.decodeIfPresent([String: Date].self, forKey: .noteChangedAt) ?? [:]
        currentStreak = try c.decodeIfPresent(Int.self, forKey: .currentStreak) ?? 0
        longestStreak = try c.decodeIfPresent(Int.self, forKey: .longestStreak) ?? 0
        lastOpenedDate = try c.decodeIfPresent(Date.self, forKey: .lastOpenedDate)
        streakTimezone = try c.decodeIfPresent(String.self, forKey: .streakTimezone)
        profileUpdatedAt = try c.decodeIfPresent(Date.self, forKey: .profileUpdatedAt) ?? .distantPast
        settingsUpdatedAt = try c.decodeIfPresent(Date.self, forKey: .settingsUpdatedAt) ?? .distantPast
        streakFreezes = try c.decodeIfPresent(Int.self, forKey: .streakFreezes) ?? 0
        streakFreezeUsedDates = try c.decodeIfPresent([Date].self, forKey: .streakFreezeUsedDates) ?? []
        seenWordIds = try c.decodeIfPresent([UUID].self, forKey: .seenWordIds) ?? []
        totalPoints = try c.decodeIfPresent(Int.self, forKey: .totalPoints) ?? 0
        quarterlyPoints = try c.decodeIfPresent(Int.self, forKey: .quarterlyPoints) ?? 0
        quarterlyResetDate = try c.decodeIfPresent(Date.self, forKey: .quarterlyResetDate) ?? Date()
        earnedBadges = try c.decodeIfPresent([EarnedBadge].self, forKey: .earnedBadges) ?? []
        dailyOpens = try c.decodeIfPresent([Date].self, forKey: .dailyOpens) ?? []
        dailyGoal = try c.decodeIfPresent(Int.self, forKey: .dailyGoal) ?? 5
        wordsLearnedToday = try c.decodeIfPresent(Int.self, forKey: .wordsLearnedToday) ?? 0
        wordsLearnedDate = try c.decodeIfPresent(Date.self, forKey: .wordsLearnedDate) ?? .distantPast
        wordMastery = try c.decodeIfPresent([String: Int].self, forKey: .wordMastery) ?? [:]
        decks = try c.decodeIfPresent([WordDeck].self, forKey: .decks) ?? []
        deletedDeckIds = try c.decodeIfPresent([UUID].self, forKey: .deletedDeckIds) ?? []
        reviews = try c.decodeIfPresent([String: WordReview].self, forKey: .reviews) ?? [:]
        challengeHighScores = try c.decodeIfPresent([String: Int].self, forKey: .challengeHighScores) ?? [:]
    }
}

/// Per-word FSRS-4.5 spaced-repetition state.
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

    /// Localized label (the rawValue is the canonical English key in Localizable.strings).
    var displayName: String { NSLocalizedString(rawValue, comment: "gender") }
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
