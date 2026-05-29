import Foundation
import Combine

@MainActor
class UserProfileStore: ObservableObject {
    @Published var profile: UserProfile {
        didSet { handleProfileChange(from: oldValue) }
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

    private var isTouchingTimestamp = false

    /// Central reaction to any `profile` mutation. Keeps the seen-cache in sync, maintains
    /// the two recency timestamps, and debounces persistence.
    ///
    /// Two distinct timestamps because they answer different questions:
    ///   - `profileUpdatedAt`  — "when did anything change" (record recency, bumped always).
    ///   - `settingsUpdatedAt` — "when were user-editable scalars last edited" (bumped only
    ///     when a scalar actually differs). The CloudKit scalar merge keys on this so a
    ///     device that merely swipes words can't clobber another device's genuine settings
    ///     edit just because swiping kept bumping a global mtime.
    private func handleProfileChange(from oldValue: UserProfile) {
        // Reentrancy guard: the timestamp bumps below mutate `profile`, re-firing didSet.
        guard !isTouchingTimestamp else { scheduleSaveWork(); return }
        isTouchingTimestamp = true

        // Keep the O(1) seen-cache in lockstep with the source of truth (e.g. after a
        // CloudKit pull replaces `profile` wholesale with remote-only seen IDs).
        if oldValue.seenWordIds.count != profile.seenWordIds.count {
            seenSet = Set(profile.seenWordIds)
        }
        if Self.scalarsDiffer(oldValue, profile) {
            profile.settingsUpdatedAt = Date()
        }
        profile.profileUpdatedAt = Date()

        isTouchingTimestamp = false
        scheduleSaveWork()
    }

    /// True if any user-editable scalar (settings the user changes by hand) differs.
    private static func scalarsDiffer(_ a: UserProfile, _ b: UserProfile) -> Bool {
        a.name != b.name
            || a.age != b.age
            || a.gender != b.gender
            || a.nativeLanguage != b.nativeLanguage
            || a.level != b.level
            || a.wordsPerWeek != b.wordsPerWeek
            || a.notificationsEnabled != b.notificationsEnabled
            || a.notificationCount != b.notificationCount
            || a.notificationStart != b.notificationStart
            || a.notificationEnd != b.notificationEnd
            || a.selectedTheme != b.selectedTheme
            || a.dailyGoal != b.dailyGoal
            || a.onboardingCompleted != b.onboardingCompleted
    }

    private func scheduleSaveWork() {
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
        // Crossing detection with >=: using == would never fire again if the user lowered
        // their daily goal below the already-reached count, or if the count ever jumps by >1.
        let wasBelowGoal = profile.wordsLearnedToday < profile.dailyGoal
        profile.wordsLearnedToday += 1
        return wasBelowGoal && profile.wordsLearnedToday >= profile.dailyGoal
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

    // MARK: - FSRS spaced repetition

    /// Records a review for a word with the given rating; updates FSRS state and
    /// bumps mastery (rating ≥ good counts as "correct" for the simple mastery dots).
    func recordReview(_ wordId: UUID, rating: FSRSRating, now: Date = Date()) {
        let key = wordId.uuidString
        let current = profile.reviews[key] ?? WordReview.newCard(now: now)
        let updated = FSRS.next(current, rating: rating, now: now)
        profile.reviews[key] = updated
        bumpMastery(wordId, correct: rating != .again)
    }

    /// Words that are due for review right now (dueDate <= now). Sorted oldest-due first.
    func dueReviews(now: Date = Date()) -> [UUID] {
        let pairs = profile.reviews
            .compactMap { (key, review) -> (UUID, Date)? in
                guard let id = UUID(uuidString: key) else { return nil }
                guard review.state != .new, review.dueDate <= now else { return nil }
                return (id, review.dueDate)
            }
            .sorted { $0.1 < $1.1 }
        return pairs.map(\.0)
    }

    /// Count of reviews due today (for surface badges).
    func dueTodayCount(now: Date = Date()) -> Int {
        profile.reviews.values.filter { $0.state != .new && $0.dueDate <= now }.count
    }

    // MARK: - Decks

    func createDeck(name: String, icon: String = "books.vertical") {
        let deck = WordDeck(name: name, icon: icon, wordIds: [])
        profile.decks.append(deck)
    }

    func deleteDeck(_ id: UUID) {
        profile.decks.removeAll { $0.id == id }
    }

    func toggleWord(_ wordId: UUID, in deckId: UUID) {
        guard let idx = profile.decks.firstIndex(where: { $0.id == deckId }) else { return }
        if let wordIdx = profile.decks[idx].wordIds.firstIndex(of: wordId) {
            profile.decks[idx].wordIds.remove(at: wordIdx)
        } else {
            profile.decks[idx].wordIds.append(wordId)
        }
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
            } else if diff > 1, profile.streakFreezes >= (diff - 1) {
                // Only spend freezes when they fully cover the gap — a partial burn would
                // reset the streak AND consume the freezes for zero benefit.
                let missedDays = diff - 1
                profile.streakFreezes -= missedDays
                for _ in 0..<missedDays { profile.streakFreezeUsedDates.append(Date()) }
                profile.currentStreak += 1  // streak survives, continues
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
        // Push to Game Center (no-op if not authenticated / capability not enabled)
        GameCenterService.shared.submitScore(profile.quarterlyPoints,
                                             to: GameCenterService.LeaderboardID.quarterlyPoints)
        GameCenterService.shared.submitScore(profile.totalPoints,
                                             to: GameCenterService.LeaderboardID.allTimePoints)
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

