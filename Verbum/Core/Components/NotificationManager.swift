import UserNotifications

enum NotificationManager {
    // Localized at fire time via the swizzled main bundle (matches the UI/word language).
    private static var messages: [String] {
        [
            NSLocalizedString("Your word of the day is ready! 📖", comment: "notification"),
            NSLocalizedString("Time to expand your vocabulary! ✨", comment: "notification"),
            NSLocalizedString("A new word is waiting for you 🎯", comment: "notification"),
            NSLocalizedString("Keep your streak alive! 🔥", comment: "notification"),
            NSLocalizedString("1 minute a day keeps ignorance away 💡", comment: "notification"),
        ]
    }

    static func requestAndSchedule(count: Int, startHour: Int = 9, endHour: Int = 22, seenIds: Set<UUID> = []) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
            guard granted else { return }
            Task { @MainActor in
                reschedule(count: count, startHour: startHour, endHour: endHour, seenIds: seenIds)
            }
        }
    }

    @MainActor
    static func reschedule(count: Int, startHour: Int = 9, endHour: Int = 22, seenIds: Set<UUID> = []) {
        // Sample real words from the user's own free pool so notifications never leak paywalled
        // words (and a free user can immediately tap-open anything the notification mentions).
        // Prefer words the user hasn't seen yet, so each notification surfaces a genuinely NEW
        // word; fall back to the whole pool once everything's been seen.
        let pool = WordAccess.freePool()
        let unseen = pool.filter { !seenIds.contains($0.id) }
        let source = unseen.isEmpty ? pool : unseen
        let sampledWords = Array(source.shuffled().prefix(count))

        UNUserNotificationCenter.current().getNotificationSettings { settings in
            guard settings.authorizationStatus == .authorized else { return }
            // Remove ONLY the daily word slots (verbum_0…23), never the separately-scheduled
            // "verbum_streak_risk" reminder — wiping all pending requests here used to silently
            // cancel a streak-save notification whenever the user touched notification settings.
            let dailyIds = (0..<24).map { "verbum_\($0)" }
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: dailyIds)
            let span = max(endHour - startHour, 1)
            let step = max(span / max(count, 1), 1)
            for i in 0..<count {
                let content = UNMutableNotificationContent()
                if let word = sampledWords[safe: i] {
                    // The word itself is the bold headline; the body leads with the part-of-speech
                    // abbreviation then the definition — e.g. "ammil" / "(n.) The thin film of ice…".
                    content.title = word.text
                    let pos = posAbbreviation(word.partOfSpeech)
                    content.body = pos.isEmpty ? word.definition : "(\(pos)) \(word.definition)"
                } else {
                    content.title = "Verbum"
                    content.body = messages[i % messages.count]
                }
                content.sound = .default
                content.badge = 1
                var comps = DateComponents()
                comps.hour = min(startHour + i * step, endHour)
                // Offset the minute by index so notifications that clamp to the same hour
                // (count > available hours) don't all fire at the exact same :00 instant.
                comps.minute = (i * 17) % 60
                let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
                UNUserNotificationCenter.current().add(
                    UNNotificationRequest(identifier: "verbum_\(i)", content: content, trigger: trigger)
                )
            }
        }
    }

    static func cancelAll() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }

    /// Clears the app icon badge. Each scheduled word sets badge = 1; without this it never
    /// resets. Call on launch.
    static func clearBadge() {
        UNUserNotificationCenter.current().setBadgeCount(0)
    }

    /// Schedules a once-off streak-at-risk notification at 20:00 today if the user
    /// hasn't opened the app today. Call this before recordDailyOpen() so lastOpened
    /// still reflects the previous session.
    static func scheduleStreakReminder(currentStreak: Int, lastOpened: Date?) {
        guard currentStreak > 1 else {
            UNUserNotificationCenter.current()
                .removePendingNotificationRequests(withIdentifiers: ["verbum_streak_risk"])
            return
        }
        let openedToday = lastOpened.map { Calendar.current.isDateInToday($0) } ?? false
        if openedToday {
            UNUserNotificationCenter.current()
                .removePendingNotificationRequests(withIdentifiers: ["verbum_streak_risk"])
            return
        }
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            guard settings.authorizationStatus == .authorized else { return }
            UNUserNotificationCenter.current()
                .removePendingNotificationRequests(withIdentifiers: ["verbum_streak_risk"])
            let content = UNMutableNotificationContent()
            content.title = "Verbum"
            content.body  = String(format: NSLocalizedString("Your %lld-day streak is at risk! 🔥 Open Verbum for 30 seconds.", comment: "streak reminder"), currentStreak)
            content.sound = .default
            var comps = DateComponents()
            comps.hour   = 20
            comps.minute = 0
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
            UNUserNotificationCenter.current().add(
                UNNotificationRequest(identifier: "verbum_streak_risk", content: content, trigger: trigger)
            )
        }
    }

    static func hoursFrom(_ timeString: String) -> Int {
        Int(timeString.prefix(2)) ?? 9
    }

    /// Short part-of-speech tag for the notification body (English for now), e.g. noun → "n.".
    private static func posAbbreviation(_ pos: String) -> String {
        switch pos.lowercased() {
        case "noun":      return "n."
        case "verb":      return "v."
        case "adjective": return "adj."
        case "adverb":    return "adv."
        default:          return ""
        }
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
