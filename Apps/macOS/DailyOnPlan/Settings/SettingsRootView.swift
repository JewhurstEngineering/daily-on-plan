import SwiftUI
import OnPlanCore

struct SettingsRootView: View {
    @EnvironmentObject private var store: OnPlanStore

    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem { Label("General", systemImage: "gearshape") }
            LayoutSettingsView()
                .tabItem { Label("Layout", systemImage: "rectangle.split.2x1") }
            ThemeSettingsView()
                .tabItem { Label("Theme", systemImage: "paintpalette") }
            AccessibilitySettingsView()
                .tabItem { Label("Accessibility", systemImage: "accessibility") }
            SettingsView()
                .tabItem { Label("Program", systemImage: "slider.horizontal.3") }
            MacNotificationsSettingsView()
                .tabItem { Label("Notifications", systemImage: "bell") }
            DataSettingsView()
                .tabItem { Label("Data", systemImage: "externaldrive") }
            AboutSettingsView()
                .tabItem { Label("About", systemImage: "info.circle") }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .appLayoutScale(store.preferences.interfaceSize.scale)
        .frame(
            minWidth: 800,
            idealWidth: 960 * store.preferences.interfaceSize.scale,
            maxWidth: .infinity,
            minHeight: 520,
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
}

struct DataSettingsView: View {
    @EnvironmentObject private var store: OnPlanStore
    @State private var statusTick = 0
    @State private var isChecking = false

    var body: some View {
        NavigationStack {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
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
                    NavigationLink {
                        BackupRestoreView()
                    } label: {
                        Label("Open backup & restore", systemImage: "arrow.up.arrow.down")
                    }
                    Text("Backups include days, weights, body composition, measurements, meals, and settings. Restore replaces everything currently in the journal.")
                        .appFont(.body)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(16)
        }
        .background(Color(nsColor: .windowBackgroundColor))
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
