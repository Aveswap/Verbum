import CoreSpotlight
import UniformTypeIdentifiers
import Foundation

/// Indexes the word catalogue into iOS Spotlight so words are findable system-wide.
/// Tapping a Spotlight result re-opens the app via `CSSearchableItemActionType`
/// (handled in VerbumApp) and deep-links to the word's detail.
enum SpotlightIndexer {
    static let domain = "com.verbum.app.words"
    private static let indexedVersionKey = "verbum.spotlightVersion"

    /// Indexes the catalogue once per content version. Cheap no-op on every launch after the
    /// first because the indexed version is persisted. Runs off the main thread.
    static func indexIfNeeded(words: [Word], version: Int) {
        guard !words.isEmpty else { return }
        guard UserDefaults.standard.integer(forKey: indexedVersionKey) < version else { return }

        DispatchQueue.global(qos: .utility).async {
            let items = words.map { word -> CSSearchableItem in
                let attributes = CSSearchableItemAttributeSet(contentType: .text)
                attributes.title = word.text
                attributes.contentDescription = word.definition
                attributes.phoneticPronunciation = word.phonetic
                attributes.keywords = ([word.partOfSpeech, word.category] + word.synonyms)
                    .filter { !$0.isEmpty }
                return CSSearchableItem(
                    uniqueIdentifier: word.id.uuidString,
                    domainIdentifier: domain,
                    attributeSet: attributes
                )
            }
            CSSearchableIndex.default().indexSearchableItems(items) { error in
                if error == nil {
                    UserDefaults.standard.set(version, forKey: indexedVersionKey)
                }
            }
        }
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
