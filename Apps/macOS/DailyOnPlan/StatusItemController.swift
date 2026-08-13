import AppKit
import SwiftUI
import Combine
import OnPlanCore

/// AppKit status item — SwiftUI `MenuBarExtra` labels get clipped/`…` truncated.
@MainActor
final class StatusItemController: NSObject {
    private var item: NSStatusItem?
    private var popover: NSPopover?
    private var hosting: NSHostingController<AnyView>?
    private var store: OnPlanStore?
    private var cancellables = Set<AnyCancellable>()
    private var eventMonitor: Any?

    private var popoverWidth: CGFloat {
        store?.preferences.interfaceSize.popoverWidth ?? 360
    }

    func start(store: OnPlanStore) {
        self.store = store
        makeItem(store: store)

        store.$preferences
            .receive(on: DispatchQueue.main)
            .sink { [weak self] prefs in
                self?.refreshTitle()
                self?.applyPopoverAppearance(prefs)
                self?.syncPopoverSize()
            }
            .store(in: &cancellables)

        store.$snapshot
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.refreshTitle()
                self?.syncShownPopover()
            }
            .store(in: &cancellables)

        SystemAppearanceMonitor.shared.$isDark
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self, let prefs = self.store?.preferences else { return }
                self.applyPopoverAppearance(prefs)
            }
            .store(in: &cancellables)

        refreshTitle()
    }

    private func makeItem(store: OnPlanStore) {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            button.imagePosition = .imageLeft
            button.imageScaling = .scaleProportionallyDown
            button.target = self
            button.action = #selector(togglePopover(_:))
            button.sendAction(on: [.leftMouseUp])
        }

        let hosting = NSHostingController(
            rootView: AnyView(
                MenuBarPopoverView()
                    .environmentObject(store)
            )
        )
        hosting.sizingOptions = [.intrinsicContentSize]
        hosting.view.wantsLayer = true

        let pop = NSPopover()
        pop.behavior = .transient
        pop.animates = false
        pop.contentViewController = hosting

        self.item = item
        self.popover = pop
        self.hosting = hosting
        applyPopoverAppearance(store.preferences)
        syncPopoverSize()
    }

    private func syncPopoverSize() {
        guard let hosting else { return }
        let width = popoverWidth
        hosting.view.layoutSubtreeIfNeeded()
        let fitted = hosting.sizeThatFits(
            in: CGSize(width: width, height: CGFloat.greatestFiniteMagnitude)
        )
        let screenCap = (NSScreen.main?.visibleFrame.height ?? 900) * 0.88
        let height = min(max(fitted.height.rounded(.up) + 12, 160), screenCap)
        let size = NSSize(width: width, height: height)
        hosting.preferredContentSize = size
        popover?.contentSize = size
    }

    private func syncShownPopover() {
        guard popover?.isShown == true else { return }
        syncPopoverSize()
    }

    private func applyPopoverAppearance(_ prefs: DisplayPreferences) {
        guard let popover else { return }
        let appearance = prefs.appearanceMode.nsAppearance ?? NSApp.effectiveAppearance
        popover.appearance = appearance
        if let view = popover.contentViewController?.view {
            view.appearance = appearance
            appearance.performAsCurrentDrawingAppearance {
                view.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
            }
        }
    }

    func refreshTitle() {
        guard let store, let button = item?.button else { return }
        button.image = Self.menuBarLogo()
        button.imagePosition = .imageLeft
        let text = MenuBarFormatter.title(snapshot: store.snapshot, preferences: store.preferences)
        let font = NSFont.menuBarFont(ofSize: 0)
        if store.preferences.showInMenuBar {
            button.attributedTitle = NSAttributedString(string: " \(text)", attributes: [
                .font: font,
                .foregroundColor: NSColor.labelColor,
                .baselineOffset: -0.5,
            ])
        } else {
            button.attributedTitle = NSAttributedString()
        }
        button.toolTip = text
    }

    func closePopover() {
        popover?.performClose(nil)
        removeEventMonitor()
    }

    @objc private func togglePopover(_ sender: Any?) {
        guard let store, let popover, let button = item?.button else { return }
        if popover.isShown {
            closePopover()
            return
        }
        AppActivation.bringToFront()
        applyPopoverAppearance(store.preferences)
        syncPopoverSize()
        var rect = button.bounds
        rect.origin.y -= 6
        popover.show(relativeTo: rect, of: button, preferredEdge: .minY)
        Self.hardenPopoverBackground(popover)
        syncPopoverSize()
        DispatchQueue.main.async { [weak self] in self?.syncPopoverSize() }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { [weak self] in
            self?.syncPopoverSize()
        }
        addEventMonitor()
    }

    /// NSPopover wraps content in a vibrant effect view; force an opaque material so dark apps don't show through.
    private static func hardenPopoverBackground(_ popover: NSPopover) {
        guard let root = popover.contentViewController?.view else { return }
        let appearance = popover.appearance ?? NSApp.effectiveAppearance
        root.wantsLayer = true
        appearance.performAsCurrentDrawingAppearance {
            root.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        }
        func walk(_ view: NSView) {
            view.appearance = appearance
            if let effect = view as? NSVisualEffectView {
                effect.material = .contentBackground
                effect.blendingMode = .withinWindow
                effect.state = .active
                effect.isEmphasized = true
            }
            view.subviews.forEach(walk)
        }
        walk(root)
    }

    private func addEventMonitor() {
        removeEventMonitor()
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.closePopover()
        }
    }

    private func removeEventMonitor() {
        if let eventMonitor {
            NSEvent.removeMonitor(eventMonitor)
            self.eventMonitor = nil
        }
    }

    private static func menuBarLogo() -> NSImage? {
        if let base = NSImage(named: "AppLogoTemplate") {
            let point = NSSize(width: 18, height: 18)
            let image = NSImage(size: point, flipped: false) { rect in
                NSGraphicsContext.current?.imageInterpolation = .high
                base.draw(in: rect)
                return true
            }
            image.isTemplate = true
            return image
        }
        let image = NSImage(systemSymbolName: "checkmark.seal.fill", accessibilityDescription: "Daily On Plan")
        image?.isTemplate = true
        return image
    }
}
