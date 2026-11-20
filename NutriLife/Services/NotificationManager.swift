import UserNotifications

enum NotificationManager {
    /// Rappel quotidien (18h) pour consulter le planning. Retourne false si la permission est refusée.
    static func setDailyReminder(_ on: Bool) async -> Bool {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ["nutrilife.daily"])
        guard on else { return true }
        guard (try? await center.requestAuthorization(options: [.alert, .sound])) == true else { return false }
        let content = UNMutableNotificationContent()
        content.title = "NutriLife"
        content.body = L("notif.body")
        var comps = DateComponents(); comps.hour = 18
        let request = UNNotificationRequest(identifier: "nutrilife.daily", content: content,
                                            trigger: UNCalendarNotificationTrigger(dateMatching: comps, repeats: true))
        try? await center.add(request)
        return true
    }
}
