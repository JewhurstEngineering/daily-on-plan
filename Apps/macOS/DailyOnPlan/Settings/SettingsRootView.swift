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
            TrackingSettingsView()
                .tabItem { Label("Tracking", systemImage: "checklist") }
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

struct TrackingSettingsView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                SettingsPanel(
                    title: "Smoking, drinking & bathroom",
                    systemImage: "iphone",
                    subtitle: "Modes and limits are set on iPhone."
                ) {
                    Text("Use the iPhone app to turn smoking or drinking tracking on, pick count / reduce / quit, and show or hide bathroom. This Mac menu bar shows today’s counts and quick-add when those sections are enabled.")
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

struct DataSettingsView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                SettingsPanel(
                    title: "Backup on iPhone",
                    systemImage: "externaldrive",
                    subtitle: "Full backup and restore live on iPhone."
                ) {
                    Text("Create and restore backups from the iPhone app. This Mac reads the shared day log; export a backup on iPhone before deleting the app. Report exports from iPhone cannot restore data.")
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
