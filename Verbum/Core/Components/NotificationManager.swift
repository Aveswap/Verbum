import UserNotifications

enum NotificationManager {
    /// Holds the word id from a notification tap when the app is cold-launched — observers
    /// (WordFeedView) aren't subscribed yet at the moment `didReceive` fires. The feed
    /// drains this on its first `.onAppear` so the deep-link still resolves.
    @MainActor static var pendingDeepLinkWordId: UUID?

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

    /// Requests permission and schedules. `onAuthorization(granted)` runs on the main actor so the
    /// caller can keep `profile.notificationsEnabled` honest when the user taps "Don't Allow".
    static func requestAndSchedule(count: Int, startHour: Int = 9, endHour: Int = 22,
                                   seenIds: Set<UUID> = [], calendar: Calendar = .current,
                                   onAuthorization: (@MainActor @Sendable (Bool) -> Void)? = nil) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
            Task { @MainActor in
                if granted {
                    reschedule(count: count, startHour: startHour, endHour: endHour, seenIds: seenIds, calendar: calendar)
                }
                onAuthorization?(granted)
            }
        }
    }

    @MainActor
    static func reschedule(count: Int, startHour: Int = 9, endHour: Int = 22,
                           seenIds: Set<UUID> = [], calendar: Calendar = .current) {
        // The SAME "words of the day" the widget shows (DailyWords.forToday) — so the daily
        // notifications and the lock-/home-screen widget surface one shared set per day. These are
        // free-pool/unseen-first words, so a free user can immediately tap-open anything mentioned.
        let sampledWords = DailyWords.forToday(count: count, seenIds: seenIds, calendar: calendar)

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
                    // Layout (matches the long-press expanded card the user asked for):
                    //   • App name "Verbum" — comes from CFBundleDisplayName, set by iOS.
                    //   • title  → the word itself (big bold headline)
                    //   • body   → "(pos.) definition" on the first line, then a blank line, then
                    //              "(example sentence)" so the two paragraphs read as separate
                    //              blocks in both the banner and the long-press preview.
                    content.title = word.text
                    let pos = posAbbreviation(word.partOfSpeech)
                    let meaning = pos.isEmpty ? word.definition : "(\(pos)) \(word.definition)"
                    if let example = word.exampleSentence, !example.isEmpty {
                        content.body = "\(meaning)\n\n(\(example))"
                    } else {
                        content.body = meaning
                    }
                    // Stash the word id so a tap can deep-link to *this exact word*.
                    // Read in VerbumAppDelegate.userNotificationCenter(_:didReceive:).
                    content.userInfo = ["wordId": word.id.uuidString]
                } else {
                    content.title = "Verbum"
                    content.body = messages[i % messages.count]
                }
                content.sound = .default
                content.badge = 1
                var comps = DateComponents()
                let hour = min(startHour + i * step, endHour)
                comps.hour = hour
                // Offset the minute by index so notifications that clamp to the same hour
                // (count > available hours) don't all fire at the exact same :00 instant — but
                // at the end hour keep it on :00 so the offset can't push it past endHour.
                comps.minute = hour == endHour ? 0 : (i * 17) % 60
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
