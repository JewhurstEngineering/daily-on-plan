import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var settings: AppSettings?
    @State private var heightFeet = 5
    @State private var heightInchesPart = 8
    @Query(sort: \CustomFoodPreset.name) private var presets: [CustomFoodPreset]

    var body: some View {
        NavigationStack {
            Group {
                if let settings {
                    Form {
                        Section("Program") {
                            Picker("Phase", selection: Binding(
                                get: { settings.phase },
                                set: {
                                    settings.phase = $0
                                    save(settings)
                                }
                            )) {
                                ForEach(ProgramPhase.allCases) { phase in
                                    Text(phase.title).tag(phase)
                                }
                            }
                            Stepper(
                                "Default protein goal: \(settings.defaultProteinGoal)",
                                value: Binding(
                                    get: { settings.defaultProteinGoal },
                                    set: {
                                        settings.defaultProteinGoal = $0
                                        save(settings)
                                    }
                                ),
                                in: 100...1200,
                                step: 25
                            )
                        }

                        Section("Body metrics") {
                            Toggle("Use kilograms", isOn: Binding(
                                get: { settings.usesMetricWeight },
                                set: {
                                    settings.usesMetricWeight = $0
                                    save(settings)
                                }
                            ))
                            Stepper("Height: \(heightFeet) ft \(heightInchesPart) in", value: $heightFeet, in: 4...7)
                            Stepper("Inches: \(heightInchesPart)", value: $heightInchesPart, in: 0...11)
                            Button("Save height") {
                                settings.heightInches = Double(heightFeet * 12 + heightInchesPart)
                                save(settings)
                            }
                            if settings.hasHeight {
                                let feet = Int(settings.heightInches / 12)
                                let inches = Int(settings.heightInches.truncatingRemainder(dividingBy: 12))
                                Text("Stored height: \(feet)'\(inches)\"")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Section("Notifications") {
                            Toggle("Water reminders", isOn: Binding(
                                get: { settings.waterReminderEnabled },
                                set: {
                                    settings.waterReminderEnabled = $0
                                    save(settings)
                                    Task { await NotificationService.shared.reschedule(using: settings) }
                                }
                            ))
                            Stepper(
                                "Every \(settings.waterReminderIntervalHours) hours",
                                value: Binding(
                                    get: { settings.waterReminderIntervalHours },
                                    set: {
                                        settings.waterReminderIntervalHours = $0
                                        save(settings)
                                        Task { await NotificationService.shared.reschedule(using: settings) }
                                    }
                                ),
                                in: 1...6
                            )
                            Toggle("Evening check-in", isOn: Binding(
                                get: { settings.eveningCheckInEnabled },
                                set: {
                                    settings.eveningCheckInEnabled = $0
                                    save(settings)
                                    Task { await NotificationService.shared.reschedule(using: settings) }
                                }
                            ))
                            DatePicker(
                                "Check-in time",
                                selection: Binding(
                                    get: {
                                        Calendar.current.date(
                                            bySettingHour: settings.eveningCheckInHour,
                                            minute: settings.eveningCheckInMinute,
                                            second: 0,
                                            of: Date()
                                        ) ?? Date()
                                    },
                                    set: { date in
                                        let comps = Calendar.current.dateComponents([.hour, .minute], from: date)
                                        settings.eveningCheckInHour = comps.hour ?? 20
                                        settings.eveningCheckInMinute = comps.minute ?? 0
                                        save(settings)
                                        Task { await NotificationService.shared.reschedule(using: settings) }
                                    }
                                ),
                                displayedComponents: .hourAndMinute
                            )
                        }

                        Section("Supplements") {
                            ForEach(Array(settings.supplements.enumerated()), id: \.element.id) { index, supplement in
                                Stepper(
                                    "\(supplement.name): \(supplement.dosesPerDay)/day",
                                    value: Binding(
                                        get: { settings.supplements[index].dosesPerDay },
                                        set: { newValue in
                                            var list = settings.supplements
                                            list[index].dosesPerDay = newValue
                                            settings.supplements = list
                                            save(settings)
                                        }
                                    ),
                                    in: 1...6
                                )
                            }
                        }

                        Section("My Presets") {
                            if presets.isEmpty {
                                Text("Save foods as presets when adding protein.")
                                    .foregroundStyle(.secondary)
                            } else {
                                ForEach(presets, id: \.id) { preset in
                                    HStack {
                                        VStack(alignment: .leading) {
                                            Text(preset.name)
                                            Text("\(preset.servingLabel) · \(preset.calories) kcal")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                        Spacer()
                                        Button(role: .destructive) {
                                            modelContext.delete(preset)
                                            try? modelContext.save()
                                        } label: {
                                            Image(systemName: "trash")
                                        }
                                    }
                                }
                            }
                        }

                        Section("Hunger Scale") {
                            Text(HungerScale.guidance)
                            ForEach(HungerScale.levels, id: \.0) { level in
                                Text("\(level.0): \(level.1)")
                                    .font(.caption)
                            }
                        }

                        Section("Health") {
                            Button("Request Apple Health access") {
                                Task { await HealthKitService.shared.requestAuthorization() }
                            }
                        }
                    }
                } else {
                    ProgressView()
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear {
                let s = DataStore.settings(in: modelContext)
                settings = s
                let total = Int(s.heightInches)
                if total > 0 {
                    heightFeet = total / 12
                    heightInchesPart = total % 12
                }
            }
        }
    }

    private func save(_ settings: AppSettings) {
        try? modelContext.save()
    }
}
