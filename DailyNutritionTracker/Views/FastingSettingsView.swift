import SwiftUI
import SwiftData

struct FastingSettingsView: View {
    @Bindable var settings: AppSettings
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \DailyLog.date, order: .reverse) private var logs: [DailyLog]

    var body: some View {
        Form {
            Section {
                Toggle("Track fasting", isOn: Binding(
                    get: { settings.fastingEnabled },
                    set: {
                        settings.fastingEnabled = $0
                        persist()
                    }
                ))
                Text("Off until you turn it on. The day sheet still lets you tap Start / End without a protocol.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } footer: {
                Text("Protocol, typical hours, and nags sync with Mac over iCloud.")
            }

            if settings.fastingEnabled {
                Section("Protocol") {
                    Picker("Preset", selection: Binding(
                        get: { settings.fastingPreset },
                        set: {
                            settings.fastingPreset = $0
                            persist()
                        }
                    )) {
                        ForEach(FastingPreset.allCases) { preset in
                            Text(preset.title).tag(preset)
                        }
                    }
                    Text(settings.fastingPreset.blurb)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    if settings.fastingPreset == .custom {
                        Stepper(
                            "Fast \(Int(settings.fastingCustomFastHours.rounded())) hours",
                            value: Binding(
                                get: { Int(settings.fastingCustomFastHours.rounded()) },
                                set: {
                                    settings.fastingCustomFastHours = Double($0)
                                    persist()
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
                                persist()
                            }
                        ),
                        displayedComponents: .hourAndMinute
                    )
                    Text("Eat for \(formatHours(settings.fastingEatHours)). Fast \(formatHours(settings.fastingTargetHours)).")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("Today") {
                    FastingTrackerCard(
                        log: DataStore.log(for: Date(), in: modelContext, defaultGoal: settings.defaultProteinGoal),
                        previous: previousLog,
                        settings: settings,
                        streak: FastingMath.streak(logs: Array(logs.prefix(60)), settings: settings),
                        onChange: { modelContext.saveAndNotifyJournal() }
                    )
                    .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
                }

                Section("Recent") {
                    if recent.isEmpty {
                        Text("Start or end a window on the day sheet to build history.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(recent.reversed()) { row in
                            HStack {
                                Text(row.date, format: .dateTime.month(.abbreviated).day())
                                Spacer()
                                Text(FastingMath.formatDuration(row.duration))
                                    .monospacedDigit()
                                Image(systemName: row.hit ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(row.hit ? Color.green : Color.secondary)
                            }
                        }
                    }
                }

                Section {
                    Toggle("Window opening", isOn: Binding(
                        get: { settings.fastingNotifyOpenEnabled },
                        set: {
                            settings.fastingNotifyOpenEnabled = $0
                            persist()
                        }
                    ))
                    if settings.fastingNotifyOpenEnabled {
                        Stepper(
                            leadLabel(settings.fastingNotifyOpenMinutes, opening: true),
                            value: Binding(
                                get: { settings.fastingNotifyOpenMinutes },
                                set: {
                                    settings.fastingNotifyOpenMinutes = $0
                                    persist()
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
                            persist()
                        }
                    ))
                    if settings.fastingNotifyCloseEnabled {
                        Stepper(
                            leadLabel(settings.fastingNotifyCloseMinutes, opening: false),
                            value: Binding(
                                get: { settings.fastingNotifyCloseMinutes },
                                set: {
                                    settings.fastingNotifyCloseMinutes = $0
                                    persist()
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
                            persist()
                        }
                    ))
                } header: {
                    Text("Reminders")
                } footer: {
                    Text("Same nags as Notifications. They follow the typical clock, not a one-off tap.")
                }
            }
        }
        .navigationTitle("Fasting")
        .onPlanInlineNav()
    }

    private var previousLog: DailyLog? {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()
        return logs.first { Calendar.current.isDate($0.date, inSameDayAs: yesterday) }
    }

    private var recent: [FastingDayRecord] {
        FastingMath.history(logs: Array(logs.prefix(21).reversed()), settings: settings)
    }

    private func formatHours(_ hours: Double) -> String {
        if hours == hours.rounded() { return "\(Int(hours))h" }
        return String(format: "%.1fh", hours)
    }

    private func leadLabel(_ minutes: Int, opening: Bool) -> String {
        if minutes == 0 { return opening ? "At window start" : "At window end" }
        return "\(minutes) min before"
    }

    private func persist() {
        modelContext.saveAndNotifyJournal()
        Task { await NotificationService.shared.reschedule(using: settings) }
    }
}
