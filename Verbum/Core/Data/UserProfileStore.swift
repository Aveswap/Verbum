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

    /// Pushes are suppressed until the first CloudKit pull has completed. Without this, the
    /// fresh local profile created right after sign-in/reinstall races (and can overwrite) the
    /// server's history before the pull merges it back — the classic "lost my data" bug.
    private var hasCompletedInitialPull = false

    private var pendingDailyOpen = false

    /// Called by CloudKitSyncManager.pull once a merge (or first-push of a new record) finishes,
    /// so subsequent local mutations are allowed to push.
    func markInitialPullComplete() {
        hasCompletedInitialPull = true
        runPendingDailyOpen()
    }

    /// Records the daily open at the RIGHT time. With no iCloud account (or once the first pull
    /// has already merged) it runs immediately; otherwise it's deferred until the pull completes,
    /// so the streak is computed against the merged server state — not the empty local profile on
    /// a fresh install (which would miscount and then get clobbered by the merge).
    func recordDailyOpenWhenReady() {
        if profile.appleUserID == nil || hasCompletedInitialPull {
            recordDailyOpen()
        } else {
            pendingDailyOpen = true
            // Safety net: if the first pull neither succeeds nor fails in time (slow / hung
            // network), record anyway so the streak isn't lost for the session. runPendingDailyOpen
            // is idempotent, so this no-ops if the pull already handled it.
            DispatchQueue.main.asyncAfter(deadline: .now() + 6) { [weak self] in
                self?.runPendingDailyOpen()
            }
        }
    }

    /// Runs a deferred daily open (from pull success OR failure, so an offline launch still
    /// records the streak — best-effort against local state in that case).
    func runPendingDailyOpen() {
        guard pendingDailyOpen else { return }
        pendingDailyOpen = false
        recordDailyOpen()
    }

    init() {
        if let data = UserDefaults.standard.data(forKey: key),
           let saved = try? JSONDecoder().decode(UserProfile.self, from: data) {
            self.profile = saved
        } else {
            self.profile = UserProfile()
        }
        self.seenSet = Set(self.profile.seenWordIds)
        // Defensive de-dup: an earlier bug could append already-seen IDs. seenWordIds is
        // bounded by the catalogue size (~1000), so this stays small; collapse any legacy
        // duplicates so persistence/CloudKit don't carry redundant entries forward.
        if seenSet.count != profile.seenWordIds.count {
            profile.seenWordIds = Array(seenSet)
        }
    }

    // MARK: - Persistence

    private var isTouchingTimestamp = false
    private var isApplyingRemoteMerge = false

    /// Applies a CloudKit-merged profile WITHOUT bumping the recency timestamps. The merged
    /// value already carries the authoritative `max(local, remote)` timestamps; bumping them on
    /// assignment would defeat last-write-wins (a pure pull would "win" over a genuine edit on
    /// another device) and cause an endless pull→push churn across devices on every foreground.
    func applyMerged(_ merged: UserProfile) {
        isApplyingRemoteMerge = true
        profile = merged          // fires didSet synchronously; the flag suppresses the bumps
        isApplyingRemoteMerge = false
    }

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
        // CloudKit pull replaces `profile` wholesale). Rebuild by membership, not by count:
        // a count check silently desyncs the moment the seen-set ever becomes non-monotonic
        // (a future "forget word" / per-language reset). The set is bounded by catalogue size.
        if seenSet.count != profile.seenWordIds.count || !seenSet.isSuperset(of: profile.seenWordIds) {
            seenSet = Set(profile.seenWordIds)
        }
        // Bump recency timestamps only for genuine LOCAL edits — never when applying a remote
        // merge (see applyMerged): the merged profile already holds the authoritative timestamps.
        if !isApplyingRemoteMerge {
            if Self.scalarsDiffer(oldValue, profile) {
                profile.settingsUpdatedAt = Date()
            }
            profile.profileUpdatedAt = Date()
        }

        isTouchingTimestamp = false
        scheduleSaveWork()
    }

    /// True if any user-editable scalar (settings the user changes by hand) differs.
    private static func scalarsDiffer(_ a: UserProfile, _ b: UserProfile) -> Bool {
        a.name != b.name
            || a.age != b.age
            || a.gender != b.gender
            || a.nativeLanguage != b.nativeLanguage
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
        guard profile.appleUserID != nil, hasCompletedInitialPull else { return }
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
        if profile.appleUserID != nil, hasCompletedInitialPull {
            let snapshot = profile
            Task { await cloudKit.push(snapshot) }
        }
    }

    /// The calendar that defines a "user day" for streaks, the daily goal, and the practice gate.
    /// Anchored to the streak's locked timezone (or the device timezone until it's locked at the
    /// first daily open) so every day-boundary calculation agrees even across travel / DST —
    /// previously the streak used the locked TZ while the daily counter used `Calendar.current`,
    /// so they could disagree on what "today" is.
    var dayCalendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: profile.streakTimezone ?? "") ?? .current
        return cal
    }

    // MARK: - Word language (vocabulary catalogue)

    /// Resolves the active vocabulary language and applies it to WordRepository. Called at
    /// launch. Falls back to the device language, then English, among catalogues that exist.
    func applyWordLanguage() {
        let available = WordRepository.shared.availableLanguages()
        let resolved = Self.resolveWordLanguage(stored: profile.wordLanguage, available: available)
        if profile.wordLanguage != resolved { profile.wordLanguage = resolved }  // persists locally
        WordRepository.shared.setLanguage(resolved)
        // Keep the UI language in lockstep with the vocabulary language (resolved at launch).
        LanguageManager.shared.bootstrap(resolved)
    }

    /// Switches the active vocabulary language (from the in-app picker) and reloads.
    func setWordLanguage(_ language: String) {
        guard !language.isEmpty, language != profile.wordLanguage else { return }
        profile.wordLanguage = language
        WordRepository.shared.setLanguage(language)
        // Switch the whole interface to match the new vocabulary language, live.
        LanguageManager.shared.apply(language)
        // Refresh the daily word notifications so they sample from the new language's pool;
        // the existing repeating triggers would otherwise keep firing the old language.
        if profile.notificationsEnabled {
            NotificationManager.reschedule(
                count: profile.notificationCount,
                startHour: NotificationManager.hoursFrom(profile.notificationStart),
                endHour: NotificationManager.hoursFrom(profile.notificationEnd),
                seenIds: seenSet,
                calendar: dayCalendar
            )
        }
    }

    static func resolveWordLanguage(stored: String, available: [String]) -> String {
        if !stored.isEmpty, available.contains(stored) { return stored }
        let device = Locale.preferredLanguages.first
            .flatMap { Locale(identifier: $0).language.languageCode?.identifier }
            ?? Locale.current.language.languageCode?.identifier
            ?? "en"
        if available.contains(device) { return device }
        return available.contains("en") ? "en" : (available.first ?? "en")
    }

    // MARK: - Word interactions

    func bookmarkWord(_ id: UUID) {
        if profile.bookmarkedWordIds.contains(id) {
            profile.bookmarkedWordIds.removeAll { $0 == id }
        } else {
            profile.bookmarkedWordIds.append(id)
        }
        profile.bookmarkChangedAt[id.uuidString] = Date()  // stamp every toggle for per-id LWW
    }

    func likeWord(_ id: UUID) {
        if profile.likedWordIds.contains(id) {
            profile.likedWordIds.removeAll { $0 == id }
        } else {
            profile.likedWordIds.append(id)
        }
        profile.likeChangedAt[id.uuidString] = Date()
    }

    /// Marks a word as seen. Returns true if this caused the daily goal to be reached just now.
    @discardableResult
    func markWordSeen(_ id: UUID) -> Bool {
        guard seenSet.insert(id).inserted else { return false }
        profile.seenWordIds.append(id)
        return recordWordLearned()
    }

    /// Rolls back a swipe-mark when the user proves they didn't actually learn the word —
    /// currently called after a 0/5 batch quiz so those words can resurface in the feed.
    /// Decrements today's learned-count by the number actually rolled back so the daily-goal
    /// progress stays honest.
    func unmarkWordsSeen(_ ids: [UUID]) {
        var removed = 0
        for id in ids where seenSet.contains(id) {
            seenSet.remove(id)
            profile.seenWordIds.removeAll { $0 == id }
            removed += 1
        }
        guard removed > 0 else { return }
        let cal = dayCalendar
        if cal.isDateInToday(profile.wordsLearnedDate) {
            profile.wordsLearnedToday = max(0, profile.wordsLearnedToday - removed)
        }
    }

    /// Increments today's learned-words counter. Resets at local midnight.
    /// Returns true if this swipe completed the daily goal (caller may trigger celebration).
    @discardableResult
    func recordWordLearned() -> Bool {
        let cal = dayCalendar
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
        let cal = dayCalendar
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
        // Tombstone the id so a stale copy on another device doesn't resurrect it on the next
        // CloudKit merge (the merge unions decks but subtracts tombstones).
        if !profile.deletedDeckIds.contains(id) {
            profile.deletedDeckIds.append(id)
        }
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
        // Pure streak math lives in StreakEngine (unit-tested). nil = same calendar day as the
        // last open, so there's nothing to persist.
        guard let updated = StreakEngine.recordOpen(profile, calendar: dayCalendar, now: Date()) else { return }
        profile = updated
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
        guard !dayCalendar.isDateInToday(profile.practiceGamesDate) else { return }
        profile.practiceGamesPlayedToday = 0
        profile.practiceGamesDate = Date()
    }

    // MARK: - Account Deletion

    func deleteAllLocalData() {
        UserDefaults.standard.removeObject(forKey: key)
        KeychainHelper.delete("appleEmail")
        // Tear down everything that outlives the app process, so a deleted account leaves no
        // trace (App Review 5.1.1(v)): pending daily notifications would keep firing, and
        // Spotlight would keep surfacing them.
        NotificationManager.cancelAll()
        NotificationManager.clearBadge()
        SpotlightIndexer.deleteAll()
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
        // Use the streak-locked calendar (not Calendar.current) so the quarter boundary doesn't
        // drift by the device-vs-locked timezone offset after travel/DST — every other day-
        // boundary in this store already uses dayCalendar.
        let cal = dayCalendar
        let now = Date()
        // Advance one exact quarter at a time until the reset date is in the future. This keeps
        // quarter boundaries from drifting (we never snap the anchor to "now") and awards the
        // badge for the FIRST closed quarter even if the user was away for several quarters —
        // subsequent skipped quarters had no activity (0 points), so they earn no badge.
        var didReset = false
        while let nextBoundary = cal.date(byAdding: .month, value: 3, to: profile.quarterlyResetDate),
              now >= nextBoundary {
            if !didReset, let tier = Self.badgeTier(for: profile.quarterlyPoints) {
                let badge = EarnedBadge(
                    tier: tier,
                    period: quarterLabel(for: profile.quarterlyResetDate),
                    points: profile.quarterlyPoints,
                    date: nextBoundary
                )
                profile.earnedBadges.append(badge)
            }
            profile.quarterlyResetDate = nextBoundary
            didReset = true
        }
        if didReset { profile.quarterlyPoints = 0 }
    }

    private func quarterLabel(for date: Date) -> String {
        let month = dayCalendar.component(.month, from: date)
        let year  = dayCalendar.component(.year, from: date)
        return "Q\((month - 1) / 3 + 1) \(year)"
    }
}

