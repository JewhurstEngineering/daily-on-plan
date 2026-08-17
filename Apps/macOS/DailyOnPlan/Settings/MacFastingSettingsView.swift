import SwiftUI
import SwiftData
import OnPlanCore

struct MacFastingSettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.appTheme) private var appTheme
    @EnvironmentObject private var store: OnPlanStore
    @Query private var allSettings: [AppSettings]
    @Query(sort: \DailyLog.date, order: .reverse) private var logs: [DailyLog]

    var body: some View {
        Group {
            if let settings = allSettings.first {
                content(settings)
            } else {
                ProgressView("Waiting for journal…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .onAppear { _ = DataStore.settings(in: modelContext) }
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private func content(_ settings: AppSettings) -> some View {
        MacSettingsScroll {
            if settings.fastingEnabled {
                let log = DataStore.log(for: Date(), in: modelContext, defaultGoal: settings.defaultProteinGoal)
                SettingsPanel(
                    title: "Today",
                    systemImage: "flame.fill",
                    subtitle: "Live clock. Same tracker as Today and the popover."
                ) {
                    FastingTrackerCard(
                        log: log,
                        previous: previousLog,
                        settings: settings,
                        streak: FastingMath.streak(logs: Array(logs.prefix(60)), settings: settings),
                        onChange: {
                            modelContext.saveAndNotifyJournal()
                            MacDaySync.refresh(store: store)
                        }
                    )
                    .environment(\.accentPrimary, appTheme.tint)
                }
            }

            MacSettingsTwoColumn {
                SettingsPanel(
                    title: "Protocol",
                    systemImage: "clock",
                    subtitle: "Typical window. Syncs with iPhone.",
                    fillsHeight: true
                ) {
                    Toggle("Track fasting", isOn: Binding(
                        get: { settings.fastingEnabled },
                        set: {
                            settings.fastingEnabled = $0
                            persist(settings)
                        }
                    ))
                    .toggleStyle(.checkbox)

                    if settings.fastingEnabled {
                        Picker("Preset", selection: Binding(
                            get: { settings.fastingPreset },
                            set: {
                                settings.fastingPreset = $0
                                persist(settings)
                            }
                        )) {
                            ForEach(FastingPreset.allCases) { preset in
                                Text(preset.title).tag(preset)
                            }
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()

                        Text(settings.fastingPreset.blurb)
                            .appFont(.caption2)
                            .foregroundStyle(.secondary)

                        if settings.fastingPreset == .custom {
                            Stepper(
                                "Fast \(Int(settings.fastingCustomFastHours.rounded())) hours",
                                value: Binding(
                                    get: { Int(settings.fastingCustomFastHours.rounded()) },
                                    set: {
                                        settings.fastingCustomFastHours = Double($0)
                                        persist(settings)
                                    }
                                ),
                                in: 12...23
                            )
                        }

                        DatePicker(
                            "Typical eat start",
                            selection: Binding(
                                get: {
                                    Calendar.current.date(
                                        bySettingHour: settings.fastingEatStartHour,
                                        minute: settings.fastingEatStartMinute,
                                        second: 0,
                                        of: Date()
                                    ) ?? Date()
                                },
                                set: { date in
                                    let c = Calendar.current.dateComponents([.hour, .minute], from: date)
                                    settings.fastingEatStartHour = c.hour ?? 12
                                    settings.fastingEatStartMinute = c.minute ?? 0
                                    persist(settings)
                                }
                            ),
                            displayedComponents: .hourAndMinute
                        )
                        .controlSize(.small)

                        Text("Eat \(formatHours(settings.fastingEatHours)) · fast \(formatHours(settings.fastingTargetHours)).")
                            .appFont(.caption2)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Off until you turn it on. Start / End on Today still records a window.")
                            .appFont(.caption2)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            } right: {
                SettingsPanel(
                    title: "History",
                    systemImage: "calendar",
                    subtitle: "Overnight fast vs the target.",
                    fillsHeight: true
                ) {
                    Text(todayLine(settings))
                        .appFont(.subheadline, weight: .semibold)
                    Text(streakLine(settings))
                        .appFont(.caption)
                        .foregroundStyle(.secondary)
                    if settings.fastingEnabled {
                        let rows = FastingMath.history(logs: Array(logs.prefix(14).reversed()), settings: settings)
                        if rows.isEmpty {
                            Text("Start or end a window to build history.")
                                .appFont(.caption2)
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(rows.suffix(7).reversed()) { row in
                                HStack {
                                    Text(row.date, format: .dateTime.month(.abbreviated).day())
                                    Spacer()
                                    Text(FastingMath.formatDuration(row.duration))
                                        .monospacedDigit()
                                    Image(systemName: row.hit ? "checkmark.circle.fill" : "circle")
                                        .foregroundStyle(row.hit ? Color.green : Color.secondary)
                                }
                                .appFont(.caption)
                            }
                        }
                    }
                }
            }

            if settings.fastingEnabled {
                SettingsPanel(
                    title: "Reminders",
                    systemImage: "bell",
                    subtitle: "Follow the typical clock. Same toggles as Notifications."
                ) {
                    Toggle("Window opening", isOn: Binding(
                        get: { settings.fastingNotifyOpenEnabled },
                        set: {
                            settings.fastingNotifyOpenEnabled = $0
                            persist(settings)
                        }
                    ))
                    .toggleStyle(.checkbox)
                    if settings.fastingNotifyOpenEnabled {
                        Stepper(
                            leadLabel(settings.fastingNotifyOpenMinutes, opening: true),
                            value: Binding(
                                get: { settings.fastingNotifyOpenMinutes },
                                set: {
                                    settings.fastingNotifyOpenMinutes = $0
                                    persist(settings)
                                }
                            ),
                            in: 0...60,
                            step: 5
                        )
                    }
                    Toggle("Window closing", isOn: Binding(
                        get: { settings.fastingNotifyCloseEnabled },
                        set: {
                            settings.fastingNotifyCloseEnabled = $0
                            persist(settings)
                        }
                    ))
                    .toggleStyle(.checkbox)
                    if settings.fastingNotifyCloseEnabled {
                        Stepper(
                            leadLabel(settings.fastingNotifyCloseMinutes, opening: false),
                            value: Binding(
                                get: { settings.fastingNotifyCloseMinutes },
                                set: {
                                    settings.fastingNotifyCloseMinutes = $0
                                    persist(settings)
                                }
                            ),
                            in: 0...60,
                            step: 5
                        )
                    }
                    Toggle("Still eating after close", isOn: Binding(
                        get: { settings.fastingNotifyOvertimeEnabled },
                        set: {
                            settings.fastingNotifyOvertimeEnabled = $0
                            persist(settings)
                        }
                    ))
                    .toggleStyle(.checkbox)
                }
            }
        }
    }

    private var todayLog: DailyLog? {
        logs.first { Calendar.current.isDateInToday($0.date) }
    }

    private var previousLog: DailyLog? {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()
        return logs.first { Calendar.current.isDate($0.date, inSameDayAs: yesterday) }
    }

    private func todayLine(_ settings: AppSettings) -> String {
        FastingMath.statusLine(today: todayLog, previous: previousLog, settings: settings)
    }

    private func streakLine(_ settings: AppSettings) -> String {
        let n = FastingMath.streak(logs: Array(logs.prefix(60)), settings: settings)
        if n == 0 { return "No streak yet." }
        return n == 1 ? "1 day streak" : "\(n) day streak"
    }

    private func formatHours(_ hours: Double) -> String {
        if hours == hours.rounded() { return "\(Int(hours))h" }
        return String(format: "%.1fh", hours)
    }

    private func leadLabel(_ minutes: Int, opening: Bool) -> String {
        if minutes == 0 { return opening ? "At window start" : "At window end" }
        return "\(minutes) min before"
    }

    private func persist(_ settings: AppSettings) {
        modelContext.saveAndNotifyJournal()
        Task { await NotificationService.shared.reschedule(using: settings) }
    }
}
