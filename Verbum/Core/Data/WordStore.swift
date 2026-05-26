import Foundation
import Combine

class UserProfileStore: ObservableObject {
    @Published var profile: UserProfile {
        didSet { scheduleSave() }
    }

    private let key = "userProfile"
    private var saveWorkItem: DispatchWorkItem?

    init() {
        if let data = UserDefaults.standard.data(forKey: key),
           let saved = try? JSONDecoder().decode(UserProfile.self, from: data) {
            self.profile = saved
        } else {
            self.profile = UserProfile()
        }
    }

    // MARK: - Persistence

    /// Debounced: coalesces rapid writes (e.g. swiping through words)
    /// into a single UserDefaults write 0.5 s after the last change.
    private func scheduleSave() {
        saveWorkItem?.cancel()
        let item = DispatchWorkItem { [weak self] in
            self?.persist()
        }
        saveWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: item)
    }

    /// Immediate write — call for critical state (streak, points, onboarding).
    func saveNow() {
        saveWorkItem?.cancel()
        persist()
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(profile) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    // MARK: - Word interactions

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

    // MARK: - Streak

    func recordDailyOpen() {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        if let last = profile.lastOpenedDate {
            let lastDay = cal.startOfDay(for: last)
            if cal.isDate(lastDay, inSameDayAs: today) { return }
            let diff = cal.dateComponents([.day], from: lastDay, to: today).day ?? 0
            profile.currentStreak = diff == 1 ? profile.currentStreak + 1 : 1
        } else {
            profile.currentStreak = 1
        }
        profile.longestStreak = max(profile.longestStreak, profile.currentStreak)
        profile.lastOpenedDate = Date()
        saveNow()
    }

    // MARK: - Onboarding

    func resetOnboarding() {
        profile.onboardingCompleted = false
        saveNow()
    }

    // MARK: - Points

    func addPoints(_ points: Int) {
        checkQuarterlyReset()
        profile.totalPoints += points
        profile.quarterlyPoints += points
        saveNow()
    }

    var currentBadgeTier: BadgeTier? {
        Self.badgeTier(for: profile.quarterlyPoints)
    }

    static func badgeTier(for pts: Int) -> BadgeTier? {
        if pts >= 900 { return .gold }
        if pts >= 400 { return .silver }
        if pts >= 200 { return .bronze }
        return nil
    }

    private func checkQuarterlyReset() {
        let threeMonthsLater = Calendar.current.date(byAdding: .month, value: 3, to: profile.quarterlyResetDate) ?? Date()
        guard Date() >= threeMonthsLater else { return }
        if let tier = Self.badgeTier(for: profile.quarterlyPoints) {
            let badge = EarnedBadge(
                tier: tier,
                period: quarterLabel(for: profile.quarterlyResetDate),
                points: profile.quarterlyPoints,
                date: Date()
            )
            profile.earnedBadges.append(badge)
        }
        profile.quarterlyPoints = 0
        profile.quarterlyResetDate = Date()
    }

    private func quarterLabel(for date: Date) -> String {
        let month = Calendar.current.component(.month, from: date)
        let year  = Calendar.current.component(.year, from: date)
        return "Q\((month - 1) / 3 + 1) \(year)"
    }
}

// WordStore now delegates to the shared repository — no second JSON read.
class WordStore: ObservableObject {
    @Published var words: [Word] = WordRepository.shared.all
}
