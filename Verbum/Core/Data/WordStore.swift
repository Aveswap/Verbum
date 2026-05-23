import Foundation
import Combine

class UserProfileStore: ObservableObject {
    @Published var profile: UserProfile {
        didSet { save() }
    }

    private let key = "userProfile"

    init() {
        if let data = UserDefaults.standard.data(forKey: key),
           let saved = try? JSONDecoder().decode(UserProfile.self, from: data) {
            self.profile = saved
        } else {
            self.profile = UserProfile()
        }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(profile) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    func bookmarkWord(_ id: UUID) {
        if profile.bookmarkedWordIds.contains(id) {
            profile.bookmarkedWordIds.removeAll { $0 == id }
        } else {
            profile.bookmarkedWordIds.append(id)
        }
    }

    func likeWord(_ id: UUID) {
        if profile.likedWordIds.contains(id) {
            profile.likedWordIds.removeAll { $0 == id }
        } else {
            profile.likedWordIds.append(id)
        }
    }

    func markWordSeen(_ id: UUID) {
        if !profile.seenWordIds.contains(id) {
            profile.seenWordIds.append(id)
        }
    }

    /// Call once per app session to update streak
    func recordDailyOpen() {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())

        if let last = profile.lastOpenedDate {
            let lastDay = cal.startOfDay(for: last)
            if cal.isDate(lastDay, inSameDayAs: today) {
                // Already recorded today
                return
            }
            let diff = cal.dateComponents([.day], from: lastDay, to: today).day ?? 0
            if diff == 1 {
                profile.currentStreak += 1
            } else {
                profile.currentStreak = 1
            }
        } else {
            profile.currentStreak = 1
        }

        profile.longestStreak = max(profile.longestStreak, profile.currentStreak)
        profile.lastOpenedDate = Date()
    }

    func resetOnboarding() {
        profile.onboardingCompleted = false
    }
}

class WordStore: ObservableObject {
    @Published var words: [Word] = []

    init() {
        loadWords()
    }

    private func loadWords() {
        guard let url = Bundle.main.url(forResource: "words", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let loaded = try? JSONDecoder().decode([Word].self, from: data)
        else { return }
        self.words = loaded
    }
}
