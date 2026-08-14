import AppKit
import SwiftData
import UserNotifications
import OnPlanCore

enum MacNotifications {
    @MainActor
    static func configure() {
        guard let container = try? SharedModelContainer.shared() else { return }
        NotificationService.shared.configure(container: container)
        sync(requestIfNeeded: false)
    }

    @MainActor
    static func sync(requestIfNeeded: Bool) {
        Task {
            await syncNow(requestIfNeeded: requestIfNeeded)
        }
    }

    @MainActor
    static func syncNow(requestIfNeeded: Bool) async {
        guard DisplayPreferenceStore.load().notifyOnThisMac else {
            UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
            return
        }
        guard let container = try? SharedModelContainer.shared() else { return }
        let context = ModelContext(container)
        guard let settings = DataStore.existingSettings(in: context) else {
            UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
            return
        }
        await NotificationService.shared.reschedule(using: settings, requestIfNeeded: requestIfNeeded)
    }

    static func openSystemSettings() {
        let candidates = [
            "x-apple.systempreferences:com.apple.Notifications-Settings.extension?id=com.dailyonplan.macos",
            "x-apple.systempreferences:com.apple.Notifications-Settings.extension",
            "x-apple.systempreferences:com.apple.preference.notifications"
        ]
        for string in candidates {
            if let url = URL(string: string), NSWorkspace.shared.open(url) {
                return
            }
        }
    }
}
