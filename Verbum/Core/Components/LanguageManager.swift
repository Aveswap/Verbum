import Foundation
import SwiftUI
import ObjectiveC

/// Drives the in-app UI language so the interface matches the vocabulary language the user is
/// learning (which itself defaults to the device language). Switching the word language in
/// Settings re-points string lookups live — no app restart — via a `Bundle` override.
///
/// The lookup keys ARE the English source strings (e.g. `Text("Get Premium")`), so the views
/// need no changes: a missing translation simply falls back to the English key, never a crash.
@MainActor
final class LanguageManager: ObservableObject {
    static let shared = LanguageManager()

    /// BCP-47 base code currently driving the UI ("en", "de", "uk").
    @Published private(set) var language: String = "en"

    /// Languages we ship UI translations for. Anything else falls back to English.
    static let supported: Set<String> = ["en", "de", "uk"]

    private init() {}

    /// Point the UI at `code` if we support it (else English). Idempotent; publishes a change
    /// only when the value actually moves, so SwiftUI rebuilds exactly once per switch.
    func apply(_ code: String) {
        let normalized = Self.supported.contains(code) ? code : "en"
        guard normalized != language else { return }
        language = normalized
        Bundle.setLanguage(normalized)
    }

    /// Resolve + apply at launch, before the first frame, mirroring the word-language resolution.
    func bootstrap(_ code: String) {
        let normalized = Self.supported.contains(code) ? code : "en"
        language = normalized
        Bundle.setLanguage(normalized)
    }

    /// The Locale to feed `\.locale` so SwiftUI formats numbers/dates in the same language.
    var locale: Locale { Locale(identifier: language) }
}

// MARK: - Bundle language override

private var kBundleLanguageKey: UInt8 = 0

/// A bundle that resolves localized strings from a specific `.lproj`, regardless of the system
/// language. Swapped onto `Bundle.main` the first time `setLanguage` runs (object_setClass).
private final class LanguageBundle: Bundle, @unchecked Sendable {
    override func localizedString(forKey key: String, value: String?, table tableName: String?) -> String {
        if let path = objc_getAssociatedObject(self, &kBundleLanguageKey) as? String,
           let lproj = Bundle(path: path) {
            return lproj.localizedString(forKey: key, value: value, table: tableName)
        }
        return super.localizedString(forKey: key, value: value, table: tableName)
    }
}

extension Bundle {
    private static var didSwizzle = false

    /// Repoints `Bundle.main` at the given language's `.lproj`. Safe to call repeatedly.
    static func setLanguage(_ code: String) {
        if !didSwizzle {
            object_setClass(Bundle.main, LanguageBundle.self)
            didSwizzle = true
        }
        let path = Bundle.main.path(forResource: code, ofType: "lproj")
        objc_setAssociatedObject(Bundle.main, &kBundleLanguageKey, path,
                                 .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }
}
