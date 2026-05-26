import UserNotifications

enum NotificationManager {
    private static let messages = [
        "Your word of the day is ready! 📖",
        "Time to expand your vocabulary! ✨",
        "A new word is waiting for you 🎯",
        "Keep your streak alive! 🔥",
        "1 minute a day keeps ignorance away 💡"
    ]

    static func requestAndSchedule(count: Int, startHour: Int = 9, endHour: Int = 22) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
            guard granted else { return }
            reschedule(count: count, startHour: startHour, endHour: endHour)
        }
    }

    static func reschedule(count: Int, startHour: Int = 9, endHour: Int = 22) {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            guard settings.authorizationStatus == .authorized else { return }
            UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
            let span = max(endHour - startHour, 1)
            let step = max(span / max(count, 1), 1)
            for i in 0..<count {
                let content = UNMutableNotificationContent()
                content.title = "Verbum"
                content.body = messages[i % messages.count]
                content.sound = .default
                content.badge = 1
                var comps = DateComponents()
                comps.hour = min(startHour + i * step, endHour)
                comps.minute = 0
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
            content.body  = "Your \(currentStreak)-day streak is at risk! 🔥 Open Verbum for 30 seconds."
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
}
