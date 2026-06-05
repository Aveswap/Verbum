import Foundation

/// Single source of truth for the soft-paywall model.
///
/// The app no longer has difficulty levels — every word is just an interesting word. Free users
/// get the top **`freeLimit`** words of their active language (by `frequencyRank` ASC, most-common
/// first), excluding premium-category words; Pro unlocks the whole catalogue. The `level` /
/// `userLevel` parameters below are kept only so existing call sites compile — they are ignored.
///
/// Every consumer (feed, practice, challenges, categories, notifications, widget) MUST go through
/// this service to decide what a free user may see, so the rules stay consistent across surfaces.
@MainActor
enum WordAccess {
    /// Number of free words a user gets (per active language).
    static let freeLimit = 50

    /// DB `category` values that live behind a premium bucket in CategoriesView.
    /// Free users never see these.
    static let premiumDbCategories: Set<String> = [
        "Technology", "Science", "Literature", "Society"
    ]

    /// Source of the full catalog (already scoped to the active language). Defaults to the live
    /// repository; overridable in tests. Assign then call `invalidate()` to drop the memoized pool.
    static var catalogProvider: @MainActor () -> [Word] = { WordRepository.shared.all }

    /// Memoized free pool + its id-set for O(1) membership. Pure function of the catalog, so it's
    /// cached and recomputed only after `invalidate()` (called when the catalogue/language reloads).
    private static var poolCache: [Word]?
    private static var poolIdCache: Set<UUID>?

    /// Drops the memoized pool. Call whenever `WordRepository.all` changes (catalog or language).
    static func invalidate() {
        poolCache = nil
        poolIdCache = nil
    }

    /// Top `freeLimit` words of the active language, ordered by frequencyRank ASC (stable
    /// text tiebreaker so the same set is chosen across launches even when ranks are nil).
    /// (`_ level` is ignored — kept for source compatibility.)
    static func freePool(level: WordLevel = .beginner) -> [Word] {
        if let cached = poolCache { return cached }
        let candidates = catalogProvider().filter { !premiumDbCategories.contains($0.category) }
        let sorted = candidates.sorted { a, b in
            let ar = a.frequencyRank ?? Int.max
            let br = b.frequencyRank ?? Int.max
            if ar != br { return ar < br }
            return a.text.lowercased() < b.text.lowercased()
        }
        let pool = Array(sorted.prefix(freeLimit))
        poolCache = pool
        poolIdCache = Set(pool.map(\.id))
        return pool
    }

    /// All words a user can access right now. Pro = entire (active-language) catalogue; free = pool.
    static func accessibleWords(isPro: Bool, level: WordLevel = .beginner) -> [Word] {
        isPro ? catalogProvider() : freePool()
    }

    /// True if the given word is reachable in the user's current state. (`userLevel` ignored.)
    static func canAccess(_ word: Word, isPro: Bool, userLevel: WordLevel = .beginner) -> Bool {
        if isPro { return true }
        if premiumDbCategories.contains(word.category) { return false }
        _ = freePool()  // ensure the id-set is populated
        return poolIdCache?.contains(word.id) ?? false
    }

    /// Count of free words the user has NOT yet seen. Drives the "5 left" counter / paywall tease.
    static func remainingFreeCount(seenIds: Set<UUID>, userLevel: WordLevel = .beginner) -> Int {
        freePool().filter { !seenIds.contains($0.id) }.count
    }

    /// Total active-language words that are NOT in the free pool. Used for "Unlock N more words".
    static func lockedAtLevelCount(userLevel: WordLevel = .beginner) -> Int {
        max(0, catalogProvider().count - freeLimit)
    }
}
