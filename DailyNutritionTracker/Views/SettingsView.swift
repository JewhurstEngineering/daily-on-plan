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
                        Section("Appearance") {
                            Text(AppIdentity.tagline)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                            Text("Accent color")
                                .font(.subheadline)
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 12) {
                                ForEach(AccentTheme.allCases) { theme in
                                    Button {
                                        settings.accentTheme = theme
                                        save(settings)
                                    } label: {
                                        ZStack {
                                            Circle()
                                                .fill(theme.color)
                                                .frame(width: 36, height: 36)
                                            if settings.accentTheme == theme {
                                                Image(systemName: "checkmark")
                                                    .font(.caption.weight(.bold))
                                                    .foregroundStyle(.white)
                                            }
                                        }
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityLabel(theme.title)
                                }
                            }
                            Text(settings.accentTheme.title)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

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
                                "Protein goal: \(settings.defaultProteinGoal) kcal",
                                value: Binding(
                                    get: { settings.defaultProteinGoal },
                                    set: {
                                        settings.defaultProteinGoal = $0
                                        save(settings)
                                    }
                                ),
                                in: AppLimits.proteinGoalMin...AppLimits.proteinGoalMax,
                                step: 1
                            )
                        }

                        Section {
                            Toggle("Use kilograms", isOn: Binding(
                                get: { settings.usesMetricWeight },
                                set: {
                                    settings.usesMetricWeight = $0
                                    save(settings)
                                }
                            ))

                            HStack {
                                Text("Height")
                                Spacer()
                                Picker("Feet", selection: $heightFeet) {
                                    ForEach(4...7, id: \.self) { Text("\($0) ft").tag($0) }
                                }
                                .labelsHidden()
                                .pickerStyle(.menu)

                                Picker("Inches", selection: $heightInchesPart) {
                                    ForEach(0...11, id: \.self) { Text("\($0) in").tag($0) }
                                }
                                .labelsHidden()
                                .pickerStyle(.menu)
                            }

                            Text("Saved as \(heightFeet)'\(heightInchesPart)\"")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } header: {
                            Text("Body metrics")
                        } footer: {
                            Text("BMI uses this height with each day’s weight. Change either picker — both update together.")
                        }
                        .onChange(of: heightFeet) { _, _ in persistHeight(settings) }
                        .onChange(of: heightInchesPart) { _, _ in persistHeight(settings) }

                        Section {
                            NavigationLink {
                                NotificationsSettingsView(settings: settings)
                            } label: {
                                Label("Notifications", systemImage: "bell.badge")
                            }
                            NavigationLink {
                                SavedMealsListView(settings: settings)
                            } label: {
                                Label("Saved meals", systemImage: "fork.knife")
                            }
                            NavigationLink {
                                FoodPreferencesView(settings: settings)
                            } label: {
                                Label("Food preferences", systemImage: "heart.slash")
                            }
                        } header: {
                            Text("Reminders & meals")
                        } footer: {
                            Text("Notifications default to evening plan, ketosis check, and daily check-in. Food preferences filter allergies and picky-eater picks.")
                        }

                        Section("Hydration defaults") {
                            Picker("Default bottle", selection: Binding(
                                get: { settings.defaultBottleOz },
                                set: {
                                    settings.defaultBottleOz = $0
                                    save(settings)
                                }
                            )) {
                                Text("8 oz").tag(8.0)
                                Text("12 oz").tag(12.0)
                                Text("16.9 oz").tag(16.9)
                                Text("20 oz").tag(20.0)
                                Text("24 oz").tag(24.0)
                            }
                            Stepper(
                                "Daily target: \(settings.hydrationTargetOz) oz",
                                value: Binding(
                                    get: { settings.hydrationTargetOz },
                                    set: {
                                        settings.hydrationTargetOz = $0
                                        save(settings)
                                    }
                                ),
                                in: 32...200,
                                step: 8
                            )
                        }

                        Section("Supplements") {
                            Toggle("Show supplements section", isOn: Binding(
                                get: { settings.showSupplementsSection },
                                set: {
                                    settings.showSupplementsSection = $0
                                    save(settings)
                                }
                            ))
                            Text("Or hide individual items from the gear on the Supplements card.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                            if settings.showSupplementsSection {
                                Button("Disable all items") {
                                    var list = settings.supplements
                                    for i in list.indices { list[i].isEnabled = false }
                                    settings.supplements = list
                                    save(settings)
                                }
                                ForEach(Array(settings.supplements.enumerated()), id: \.element.id) { index, supplement in
                                    Toggle(isOn: Binding(
                                        get: { settings.supplements[index].isEnabled },
                                        set: { newValue in
                                            var list = settings.supplements
                                            list[index].isEnabled = newValue
                                            settings.supplements = list
                                            save(settings)
                                        }
                                    )) {
                                        Text(supplement.name)
                                    }
                                }
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

    private func persistHeight(_ settings: AppSettings) {
        settings.heightInches = Double(heightFeet * 12 + heightInchesPart)
        save(settings)
    }

    private func save(_ settings: AppSettings) {
        try? modelContext.save()
    }
}
