import Foundation

struct UserProfile: Codable {
    var name: String = ""
    var age: AgeRange? = nil
    var gender: Gender? = nil
    var level: WordLevel = .beginner
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
    var seenWordIds: [UUID] = []
    var totalPoints: Int = 0
    var quarterlyPoints: Int = 0
    var quarterlyResetDate: Date = Date()
    var earnedBadges: [EarnedBadge] = []
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
    case dark, light, forest, ocean, sunset, midnight

    var displayName: String {
        switch self {
        case .dark:     return "Dark"
        case .light:    return "Light"
        case .forest:   return "Forest"
        case .ocean:    return "Ocean"
        case .sunset:   return "Sunset"
        case .midnight: return "Midnight"
        }
    }
}
