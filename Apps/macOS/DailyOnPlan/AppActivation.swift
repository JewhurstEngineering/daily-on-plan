import AppKit

enum AppActivation {
    static func bringToFront() {
        NSApp.activate(ignoringOtherApps: true)
    }

    static func focusSettingsWindows() {
        bringToFront()
        let candidates = NSApp.windows.filter { window in
            guard window.isVisible || window.isMiniaturized else { return false }
            let isPanel = window.styleMask.contains(.nonactivatingPanel) || window.level == .statusBar
            return window.styleMask.contains(.titled) && !isPanel
        }
        for window in candidates {
            if window.isMiniaturized {
                window.deminiaturize(nil)
            }
            window.collectionBehavior.insert(.moveToActiveSpace)
            window.makeKeyAndOrderFront(nil)
            window.orderFrontRegardless()
            WindowAppearanceApplier.unlockResize(window)
        }
    }

    static func scheduleSettingsFocus() {
        bringToFront()
        DispatchQueue.main.async {
            focusSettingsWindows()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            focusSettingsWindows()
        }
    }

    static func openSettingsViaLinkFallback() {
        bringToFront()
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        scheduleSettingsFocus()
    }
}
