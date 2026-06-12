import CoreSpotlight
import UniformTypeIdentifiers
import Foundation

/// Indexes the word catalogue into iOS Spotlight so words are findable system-wide.
/// Tapping a Spotlight result re-opens the app via `CSSearchableItemActionType`
/// (handled in VerbumApp) and deep-links to the word's detail.
enum SpotlightIndexer {
    static let domain = "com.verbum.app.words"
    private static let indexedTokenKey = "verbum.spotlightToken"

    /// Indexes the catalogue into Spotlight, re-indexing only when the content version OR the
    /// Pro state changes (so it's a cheap no-op on most launches). Runs off the main thread.
    ///
    /// **Paywall-aware:** locked words (premium-category / beyond the free pool, for a non-Pro
    /// user) are indexed with their title only — never the definition or synonyms — so the
    /// system search can surface "this word lives in Verbum" without leaking paid content.
    /// When the user goes Pro the full descriptions are re-indexed; when Pro lapses they're
    /// re-locked (`indexSearchableItems` overwrites items by their stable id).
    static func indexIfNeeded(words: [Word], freeIds: Set<UUID>, isPro: Bool, language: String, version: Int) {
        guard !words.isEmpty else { return }
        let token = "\(version)|\(language)|\(isPro)"
        let stored = UserDefaults.standard.string(forKey: indexedTokenKey)
        guard stored != token else { return }
        // If the active language changed, purge the previous language's items first — they carry
        // different ids and would otherwise linger in system search forever (re-indexing only
        // overwrites items with matching ids).
        let storedLang = stored?.split(separator: "|").dropFirst().first.map(String.init)
        let purgeFirst = storedLang != nil && storedLang != language

        DispatchQueue.global(qos: .utility).async {
            if purgeFirst {
                CSSearchableIndex.default().deleteSearchableItems(withDomainIdentifiers: [domain]) { _ in }
            }
            let lockedDescription = NSLocalizedString("Unlock with Verbum Premium",
                                                      comment: "spotlight locked-word description")
            let items = words.map { word -> CSSearchableItem in
                let unlocked = isPro || freeIds.contains(word.id)
                let attributes = CSSearchableItemAttributeSet(contentType: .text)
                attributes.title = word.text
                attributes.contentDescription = unlocked ? word.definition : lockedDescription
                attributes.keywords = unlocked
                    ? ([word.partOfSpeech, word.category] + word.synonyms).filter { !$0.isEmpty }
                    : [word.partOfSpeech].filter { !$0.isEmpty }
                return CSSearchableItem(
                    uniqueIdentifier: word.id.uuidString,
                    domainIdentifier: domain,
                    attributeSet: attributes
                )
            }
            CSSearchableIndex.default().indexSearchableItems(items) { error in
                if error == nil {
                    UserDefaults.standard.set(token, forKey: indexedTokenKey)
                }
            }
        }
    }

    /// Removes every indexed word from Spotlight (used on account deletion) and resets the
    /// memoized token so a fresh sign-in re-indexes from scratch.
    static func deleteAll() {
        UserDefaults.standard.removeObject(forKey: indexedTokenKey)
        CSSearchableIndex.default().deleteSearchableItems(withDomainIdentifiers: [domain]) { _ in }
    }

    /// Pulls the word UUID out of a Spotlight continuation activity, if present.
    static func wordId(from activity: NSUserActivity) -> UUID? {
        guard let id = activity.userInfo?[CSSearchableItemActivityIdentifier] as? String else { return nil }
        return UUID(uuidString: id)
    }
}

extension Notification.Name {
    /// Posted with a `UUID` object when the app should deep-link to a word's detail
    /// (e.g. from a Spotlight result). Observed by WordFeedView.
    static let openWord = Notification.Name("openWord")
}
