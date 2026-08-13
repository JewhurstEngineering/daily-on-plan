import AppKit
import SwiftUI
import SwiftData
import OnPlanCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let store = OnPlanStore()
    let container = DataStore.makeContainer()
    private let statusItem = StatusItemController()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        store.onSnapshotWritten = { WidgetReload.afterWritingSnapshot() }
        MacDaySync.refresh(store: store, context: ModelContext(container))
        AppInstall.registerEmbeddedWidget()
        statusItem.start(store: store)
    }

    nonisolated func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            Task { @MainActor in
                AppActivation.openSettingsViaLinkFallback()
            }
        }
        return true
    }
}

@main
struct DailyOnPlanApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // Menu bar UI is hosted by StatusItemController (AppKit) so the label
        // is not clipped the way SwiftUI MenuBarExtra truncates with "…".
        Settings {
            SettingsRootView()
                .environmentObject(appDelegate.store)
                .modelContainer(appDelegate.container)
                .onAppear {
                    AppActivation.scheduleSettingsFocus()
                }
        }
        .defaultSize(width: 960, height: 680)
        .windowResizability(.contentMinSize)
    }
}
