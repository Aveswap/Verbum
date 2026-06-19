import Foundation
import os

/// Minimal analytics seam — decoupled from any SDK so instrumentation lands now and a real backend
/// can be dropped in later WITHOUT touching call sites or adding a dependency/account today.
///
/// The retention test (council verdict) needs exactly four signals:
///   • `app_open`    → D7 unprompted-return rate (the one metric that decides build vs. pivot)
///   • `word_claimed`→ is the ownership loop happening?
///   • `note_added`  → are people personalising (the deep-binding action)?
///   • `card_shared` → the acquisition/expression signal
///
/// To go live: add a package (e.g. TelemetryDeck or PostHog) and, at app launch, set
/// `Analytics.backend = MyBackend(appID: …)` implementing `AnalyticsBackend`. Nothing else changes.
enum AnalyticsEvent: String {
    case appOpen     = "app_open"
    case wordClaimed = "word_claimed"
    case noteAdded   = "note_added"
    case cardShared  = "card_shared"
}

protocol AnalyticsBackend: Sendable {
    func send(_ event: String, _ params: [String: String])
}

@MainActor
enum Analytics {
    /// Defaults to OSLog so events are visible in Console during dev with zero third-party code or
    /// account. Swap for a real backend at launch when ready to measure live.
    static var backend: AnalyticsBackend = OSLogAnalytics()

    static func log(_ event: AnalyticsEvent, _ params: [String: String] = [:]) {
        backend.send(event.rawValue, params)
    }
}

/// No-dependency default: prints to the unified log under category "Analytics".
struct OSLogAnalytics: AnalyticsBackend {
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.verbum.app",
                                category: "Analytics")
    func send(_ event: String, _ params: [String: String]) {
        if params.isEmpty {
            logger.info("\(event, privacy: .public)")
        } else {
            logger.info("\(event, privacy: .public) \(params.description, privacy: .public)")
        }
    }
}
