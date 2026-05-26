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
    case dark

    var displayName: String { "Dark" }
}

enum NativeLanguage: String, Codable, CaseIterable {
    case ukrainian  = "uk"
    case russian    = "ru"
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
        case .russian:    return "Russian 🇷🇺"
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
