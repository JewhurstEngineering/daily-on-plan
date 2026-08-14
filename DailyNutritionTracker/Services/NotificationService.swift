import Foundation
import UserNotifications
import SwiftData
import OnPlanCore

enum NotificationKind: String {
    case water
    case meal
    case weigh
    case eveningPlan
    case ketosis
    case genericCheckIn
    case smokingCheckIn
    case drinkingCheckIn
    case motivation
    case bodyComposition
    case supplement

    var deepLinkSection: String {
        switch self {
        case .water: return "hydration"
        case .meal: return "protein"
        case .weigh: return "weight"
        case .smokingCheckIn: return "smoking"
        case .drinkingCheckIn: return "drinking"
        case .bodyComposition: return "bodyComposition"
        case .supplement: return "supplements"
        case .eveningPlan, .ketosis, .genericCheckIn, .motivation: return "header"
        }
    }
}

enum NotificationActionID {
    static let eveningYes = "evening.yes"
    static let eveningNo = "evening.no"
    static let ketosisYes = "ketosis.yes"
    static let ketosisNo = "ketosis.no"
    static let waterLogged = "water.logged"
    static let supplementTaken = "supplement.taken"
    static let categoryEvening = "CATEGORY_EVENING_PLAN"
    static let categoryKetosis = "CATEGORY_KETOSIS"
    static let categoryWater = "CATEGORY_WATER"
    static let categorySupplement = "CATEGORY_SUPPLEMENT"
}

extension Notification.Name {
    static let openDaySection = Notification.Name("openDaySection")
    static let onPlanNotificationHandled = Notification.Name("onPlanNotificationHandled")
    static let onPlanJournalDidChange = Notification.Name("onPlanJournalDidChange")
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

