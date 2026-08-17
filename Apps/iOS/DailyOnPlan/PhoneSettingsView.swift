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
                        Label("Program & body", systemImage: "slider.horizontal.3")
                    }
                    NavigationLink {
                        TrackingSettingsView(settings: DataStore.settings(in: modelContext))
                    } label: {
                        Label("Tracking & habits", systemImage: "checklist")
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

                Section {
                    NavigationLink {
                        BackupRestoreView()
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Label("Backup & restore", systemImage: "externaldrive.badge.icloud")
                            Text("Full data backup for reinstalls or a new device")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    NavigationLink {
                        ExportSheetView(selectedDate: Date())
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Label("Export & share", systemImage: "square.and.arrow.up")
                            Text("A day's report as CSV, PDF, or a share card")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text("Data")
                } footer: {
                    Text("Backup is your whole journal, for moving devices. Export is a snapshot of one day's data to share.")
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
