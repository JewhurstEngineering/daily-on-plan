import AppKit
import SwiftUI
import SwiftData
import OnPlanCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let store = OnPlanStore()
    private var container: ModelContainer?

    var modelContainer: ModelContainer {
        if let container { return container }
        let made = DataStore.makeContainer()
        self.container = made
        return made
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        store.onSnapshotWritten = { WidgetReload.afterWritingSnapshot() }
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            MacDaySync.refresh(store: self.store, context: ModelContext(self.modelContainer))
            MacDaySync.startObserving(store: self.store)
            // Hide Dock after SwiftUI has registered the MenuBarExtra. Putting
            // LSUIElement in Info.plist (or flipping accessory too early) lets
            // macOS 26 Control Center drop the extra entirely.
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
}

/// SwiftUI scene so Control Center actually installs the extra. AppKit
/// `NSStatusItem` in a Settings-only `App` is silently dropped on macOS 26.
private struct OnPlanMenuBarScene: Scene {
    @ObservedObject var store: OnPlanStore

    var body: some Scene {
        MenuBarExtra {
            MenuBarPopoverView()
                .environmentObject(store)
        } label: {
            MenuBarLabelView()
                .environmentObject(store)
        }
        .menuBarExtraStyle(.window)
    }
}

@main
struct DailyOnPlanApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        OnPlanMenuBarScene(store: appDelegate.store)

        Settings {
            SettingsRootView()
                .environmentObject(appDelegate.store)
                .onAppear {
                    AppActivation.scheduleSettingsFocus()
                }
        }
        .defaultSize(width: 960, height: 680)
        .windowResizability(.contentMinSize)
    }
}
