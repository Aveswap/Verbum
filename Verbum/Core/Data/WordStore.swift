import Foundation
import Combine

@MainActor
class UserProfileStore: ObservableObject {
    @Published var profile: UserProfile {
        didSet { scheduleSave() }
    }

    let cloudKit = CloudKitSyncManager()
    private let key = "userProfile"
    private var saveWorkItem: DispatchWorkItem?
    private var cloudKitWorkItem: DispatchWorkItem?
    private var seenSet: Set<UUID> = []

    init() {
        if let data = UserDefaults.standard.data(forKey: key),
           let saved = try? JSONDecoder().decode(UserProfile.self, from: data) {
            self.profile = saved
        } else {
            self.profile = UserProfile()
        }
        self.seenSet = Set(self.profile.seenWordIds)
    }

    // MARK: - Persistence

    private func scheduleSave() {
        saveWorkItem?.cancel()
        let item = DispatchWorkItem { [weak self] in
            self?.persistLocally()
        }
        saveWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: item)
        scheduleCloudKitPush()
    }

    private func scheduleCloudKitPush() {
        guard profile.appleUserID != nil else { return }
        cloudKitWorkItem?.cancel()
        let item = DispatchWorkItem { [weak self] in
            guard let self else { return }
            let snapshot = self.profile
            Task { await self.cloudKit.push(snapshot) }
        }
        cloudKitWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 10, execute: item)
    }

    func saveNow() {
        saveWorkItem?.cancel()
        cloudKitWorkItem?.cancel()
        persist()
    }

    private func persistLocally() {
        if let data = try? JSONEncoder().encode(profile) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    private func persist() {
        persistLocally()
        if profile.appleUserID != nil {
            let snapshot = profile
            Task { await cloudKit.push(snapshot) }
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

    /// Marks a word as seen. Returns true if this caused the daily goal to be reached just now.
    @discardableResult
    func markWordSeen(_ id: UUID) -> Bool {
        guard seenSet.insert(id).inserted else { return false }
        profile.seenWordIds.append(id)
        return recordWordLearned()
    }

    /// Increments today's learned-words counter. Resets at local midnight.
    /// Returns true if this swipe completed the daily goal (caller may trigger celebration).
    @discardableResult
    func recordWordLearned() -> Bool {
        let cal = Calendar.current
        if !cal.isDateInToday(profile.wordsLearnedDate) {
            profile.wordsLearnedToday = 0
            profile.wordsLearnedDate = Date()
        }
        let wasBelowGoal = profile.wordsLearnedToday < profile.dailyGoal
        profile.wordsLearnedToday += 1
        let nowAtGoal = profile.wordsLearnedToday == profile.dailyGoal
        return wasBelowGoal && nowAtGoal
    }

    /// Current count of words learned today (resets at local midnight).
    var wordsLearnedToday: Int {
        let cal = Calendar.current
        if !cal.isDateInToday(profile.wordsLearnedDate) { return 0 }
        return profile.wordsLearnedToday
    }

    // MARK: - Word Mastery (0-5)

    func mastery(for wordId: UUID) -> Int {
        profile.wordMastery[wordId.uuidString] ?? 0
    }

    /// Bumps mastery up (correct quiz) or down (wrong). Clamped 0...5.
    func bumpMastery(_ wordId: UUID, correct: Bool) {
        let key = wordId.uuidString
        let current = profile.wordMastery[key] ?? 0
        let delta = correct ? 1 : -1
        let new = max(0, min(5, current + delta))
        profile.wordMastery[key] = new
    }

    // MARK: - Streak

    func recordDailyOpen() {
        // Anchor day boundaries to the user's locked timezone (or current at first launch).
        // Locking prevents the streak from glitching when crossing timezones mid-trip.
        if profile.streakTimezone == nil {
            profile.streakTimezone = TimeZone.current.identifier
        }
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: profile.streakTimezone ?? "UTC") ?? .current
        let today = cal.startOfDay(for: Date())
        if let last = profile.lastOpenedDate {
            let lastDay = cal.startOfDay(for: last)
            if cal.isDate(lastDay, inSameDayAs: today) { return }
            let diff = cal.dateComponents([.day], from: lastDay, to: today).day ?? 0
            if diff == 1 {
                profile.currentStreak += 1
            } else if diff > 1, profile.streakFreezes > 0 {
                // Burn one freeze per missed day, up to available freezes
                let missedDays = diff - 1
                let useable = min(missedDays, profile.streakFreezes)
                profile.streakFreezes -= useable
                for _ in 0..<useable { profile.streakFreezeUsedDates.append(Date()) }
                if useable == missedDays {
                    profile.currentStreak += 1  // streak survives, continues
                } else {
                    profile.currentStreak = 1   // ran out of freezes
                }
            } else {
                profile.currentStreak = 1
            }
        } else {
            profile.currentStreak = 1
        }
        profile.longestStreak = max(profile.longestStreak, profile.currentStreak)
        // Award a freeze for every 7-day streak milestone
        if profile.currentStreak > 0, profile.currentStreak % 7 == 0 {
            profile.streakFreezes = min(profile.streakFreezes + 1, 3)  // cap at 3
        }
        profile.lastOpenedDate = Date()
        // Append today to daily opens (deduplicated, trimmed to last 7 days)
        let sevenDaysAgo = cal.date(byAdding: .day, value: -6, to: today)!
        profile.dailyOpens.removeAll { cal.startOfDay(for: $0) < sevenDaysAgo }
        if !profile.dailyOpens.contains(where: { cal.isDate($0, inSameDayAs: today) }) {
            profile.dailyOpens.append(today)
        }
        saveNow()
    }

    // MARK: - Onboarding

    func resetOnboarding() {
        profile.onboardingCompleted = false
        saveNow()
    }

    // MARK: - Practice gate

    func practiceGamesRemaining() -> Int {
        resetPracticeIfNewDay()
        return max(0, UserProfile.freePracticeLimit - profile.practiceGamesPlayedToday)
    }

    func recordPracticeGame() {
        resetPracticeIfNewDay()
        profile.practiceGamesPlayedToday += 1
        saveNow()
    }

    private func resetPracticeIfNewDay() {
        guard !Calendar.current.isDateInToday(profile.practiceGamesDate) else { return }
        profile.practiceGamesPlayedToday = 0
        profile.practiceGamesDate = Date()
    }

    // MARK: - Account Deletion

    func deleteAllLocalData() {
        UserDefaults.standard.removeObject(forKey: key)
        KeychainHelper.delete("appleEmail")
        profile = UserProfile()
        seenSet = []
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