    func reschedule(using settings: AppSettings, requestIfNeeded: Bool = true) async {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()
        registerCategories()

        #if os(macOS)
        guard DisplayPreferenceStore.load().notifyOnThisMac else { return }
        #endif

        guard !settings.notificationsPaused else { return }

        let granted: Bool
        if requestIfNeeded {
            granted = await requestPermission()
        } else {
            let status = await authorizationStatus()
            granted = status == .authorized || status == .provisional
        }
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

        if settings.smokingCheckInEnabled, settings.smokingMode.showsSection {
            let body = MotivationQuoteStore.smokingBodies().randomElement()
                ?? "Open Smoking to log today’s count."
            scheduleDaily(
                id: "smoking-checkin",
                title: "Smoking check-in",
                body: body,
                hour: settings.smokingCheckInHour,
                minute: settings.smokingCheckInMinute,
                kind: .smokingCheckIn,
                center: center
            )
        }

        if settings.drinkingCheckInEnabled, settings.drinkingMode.showsSection {
            let body = MotivationQuoteStore.drinkingBodies().randomElement()
                ?? "Open Drinking to log today’s drinks."
            scheduleDaily(
                id: "drinking-checkin",
                title: "Drinking check-in",
                body: body,
                hour: settings.drinkingCheckInHour,
                minute: settings.drinkingCheckInMinute,
                kind: .drinkingCheckIn,
                center: center
            )
        }

        if settings.motivationReminderEnabled {
            let quote = MotivationQuoteStore.nextQuote(custom: settings.customMotivationQuotes)
            scheduleDaily(
                id: "motivation-daily",
                title: "Stay on plan",
                body: quote,
                hour: settings.motivationReminderHour,
                minute: settings.motivationReminderMinute,
                kind: .motivation,
                center: center
            )
        }

        if settings.bodyCompReminderEnabled {
            scheduleBodyComposition(settings: settings, center: center)
        }

        if settings.showSupplementsSection {
            scheduleSupplements(settings: settings, center: center)
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

        let taken = UNNotificationAction(
            identifier: NotificationActionID.supplementTaken,
            title: "Mark taken",
            options: []
        )
        let supplement = UNNotificationCategory(
            identifier: NotificationActionID.categorySupplement,
            actions: [taken],
            intentIdentifiers: [],
            options: []
        )

        UNUserNotificationCenter.current().setNotificationCategories([evening, ketosis, water, supplement])
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

    private func scheduleSupplements(settings: AppSettings, center: UNUserNotificationCenter) {
        for supplement in settings.supplements where supplement.isEnabled && supplement.reminderEnabled {
            for (index, time) in supplement.reminderTimes.enumerated() where index < supplement.dosesPerDay {
                let content = UNMutableNotificationContent()
                content.title = supplement.name
                content.body = "Dose \(index + 1) of \(supplement.dosesPerDay) — press and hold to Mark taken."
                content.sound = .default
                content.categoryIdentifier = NotificationActionID.categorySupplement
                content.userInfo = [
                    "kind": NotificationKind.supplement.rawValue,
                    "supplementId": supplement.id,
                    "doseIndex": index
                ]
                var comps = DateComponents()
                comps.hour = time.hour
                comps.minute = time.minute
                let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
                let request = UNNotificationRequest(
                    identifier: "supplement-\(supplement.id)-dose-\(index)",
                    content: content,
                    trigger: trigger
                )
                center.add(request)
            }
        }
    }

    private func scheduleBodyComposition(settings: AppSettings, center: UNUserNotificationCenter) {
        let content = UNMutableNotificationContent()
        content.title = "Body composition"
        content.body = "Log your clinic receipt in \(AppIdentity.displayName) when you’re ready."
        content.sound = .default
        content.userInfo = ["kind": NotificationKind.bodyComposition.rawValue]

        let hour = settings.bodyCompReminderHour
        let minute = settings.bodyCompReminderMinute

        switch settings.bodyCompReminderCadence {
        case .weekly:
            var comps = DateComponents()
            comps.weekday = settings.bodyCompReminderWeekday
            comps.hour = hour
            comps.minute = minute
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
            let request = UNNotificationRequest(
                identifier: "body-comp-weekly",
                content: content,
                trigger: trigger
            )
            center.add(request)

        case .monthly:
            let calendar = Calendar.current
            let preferredDay = settings.bodyCompReminderDayOfMonth
            guard let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: Date())) else {
                return
            }
            for offset in 0..<12 {
                guard let month = calendar.date(byAdding: .month, value: offset, to: monthStart) else { continue }
                let daysInMonth = calendar.range(of: .day, in: .month, for: month)?.count ?? 30
                let day = min(preferredDay, daysInMonth)
                var comps = calendar.dateComponents([.year, .month], from: month)
                comps.day = day
                comps.hour = hour
                comps.minute = minute
                guard let fireDate = calendar.date(from: comps), fireDate > Date() else { continue }
                let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
                let request = UNNotificationRequest(
                    identifier: "body-comp-monthly-\(offset)",
                    content: content,
                    trigger: trigger
                )
                center.add(request)
            }
        }
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
        case NotificationActionID.supplementTaken:
            let supplementId = info["supplementId"] as? String
            let doseIndex: Int? = {
                if let value = info["doseIndex"] as? Int { return value }
                if let number = info["doseIndex"] as? NSNumber { return number.intValue }
                return nil
            }()
            markSupplementTaken(supplementId: supplementId, doseIndex: doseIndex)
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

        NotificationCenter.default.post(name: .onPlanNotificationHandled, object: nil)
    }

    private func setFollowedPlan(_ followed: Bool) {
        guard let container else { return }
        let context = ModelContext(container)
        let settings = DataStore.settings(in: context)
        settings.migrateNotificationDefaultsIfNeeded()
        let log = DataStore.log(for: Date(), in: context, defaultGoal: settings.defaultProteinGoal)
        log.followedPlan = followed
        try? context.save()
        WidgetReloader.reloadAll()
    }

    private func setKetosis(_ inKetosis: Bool) {
        guard let container else { return }
        let context = ModelContext(container)
        let settings = DataStore.settings(in: context)
        let log = DataStore.log(for: Date(), in: context, defaultGoal: settings.defaultProteinGoal)
        log.ketosis = inKetosis
        try? context.save()
        WidgetReloader.reloadAll()
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
        WidgetReloader.reloadAll()
    }

    private func markSupplementTaken(supplementId: String?, doseIndex: Int?) {
        guard let container, let supplementId, let doseIndex, doseIndex >= 0 else { return }
        let context = ModelContext(container)
        let settings = DataStore.settings(in: context)
        guard let supplement = settings.supplements.first(where: { $0.id == supplementId }),
              doseIndex < supplement.dosesPerDay else { return }
        let log = DataStore.log(for: Date(), in: context, defaultGoal: settings.defaultProteinGoal)
        let key = supplement.doseKey(doseIndex)
        if !log.completedSupplements.contains(key) {
            log.completedSupplements.append(key)
            try? context.save()
            WidgetReloader.reloadAll()
        }
    }
}
