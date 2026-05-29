import os

/// Shared os.Logger categories. Prefer these over print() / silently-swallowed `try?`
/// so failures are visible in Console.app and sysdiagnose logs.
extension Logger {
    private static let subsystem = "com.verbum.app"

    static let database      = Logger(subsystem: subsystem, category: "Database")
    static let subscriptions = Logger(subsystem: subsystem, category: "Subscriptions")
    static let speech        = Logger(subsystem: subsystem, category: "Speech")
    static let spotlight     = Logger(subsystem: subsystem, category: "Spotlight")
}
