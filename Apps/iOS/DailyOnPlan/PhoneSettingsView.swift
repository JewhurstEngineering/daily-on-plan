import SwiftUI
import SwiftData
import OnPlanCore

/// Settings, regrouped so the things that change most often lead and carry their current
/// value on the row, instead of a flat wall of identical navigation links.
/// See the redesign canvas, "Settings".
struct PhoneSettingsView: View {
    @EnvironmentObject private var store: OnPlanStore
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        NavigationStack {
            let settings = DataStore.settings(in: modelContext)

            List {
                Section("Goals") {
                    NavigationLink {
                        ProteinGoalSettingsForm(settings: settings)
                    } label: {
                        SettingsValueRow(
                            title: "Protein goal",
                            systemImage: "fork.knife",
                            value: "\(settings.defaultProteinGoal) kcal"
                        )
                    }
                    NavigationLink {
                        HydrationSettingsForm(settings: settings)
                    } label: {
                        SettingsValueRow(
                            title: "Hydration target",
                            systemImage: "drop.fill",
                            value: "\(settings.hydrationTargetOz) oz"
                        )
                    }
                    NavigationLink {
                        BodyMetricsSettingsForm(settings: settings)
                    } label: {
                        SettingsValueRow(
                            title: "Goal weight & height",
                            systemImage: "scalemass",
                            value: goalBodyValue(settings)
                        )
                    }
                }

                Section {
                    Toggle(isOn: hideWeightBinding) {
                        Label("Hide weight until tapped", systemImage: "eye.slash")
                    }
                    NavigationLink {
                        TrackingSettingsView(settings: settings)
                    } label: {
                        SettingsValueRow(
                            title: "“Also today” sections",
                            systemImage: "list.bullet",
                            value: "\(alsoTodayCount(settings)) on"
                        )
                    }
                    NavigationLink {
                        DayLayoutSettingsView(settings: settings)
                    } label: {
                        Label("Day layout", systemImage: "list.bullet.rectangle")
                    }
                } header: {
                    Text("Today screen")
                } footer: {
                    Text("Hiding weight masks it and your BMI on Today until you tap; it re-hides whenever you leave the app. Anything switched off leaves Today and the “Also today” list for good.")
                }

                Section("Look") {
                    NavigationLink {
                        PhoneThemeSettings()
                    } label: {
                        SettingsValueRow(
                            title: "Theme",
                            systemImage: "paintpalette",
                            value: store.preferences.colorTheme.title
                        )
                    }
                    NavigationLink {
                        PhoneAccessibilitySettings()
                    } label: {
                        Label("Accessibility", systemImage: "accessibility")
                    }
                }

                Section {
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
                } header: {
                    Text("Data")
                } footer: {
                    Text("Backup is your whole journal, for moving devices. Export is a snapshot of one day's data to share.")
                }

                Section("More") {
                    NavigationLink {
                        NotificationsSettingsView(settings: settings)
                    } label: {
                        Label("Reminders", systemImage: "bell.badge")
                    }
                    NavigationLink {
                        SettingsView(presentedAsSheet: false)
                    } label: {
                        Label("Program & body", systemImage: "slider.horizontal.3")
                    }
                    NavigationLink {
                        MotivationQuotesSettingsView(settings: settings)
                    } label: {
                        Label("Quotes", systemImage: "quote.closing")
                    }
                    NavigationLink {
                        PhoneWatchSettings()
                    } label: {
                        Label("Apple Watch", systemImage: "applewatch")
                    }
                    NavigationLink {
                        PhoneAboutSettings()
                    } label: {
                        Label("About & privacy", systemImage: "info.circle")
                    }
                }
            }
            .navigationTitle("Settings")
        }
    }

    private func goalBodyValue(_ settings: AppSettings) -> String {
        let unit = settings.usesMetricWeight ? "kg" : "lb"
        guard let goal = settings.goalWeightLbs else {
            return settings.hasHeight ? settings.heightDisplay : "Not set"
        }
        let value = settings.usesMetricWeight ? goal * 0.453592 : goal
        return String(format: "%.0f %@", value, unit)
    }

    private func alsoTodayCount(_ settings: AppSettings) -> Int {
        AlsoTodayCatalog.sections(for: settings).count
    }

    private var hideWeightBinding: Binding<Bool> {
        Binding(
            get: { store.preferences.hideWeightUntilTapped },
            set: { newValue in
                store.updatePreferences { $0.hideWeightUntilTapped = newValue }
            }
        )
    }
}

/// A settings row that shows its current value, so the list answers questions without
/// making you open every screen to find out what things are set to.
struct SettingsValueRow: View {
    let title: String
    let systemImage: String
    let value: String

    var body: some View {
        HStack(spacing: Spacing.s) {
            Label(title, systemImage: systemImage)
            Spacer(minLength: Spacing.s)
            Text(value)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }
}
