import Foundation
import UserNotifications
import SwiftData

enum NotificationKind: String {
    case water
    case meal
    case weigh
    case eveningPlan
    case ketosis
    case genericCheckIn

    var deepLinkSection: String {
        switch self {
        case .water: return "hydration"
        case .meal: return "protein"
        case .weigh: return "weight"
        case .eveningPlan, .ketosis, .genericCheckIn: return "header"
        }
    }
}

enum NotificationActionID {
    static let eveningYes = "evening.yes"
    static let eveningNo = "evening.no"
    static let ketosisYes = "ketosis.yes"
    static let ketosisNo = "ketosis.no"
    static let waterLogged = "water.logged"
    static let categoryEvening = "CATEGORY_EVENING_PLAN"
    static let categoryKetosis = "CATEGORY_KETOSIS"
    static let categoryWater = "CATEGORY_WATER"
}

extension Notification.Name {
    static let openDaySection = Notification.Name("openDaySection")
}

@MainActor
final class NotificationService: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationService()

    private var container: ModelContainer?

    func configure(container: ModelContainer) {
        self.container = container
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        registerCategories()
    }

    func requestPermission() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    func authorizationStatus() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    func reschedule(using settings: AppSettings) async {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()
        registerCategories()

        guard !settings.notificationsPaused else { return }

        let granted = await requestPermission()
        guard granted else { return }

        if settings.waterReminderEnabled {
            scheduleWater(settings: settings, center: center)
        }
        if settings.mealReminderEnabled {
            scheduleDaily(
                id: "meal-reminder",
                title: "Meal reminder",
                body: "Time to eat or log a meal in \(AppIdentity.displayName).",
                hour: settings.mealReminderHour,
                minute: settings.mealReminderMinute,
                kind: .meal,
                center: center
            )
        }
        if settings.weighReminderEnabled {
            scheduleDaily(
                id: "weigh-reminder",
                title: "Weigh-in",
                body: "Log today’s weight in \(AppIdentity.displayName) when you’re ready.",
                hour: settings.weighReminderHour,
                minute: settings.weighReminderMinute,
                kind: .weigh,
                center: center
            )
        }
        if settings.genericCheckInEnabled {
            scheduleDaily(
                id: "generic-checkin",
                title: "Daily check-in",
                body: "Finish logging protein, feelings, and the rest of today’s sheet in \(AppIdentity.displayName).",
                hour: settings.genericCheckInHour,
                minute: settings.genericCheckInMinute,
                kind: .genericCheckIn,
                center: center
            )
        }
        if settings.eveningCheckInEnabled {
            let content = UNMutableNotificationContent()
            content.title = "Did you follow the plan today?"
            content.body = "Press and hold, then tap Yes or No — or open \(AppIdentity.displayName)."
            content.sound = .default
            content.categoryIdentifier = NotificationActionID.categoryEvening
            content.userInfo = ["kind": NotificationKind.eveningPlan.rawValue]
            var comps = DateComponents()
            comps.hour = settings.eveningCheckInHour
            comps.minute = settings.eveningCheckInMinute
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
            let request = UNNotificationRequest(
                identifier: "evening-plan",
                content: content,
                trigger: trigger
            )
            try? await center.add(request)
        }

        if settings.ketosisCheckInEnabled {
            let content = UNMutableNotificationContent()
            content.title = "Are you in ketosis today?"
            content.body = "Press and hold for Yes or No. (Strips, blood meter, breath — or your best guess.)"
            content.sound = .default
            content.categoryIdentifier = NotificationActionID.categoryKetosis
            content.userInfo = ["kind": NotificationKind.ketosis.rawValue]
            var comps = DateComponents()
            comps.hour = settings.ketosisCheckInHour
            comps.minute = settings.ketosisCheckInMinute
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
            let request = UNNotificationRequest(
                identifier: "ketosis-checkin",
                content: content,
                trigger: trigger
            )
            try? await center.add(request)
        }
    }

    // MARK: - UNUserNotificationCenterDelegate

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .list])
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        Task { @MainActor in
            await handle(response: response)
            completionHandler()
        }
    }

    // MARK: - Private

    private func registerCategories() {
        let yes = UNNotificationAction(
            identifier: NotificationActionID.eveningYes,
            title: "Yes",
            options: []
        )
        let no = UNNotificationAction(
            identifier: NotificationActionID.eveningNo,
            title: "No",
            options: [.destructive]
        )
        // `.customDismissAction` is unused; keep category options empty.
        // Actions appear after press-and-hold / expand — iOS never shows them on the compact banner.
        let evening = UNNotificationCategory(
            identifier: NotificationActionID.categoryEvening,
            actions: [yes, no],
            intentIdentifiers: [],
            options: []
        )

        let ketosisYes = UNNotificationAction(
            identifier: NotificationActionID.ketosisYes,
            title: "Yes",
            options: []
        )
        let ketosisNo = UNNotificationAction(
            identifier: NotificationActionID.ketosisNo,
            title: "No",
            options: [.destructive]
        )
        let ketosis = UNNotificationCategory(
            identifier: NotificationActionID.categoryKetosis,
            actions: [ketosisYes, ketosisNo],
            intentIdentifiers: [],
            options: []
        )

        let logged = UNNotificationAction(
            identifier: NotificationActionID.waterLogged,
            title: "Logged a drink",
            options: []
        )
        let water = UNNotificationCategory(
            identifier: NotificationActionID.categoryWater,
            actions: [logged],
            intentIdentifiers: [],
            options: []
        )

        UNUserNotificationCenter.current().setNotificationCategories([evening, ketosis, water])
    }

    private func scheduleWater(settings: AppSettings, center: UNUserNotificationCenter) {
        let content = UNMutableNotificationContent()
        content.title = "Hydration check"
        content.body = "Time for a glass of water. Press and hold for “Logged a drink”."
        content.sound = .default
        content.categoryIdentifier = NotificationActionID.categoryWater
        content.userInfo = ["kind": NotificationKind.water.rawValue]

        let interval = max(settings.waterReminderIntervalHours, 2)
        let hours = stride(from: 9, through: 18, by: interval)
        for hour in hours {
            var c = DateComponents()
            c.hour = hour
            c.minute = 0
            let t = UNCalendarNotificationTrigger(dateMatching: c, repeats: true)
            let r = UNNotificationRequest(
                identifier: "water-\(hour)",
                content: content,
                trigger: t
            )
            center.add(r)
        }
    }

    private func scheduleDaily(
        id: String,
        title: String,
        body: String,
        hour: Int,
        minute: Int,
        kind: NotificationKind,
        center: UNUserNotificationCenter
    ) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.userInfo = ["kind": kind.rawValue]
        var comps = DateComponents()
        comps.hour = hour
        comps.minute = minute
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        center.add(request)
    }

    private func handle(response: UNNotificationResponse) async {
        let action = response.actionIdentifier
        let info = response.notification.request.content.userInfo
        let kindRaw = info["kind"] as? String
        let kind = kindRaw.flatMap(NotificationKind.init(rawValue:))

        switch action {
        case NotificationActionID.eveningYes:
            setFollowedPlan(true)
        case NotificationActionID.eveningNo:
            setFollowedPlan(false)
        case NotificationActionID.ketosisYes:
            setKetosis(true)
        case NotificationActionID.ketosisNo:
            setKetosis(false)
        case NotificationActionID.waterLogged:
            logWaterDrink()
        case UNNotificationDefaultActionIdentifier:
            if let kind {
                NotificationCenter.default.post(
                    name: .openDaySection,
                    object: nil,
                    userInfo: ["section": kind.deepLinkSection]
                )
            }
        default:
            break
        }
    }

    private func setFollowedPlan(_ followed: Bool) {
        guard let container else { return }
        let context = ModelContext(container)
        let settings = DataStore.settings(in: context)
        settings.migrateNotificationDefaultsIfNeeded()
        let log = DataStore.log(for: Date(), in: context, defaultGoal: settings.defaultProteinGoal)
        log.followedPlan = followed
        try? context.save()
    }

    private func setKetosis(_ inKetosis: Bool) {
        guard let container else { return }
        let context = ModelContext(container)
        let settings = DataStore.settings(in: context)
        let log = DataStore.log(for: Date(), in: context, defaultGoal: settings.defaultProteinGoal)
        log.ketosis = inKetosis
        try? context.save()
    }

    private func logWaterDrink() {
        guard let container else { return }
        let context = ModelContext(container)
        let settings = DataStore.settings(in: context)
        let log = DataStore.log(for: Date(), in: context, defaultGoal: settings.defaultProteinGoal)
        let bottle = max(settings.defaultBottleOz, 1)
        let minimumSlots = max(1, Int(ceil(Double(settings.hydrationTargetOz) / bottle)))
        log.fillNextWaterSlot(oz: bottle, ensuringMinimumSlots: minimumSlots)
        try? context.save()
    }
}
