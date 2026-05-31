import Foundation

/// Single source of truth for the soft-paywall model:
///
/// Free users get **50 words per level**, picked by `frequencyRank` ASC (most-common first),
/// excluding any word whose category sits inside a premium bucket. Premium subscribers see
/// the full catalog of their currently-selected level — switching levels exposes a fresh
/// pool naturally because state is derived from `seenWordIds`.
///
/// Every consumer (feed, practice, challenges, categories, notifications, widget) MUST go
/// through this service to decide what a free user is allowed to see, so the rules stay
/// consistent across surfaces.
@MainActor
enum WordAccess {
    /// Number of free words a user gets at their current level.
    static let freeLimit = 50

    /// DB `category` values that live behind a premium bucket in CategoriesView.
    /// Free users never see these regardless of level.
    static let premiumDbCategories: Set<String> = [
        "Technology", "Science", "Literature", "Society"
    ]

    /// Source of the full catalog. Defaults to the live repository; overridable in tests so the
    /// paywall rules can be exercised against a fixture catalog without booting the database.
    /// Assign a new provider then call `invalidate()` to drop any memoized pools.
    static var catalogProvider: @MainActor () -> [Word] = { WordRepository.shared.all }

    /// Memoized free pool per level + its id-set for O(1) membership. The pool is a pure
    /// function of the catalog, so it's cached and only recomputed after `invalidate()`
    /// (called when the catalog reloads). Without this, `freePool` re-filtered and re-sorted
    /// the whole catalog on every call — including per-frame during a card drag and per
    /// bucket × word in CategoriesView — which made the feed feel sticky at 1000 words.
    private static var poolCache: [WordLevel: [Word]] = [:]
    private static var poolIdCache: [WordLevel: Set<UUID>] = [:]

    /// Drops the memoized pools. Call whenever `WordRepository.all` changes.
    static func invalidate() {
        poolCache = [:]
        poolIdCache = [:]
    }

    /// Top `freeLimit` words at the given level, deterministically ordered by
    /// frequencyRank ASC (with a stable text-based tiebreaker so the same 50 are
    /// chosen across launches even when ranks are nil — e.g. bundled JSON).
    static func freePool(level: WordLevel) -> [Word] {
        if let cached = poolCache[level] { return cached }
        let candidates = catalogProvider().filter {
            $0.level == level && !premiumDbCategories.contains($0.category)
        }
        let sorted = candidates.sorted { a, b in
            let ar = a.frequencyRank ?? Int.max
            let br = b.frequencyRank ?? Int.max
            if ar != br { return ar < br }
            return a.text.lowercased() < b.text.lowercased()
        }
        let pool = Array(sorted.prefix(freeLimit))
        poolCache[level] = pool
        poolIdCache[level] = Set(pool.map(\.id))
        return pool
    }

    /// All words a user can access right now. Pro = entire catalog at their level.
    /// Free = the level's freePool only.
    static func accessibleWords(isPro: Bool, level: WordLevel) -> [Word] {
        if isPro {
            return catalogProvider().filter { $0.level == level }
        }
        return freePool(level: level)
    }

    /// True if the given word is reachable in the user's current state.
    static func canAccess(_ word: Word, isPro: Bool, userLevel: WordLevel) -> Bool {
        if isPro { return true }
        guard word.level == userLevel else { return false }
        if premiumDbCategories.contains(word.category) { return false }
        _ = freePool(level: userLevel)  // ensure the id-set is populated
        return poolIdCache[userLevel]?.contains(word.id) ?? false
    }

    /// Count of accessible words at `userLevel` the user has NOT yet seen.
    /// Drives the "5 left" counter and the paywall tease copy.
    static func remainingFreeCount(seenIds: Set<UUID>, userLevel: WordLevel) -> Int {
        freePool(level: userLevel).filter { !seenIds.contains($0.id) }.count
    }

    /// Total words at `userLevel` that are NOT in the free pool. Used for tease text:
    /// "Unlock N more {level} words".
    static func lockedAtLevelCount(userLevel: WordLevel) -> Int {
        let total = catalogProvider().filter { $0.level == userLevel }.count
        return max(0, total - freeLimit)
    }
}
