import SwiftUI
import OnPlanCore
import ServiceManagement

struct GeneralSettingsView: View {
    @EnvironmentObject private var store: OnPlanStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                SettingsPanel(
                    title: "Startup",
                    systemImage: "bolt.horizontal.circle",
                    subtitle: "Launch behavior.",
                    compact: true
                ) {
                    Toggle("Launch at login", isOn: launchAtLoginBinding)
                }

                SettingsPanel(
                    title: "Menu bar",
                    systemImage: "menubar.rectangle",
                    subtitle: "Show today’s metrics next to the icon.",
                    compact: true
                ) {
                    Toggle("Show title text in menu bar", isOn: showMenuBarBinding)
                }
            }
            .padding(12)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var launchAtLoginBinding: Binding<Bool> {
        Binding(
            get: { store.preferences.launchAtLogin },
            set: { newValue in
                var prefs = store.preferences
                prefs.launchAtLogin = newValue
                store.applyPreferences(prefs)
                do {
                    if newValue {
                        try SMAppService.mainApp.register()
                    } else {
                        try SMAppService.mainApp.unregister()
                    }
                } catch {}
            }
        )
    }

    private var showMenuBarBinding: Binding<Bool> {
        Binding(
            get: { store.preferences.showInMenuBar },
            set: { value in
                var prefs = store.preferences
                prefs.showInMenuBar = value
                store.applyPreferences(prefs)
            }
        )
    }
}
