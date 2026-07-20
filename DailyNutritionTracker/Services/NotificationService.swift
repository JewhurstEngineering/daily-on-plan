import Foundation
import UserNotifications

@MainActor
final class NotificationService {
    static let shared = NotificationService()

    func requestPermission() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    func reschedule(using settings: AppSettings) async {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()

        _ = await requestPermission()

        if settings.waterReminderEnabled {
            let content = UNMutableNotificationContent()
            content.title = "Hydration check"
            content.body = "Time for a glass of water."
            content.sound = .default

            var comps = DateComponents()
            comps.hour = 9
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
            let request = UNNotificationRequest(
                identifier: "water-morning",
                content: content,
                trigger: trigger
            )
            try? await center.add(request)

            // Additional interval-style reminders at fixed daytime hours
            let hours = stride(from: 9 + settings.waterReminderIntervalHours, through: 18, by: settings.waterReminderIntervalHours)
            for hour in hours {
                var c = DateComponents()
                c.hour = hour
                let t = UNCalendarNotificationTrigger(dateMatching: c, repeats: true)
                let r = UNNotificationRequest(
                    identifier: "water-\(hour)",
                    content: content,
                    trigger: t
                )
                try? await center.add(r)
            }
        }

        if settings.eveningCheckInEnabled {
            let content = UNMutableNotificationContent()
            content.title = "Evening check-in"
            content.body = "Log today’s protein, feelings, and plan compliance."
            content.sound = .default

            var comps = DateComponents()
            comps.hour = settings.eveningCheckInHour
            comps.minute = settings.eveningCheckInMinute
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
            let request = UNNotificationRequest(
                identifier: "evening-checkin",
                content: content,
                trigger: trigger
            )
            try? await center.add(request)
        }
    }
}
