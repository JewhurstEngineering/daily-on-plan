import AppKit
import SwiftUI
import OnPlanCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let store = OnPlanStore()
    let statusItem = StatusItemController()

    func applicationDidFinishLaunching(_ notification: Notification) {
        store.onSnapshotWritten = { WidgetReload.afterWritingSnapshot() }
        // Create the extra before accessory policy. LSUIElement / flipping
        // accessory too early used to let Control Center drop AppKit extras.
        statusItem.start(store: store)
        MacNotifications.configure()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(openFromNotification(_:)),
            name: .openDaySection,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(refreshAfterNotification),
            name: .onPlanNotificationHandled,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(refreshAfterNotification),
            name: .onPlanJournalDidChange,
            object: nil
        )
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            MacDaySync.refresh(store: self.store)
            MacDaySync.startObserving(store: self.store)
            NSApp.setActivationPolicy(.accessory)
        }
        DispatchQueue.global(qos: .utility).async {
            AppInstall.registerEmbeddedWidget()
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    nonisolated func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            Task { @MainActor in
                AppActivation.openSettingsViaLinkFallback()
            }
        }
        return true
    }

    @objc private func openFromNotification(_ note: Notification) {
        MacDaySync.refresh(store: store)
        statusItem.presentPopover()
    }

    @objc private func refreshAfterNotification() {
        MacDaySync.refresh(store: store)
    }
}

@main
struct DailyOnPlanApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            SettingsRootView()
                .environmentObject(appDelegate.store)
                .modifier(MacJournalContainer())
                .onAppear {
                    AppActivation.scheduleSettingsFocus()
                }
        }
        .defaultSize(width: 960, height: 680)
        .windowResizability(.contentMinSize)
    }
}

private struct MacJournalContainer: ViewModifier {
    func body(content: Content) -> some View {
        if let container = try? SharedModelContainer.shared() {
            content.modelContainer(container)
        } else {
            content
        }
    }
}
