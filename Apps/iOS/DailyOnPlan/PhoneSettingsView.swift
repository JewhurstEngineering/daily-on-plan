import SwiftUI
import SwiftData
import OnPlanCore

struct PhoneSettingsView: View {
    @EnvironmentObject private var store: OnPlanStore
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        NavigationStack {
            List {
                Section("Look") {
                    NavigationLink {
                        PhoneThemeSettings()
                    } label: {
                        Label("Theme", systemImage: "paintpalette")
                    }
                    NavigationLink {
                        PhoneAccessibilitySettings()
                    } label: {
                        Label("Accessibility", systemImage: "accessibility")
                    }
                    NavigationLink {
                        DayLayoutSettingsView(settings: DataStore.settings(in: modelContext))
                    } label: {
                        Label("Day layout", systemImage: "list.bullet.rectangle")
                    }
                }

                Section("Program") {
                    NavigationLink {
                        SettingsView()
                    } label: {
                        Label("Program, body & tracking", systemImage: "slider.horizontal.3")
                    }
                    NavigationLink {
                        NotificationsSettingsView(settings: DataStore.settings(in: modelContext))
                    } label: {
                        Label("Notifications", systemImage: "bell.badge")
                    }
                    NavigationLink {
                        MotivationQuotesSettingsView(settings: DataStore.settings(in: modelContext))
                    } label: {
                        Label("Quotes", systemImage: "quote.closing")
                    }
                }

                Section("Data") {
                    NavigationLink {
                        BackupRestoreView()
                    } label: {
                        Label("Backup & restore", systemImage: "externaldrive.badge.icloud")
                    }
                    NavigationLink {
                        ExportSheetView(selectedDate: Date())
                    } label: {
                        Label("Export & share", systemImage: "square.and.arrow.up")
                    }
                }

                Section("App") {
                    NavigationLink {
                        PhoneAboutSettings()
                    } label: {
                        Label("About", systemImage: "info.circle")
                    }
                    NavigationLink {
                        PhoneWatchSettings()
                    } label: {
                        Label("Apple Watch", systemImage: "applewatch")
                    }
                    Text("Configure the three Watch quick-add buttons. Logging still needs the iPhone reachable.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Settings")
        }
    }
}
