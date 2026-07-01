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
                                   seenIds: Set<UUID> = [], personalWords: [Word] = [],
                                   calendar: Calendar = .current,
                                   onAuthorization: (@MainActor @Sendable (Bool) -> Void)? = nil) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
            Task { @MainActor in
                if granted {
                    reschedule(count: count, startHour: startHour, endHour: endHour,
                               seenIds: seenIds, personalWords: personalWords, calendar: calendar)
                }
                onAuthorization?(granted)
            }
        }
    }

    /// How many days ahead to pre-schedule. Rolling, not repeating — see the design note below.
    /// Apple caps an app at 64 pending local notifications; `numDays(for:)` shrinks this so
    /// `count * numDays` always leaves headroom for the streak-risk + trial reminders.
    private static func numDays(for count: Int) -> Int {
        max(1, min(7, 60 / max(count, 1)))
    }

    /// Schedules the next `numDays(for: count)` days of word notifications, each day with its own
    /// content, `repeats: false`.
    ///
    /// Why not one `repeats: true` trigger per slot (the old design): a repeating trigger bakes its
    /// `content` in ONCE and iOS re-fires that exact same text forever — so the "word of the day"
    /// notification silently froze on whatever word was current at the last reschedule() call, and
    /// since that only reruns at a true cold app launch (SwiftUI's root `.onAppear` does not refire
    /// on mere foregrounding), most users saw the identical word for days/weeks. Scheduling real,
    /// distinct, non-repeating notifications for each of the next several days — refreshed on every
    /// foreground (see VerbumApp) — fixes that: content actually differs day to day.
    ///
    /// Word selection per day:
    ///   - Personal (claimed) words: slide the `count`-wide window one word further each day
    ///     (`(day + slot) % pool.count`) so the SET shown differs daily, not just the time slot.
    ///   - Fallback (nothing claimed yet): `DailyWords.forToday(now:)` for that future calendar day
    ///     — it already varies deterministically by date.
    @MainActor
    static func reschedule(count: Int, startHour: Int = 9, endHour: Int = 22,
                           seenIds: Set<UUID> = [], personalWords: [Word] = [],
                           calendar: Calendar = .current) {
        let usingPersonal = !personalWords.isEmpty
        let days = numDays(for: count)

        UNUserNotificationCenter.current().getNotificationSettings { settings in
            guard settings.authorizationStatus == .authorized else { return }
            UNUserNotificationCenter.current().getPendingNotificationRequests { pending in
                // Clear every previously-scheduled daily-word slot — the old "verbum_0…23" scheme
                // AND this rolling "verbum_d{day}_{slot}" scheme — but never the separately-
                // scheduled "verbum_streak_risk" / "verbum_trial_reminder" reminders (wiping those
                // here used to silently cancel a streak-save notification on any settings touch).
                let staleIds = pending.map(\.identifier).filter {
                    $0.hasPrefix("verbum_") && $0 != "verbum_streak_risk" && $0 != "verbum_trial_reminder"
                }
                UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: staleIds)

                let span = max(endHour - startHour, 1)
                let step = max(span / max(count, 1), 1)
                let today = calendar.startOfDay(for: Date())

                for day in 0..<days {
                    guard let dayDate = calendar.date(byAdding: .day, value: day, to: today) else { continue }
                    let dayWords: [Word] = usingPersonal
                        ? (0..<count).map { personalWords[(day + $0) % personalWords.count] }
                        : DailyWords.forToday(count: count, seenIds: seenIds, calendar: calendar, now: dayDate)

                    for i in 0..<count {
                        let content = UNMutableNotificationContent()
                        let word: Word? = dayWords[safe: i]
                        if let word {
                            // Competitor-style layout: leave the title EMPTY so the system header
                            // shows the app display name ("Verbum"), then stack the word, its
                            // "(pos) definition", and the example sentence (in parens) as body lines.
                            content.title = ""
                            let pos = posAbbreviation(word.partOfSpeech)
                            var lines = [word.text]
                            lines.append(pos.isEmpty ? word.definition : "(\(pos)) \(word.definition)")
                            if let ex = word.exampleSentence?.trimmingCharacters(in: .whitespacesAndNewlines), !ex.isEmpty {
                                lines.append("(\(ex))")
                            }
                            content.body = lines.joined(separator: "\n")
                            // Stash the word id so a tap deep-links to *this exact word* — the SAME
                            // word this notification displayed, never a different one (read in
                            // VerbumAppDelegate.userNotificationCenter(_:didReceive:)).
                            content.userInfo = ["wordId": word.id.uuidString]
                        } else {
                            content.title = ""
                            content.body = messages[i % messages.count]
                        }
                        content.sound = .default
                        content.badge = 1

                        var comps = calendar.dateComponents([.year, .month, .day], from: dayDate)
                        let hour = min(startHour + i * step, endHour)
                        comps.hour = hour
                        // Offset the minute by index so notifications that clamp to the same hour
                        // (count > available hours) don't all fire at the exact same :00 instant —
                        // but at the end hour keep it on :00 so the offset can't push past endHour.
                        comps.minute = hour == endHour ? 0 : (i * 17) % 60
                        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
                        UNUserNotificationCenter.current().add(
                            UNNotificationRequest(identifier: "verbum_d\(day)_\(i)", content: content, trigger: trigger)
                        )
                    }
                }
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
    static func scheduleStreakReminder(currentStreak: Int, lastOpened: Date?,
                                       calendar: Calendar = .current) {
        guard currentStreak > 1 else {
            UNUserNotificationCenter.current()
                .removePendingNotificationRequests(withIdentifiers: ["verbum_streak_risk"])
            return
        }
        // Use the streak-locked calendar so "did I open today?" agrees with the streak machinery
        // (dayCalendar); Calendar.current would disagree by the TZ offset after travel/DST and
        // fire — or suppress — the 20:00 reminder on the wrong day.
        let openedToday = lastOpened.map { calendar.isDateInToday($0) } ?? false
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

    /// One-off local reminder that the 7-day free-games trial is ending (fires ~`daysFromNow`
    /// at the next opportunity). Local only — no server needed.
    static func scheduleTrialReminder(daysFromNow: Int) {
        let content = UNMutableNotificationContent()
        content.title = "Verbum"
        content.body = NSLocalizedString("Your 7-day free games trial is ending soon — go Premium to keep playing.", comment: "trial reminder")
        content.sound = .default
        let interval = max(60, Double(daysFromNow) * 86_400)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            guard settings.authorizationStatus == .authorized else { return }
            UNUserNotificationCenter.current()
                .removePendingNotificationRequests(withIdentifiers: ["verbum_trial_reminder"])
            UNUserNotificationCenter.current().add(
                UNNotificationRequest(identifier: "verbum_trial_reminder", content: content, trigger: trigger)
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
