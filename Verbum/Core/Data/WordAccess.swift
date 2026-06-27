import Foundation

/// Single source of truth for the soft-paywall model.
///
/// There are no difficulty levels — every word is just an interesting word. Free users get the
/// top **`freeLimit`** words of their active language (by `frequencyRank` ASC, most-common first),
/// excluding premium-category words; Pro unlocks the whole catalogue.
///
/// Every consumer (feed, practice, challenges, categories, notifications, widget) MUST go through
/// this service to decide what a free user may see, so the rules stay consistent across surfaces.
@MainActor
enum WordAccess {
    /// Number of free words a user gets (per active language).
    static let freeLimit = 50

    /// DB `category` values that live behind the premium bucket. Free users never see these.
    static let premiumDbCategories: Set<String> = [
        "Technology", "Science", "Literature", "Society"
    ]

    /// Source of the full catalog (already scoped to the active language). Defaults to the live
    /// repository; overridable in tests. Assign then call `invalidate()` to drop the memoized pool.
    static var catalogProvider: @MainActor () -> [Word] = { WordRepository.shared.all }

    private static var poolCache: [Word]?
    private static var poolIdCache: Set<UUID>?

    /// Drops the memoized pool. Call whenever `WordRepository.all` changes (catalog or language).
    static func invalidate() {
        poolCache = nil
        poolIdCache = nil
    }

    /// Hand-curated opening words — the "trailer" a brand-new free user meets, in this exact order.
    /// These are GUARANTEED free and shown FIRST regardless of frequencyRank or premium category,
    /// so the most stunning words lead and the first impression is designed, not random. Durable
    /// across word re-imports (it keys on text, not on rank). Lowercased. Extend toward ~50 to fully
    /// curate the free sample; the rest of the pool fills by frequencyRank.
    static let curatedFront: [String] = [
        "petrichor", "hiraeth", "gloaming", "saudade", "susurrus",
        "hygge", "komorebi", "mellifluous", "ineffable", "serendipity",
    ]

    /// The free pool: the curated front first (forced free, in order), then filled to `freeLimit`
    /// from the remaining non-premium words by frequencyRank ASC (stable text tiebreaker).
    static func freePool() -> [Word] {
        if let cached = poolCache { return cached }
        let all = catalogProvider()
        // 1) Curated front, resolved in curated order — forced in even if their category is premium.
        let byText = Dictionary(all.map { ($0.text.lowercased(), $0) }, uniquingKeysWith: { a, _ in a })
        let front = curatedFront.compactMap { byText[$0] }
        let frontIds = Set(front.map(\.id))
        // 2) Fill the rest by frequencyRank, excluding premium categories and the curated front.
        let rest = all
            .filter { !premiumDbCategories.contains($0.category) && !frontIds.contains($0.id) }
            .sorted { a, b in
                let ar = a.frequencyRank ?? Int.max
                let br = b.frequencyRank ?? Int.max
                if ar != br { return ar < br }
                return a.text.lowercased() < b.text.lowercased()
            }
        let pool = Array((front + rest).prefix(freeLimit))
        poolCache = pool
        poolIdCache = Set(pool.map(\.id))
        return pool
    }

    /// True if the given word is reachable in the user's current state.
    static func canAccess(_ word: Word, isPro: Bool) -> Bool {
        if isPro { return true }
        if premiumDbCategories.contains(word.category) { return false }
        _ = freePool()  // ensure the id-set is populated
        return poolIdCache?.contains(word.id) ?? false
    }

    /// Count of free words the user has NOT yet seen. Drives the "5 left" counter / paywall tease.
    static func remainingFreeCount(seenIds: Set<UUID>) -> Int {
        freePool().filter { !seenIds.contains($0.id) }.count
    }

    /// Active-language words that are NOT in the free pool — i.e. everything a Pro unlock adds.
    /// Counts both premium-category words and any words beyond the free cap, so it's correct even
    /// when the catalogue is smaller than `freeLimit` (then it's just the premium-locked words).
    static func lockedCount() -> Int {
        max(0, catalogProvider().count - freePool().count)
    }
}
