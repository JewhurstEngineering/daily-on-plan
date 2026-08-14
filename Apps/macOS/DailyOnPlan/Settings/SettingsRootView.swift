import SwiftUI
import OnPlanCore

enum MacSettingsPane: String, Hashable, Identifiable, CaseIterable {
    case general, layout, theme, accessibility
    case program, body, lifestyle, fasting, journal, notifications
    case data, about

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: return "General"
        case .layout: return "Layout"
        case .theme: return "Theme"
        case .accessibility: return "Accessibility"
        case .program: return "Program"
        case .body: return "Body"
        case .lifestyle: return "Lifestyle"
        case .fasting: return "Fasting"
        case .journal: return "Journal"
        case .notifications: return "Notifications"
        case .data: return "Data"
        case .about: return "About"
        }
    }

    var systemImage: String {
        switch self {
        case .general: return "gearshape"
        case .layout: return "rectangle.split.2x1"
        case .theme: return "paintpalette"
        case .accessibility: return "accessibility"
        case .program: return "flag.checkered"
        case .body: return "figure.stand"
        case .lifestyle: return "drop.fill"
        case .fasting: return "clock"
        case .journal: return "square.grid.2x2"
        case .notifications: return "bell"
        case .data: return "externaldrive"
        case .about: return "info.circle"
        }
    }
}

struct SettingsRootView: View {
    @EnvironmentObject private var store: OnPlanStore

    var body: some View {
        TabView {
            tab(GeneralSettingsView(), .general)
            tab(LayoutSettingsView(), .layout)
            tab(ThemeSettingsView(), .theme)
            tab(AccessibilitySettingsView(), .accessibility)
            tab(MacProgramSettingsView(), .program)
            tab(MacBodySettingsView(), .body)
            tab(MacLifestyleSettingsView(), .lifestyle)
            tab(MacFastingSettingsView(), .fasting)
            tab(MacJournalSettingsView(), .journal)
            tab(MacNotificationsSettingsView(), .notifications)
            tab(DataSettingsView(), .data)
            tab(AboutSettingsView(), .about)
        }
        .frame(
            minWidth: 920,
            idealWidth: 1040 * store.preferences.interfaceSize.scale,
            maxWidth: .infinity,
            minHeight: 560,
            idealHeight: 680 * store.preferences.interfaceSize.scale,
            maxHeight: .infinity,
            alignment: .topLeading
        )
        .background(SettingsResizeUnlock())
        .environmentObject(store)
        .appThemed(store.preferences)
        .onAppear {
            AppActivation.scheduleSettingsFocus()
            WindowAppearanceApplier.apply(store.preferences.appearanceMode.nsAppearance)
            WindowAppearanceApplier.configureChrome(scale: store.preferences.interfaceSize.scale)
        }
        .onChange(of: store.preferences.appearanceMode) { _, mode in
            WindowAppearanceApplier.apply(mode.nsAppearance)
        }
        .onChange(of: store.preferences.interfaceSize) { _, size in
            WindowAppearanceApplier.configureChrome(scale: size.scale)
        }
    }

    private func tab<Content: View>(_ content: Content, _ pane: MacSettingsPane) -> some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .appLayoutScale(store.preferences.interfaceSize.scale)
            .tabItem { Label(pane.title, systemImage: pane.systemImage) }
            .tag(pane)
    }
}

struct DataSettingsView: View {
    @EnvironmentObject private var store: OnPlanStore
    @State private var statusTick = 0
    @State private var isChecking = false
    @State private var showBackup = false

    var body: some View {
        MacSettingsScroll {
            SettingsPanel(
                title: "iCloud journal",
                systemImage: "icloud",
                subtitle: "Same day log as iPhone."
            ) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Circle()
                        .fill(SharedModelContainer.usesCloudKit ? Color.green : Color.orange)
                        .frame(width: 8, height: 8)
                    Text(iCloudLine)
                        .appFont(.subheadline, weight: .semibold)
                        .id(statusTick)
                    Spacer(minLength: 8)
                    Button {
                        isChecking = true
                        defer { isChecking = false }
                        _ = try? SharedModelContainer.reopen()
                        MacDaySync.refresh(store: store)
                        statusTick += 1
                    } label: {
                        if isChecking {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Text("Check now")
                        }
                    }
                    .controlSize(.small)
                    .disabled(isChecking)
                }

                Text("Protein, water, plan flags, body metrics, and the rest of the journal sync with iPhone over iCloud when this Mac is signed into the same Apple ID. Theme and menu bar layout stay on this Mac.")
                    .appFont(.body)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            SettingsPanel(
                title: "Backup & restore",
                systemImage: "externaldrive.badge.timemachine",
                subtitle: "Full journal snapshot. Same format as iPhone."
            ) {
                Button {
                    showBackup = true
                } label: {
                    Label("Open backup & restore", systemImage: "arrow.up.arrow.down")
                }
                Text("Backups include days, weights, body composition, measurements, meals, and settings. Restore replaces everything currently in the journal.")
                    .appFont(.body)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .sheet(isPresented: $showBackup) {
            NavigationStack {
                BackupRestoreView()
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Done") { showBackup = false }
                        }
                    }
            }
            .frame(minWidth: 540, minHeight: 440)
        }
    }

    private var iCloudLine: String {
        if SharedModelContainer.usesCloudKit {
            return "iCloud on"
        }
        if let error = SharedModelContainer.cloudKitError {
            return "iCloud off — \(error)"
        }
        return "iCloud off"
    }
}
