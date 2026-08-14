import SwiftUI
import SwiftData
import OnPlanCore

struct MacLifestyleSettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var allSettings: [AppSettings]

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
            SettingsPanel(
                title: "Hydration",
                systemImage: "drop.fill",
                subtitle: "Bottle size is the popover tap. Target is the daily goal."
            ) {
                HStack(alignment: .firstTextBaseline, spacing: 16) {
                    Picker("Default bottle", selection: Binding(
                        get: { settings.defaultBottleOz },
                        set: {
                            settings.defaultBottleOz = $0
                            save()
                        }
                    )) {
                        Text("8 oz").tag(8.0)
                        Text("12 oz").tag(12.0)
                        Text("16.9 oz").tag(16.9)
                        Text("20 oz").tag(20.0)
                        Text("24 oz").tag(24.0)
                    }
                    .frame(maxWidth: 280)

                    Stepper(
                        "Daily target: \(settings.hydrationTargetOz) oz",
                        value: Binding(
                            get: { settings.hydrationTargetOz },
                            set: {
                                settings.hydrationTargetOz = $0
                                save()
                            }
                        ),
                        in: 16...400,
                        step: 8
                    )
                }

                Toggle("Protein drinks count toward water", isOn: Binding(
                    get: { settings.proteinDrinksCountTowardHydration },
                    set: {
                        settings.proteinDrinksCountTowardHydration = $0
                        save()
                    }
                ))
                .toggleStyle(.checkbox)

                if settings.proteinDrinksCountTowardHydration {
                    Stepper(
                        "Shake size: \(Int(settings.defaultShakeHydrationOz)) oz",
                        value: Binding(
                            get: { Int(settings.defaultShakeHydrationOz) },
                            set: {
                                settings.defaultShakeHydrationOz = Double($0)
                                save()
                            }
                        ),
                        in: 4...32,
                        step: 1
                    )
                }
            }

            MacSettingsTwoColumn {
                smokingPanel(settings)
            } right: {
                drinkingPanel(settings)
            }

            bathroomPanel(settings)
        }
    }

    private func smokingPanel(_ settings: AppSettings) -> some View {
        SettingsPanel(
            title: "Smoking",
            systemImage: "smoke",
            subtitle: settings.smokingMode.subtitle,
            fillsHeight: true
        ) {
            Picker("Mode", selection: Binding(
                get: { settings.smokingMode },
                set: {
                    settings.smokingMode = $0
                    if $0 == .quit, settings.quitDate == nil { settings.quitDate = Date() }
                    save()
                }
            )) {
                ForEach(SmokingMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            if settings.smokingMode == .reduce {
                Stepper(
                    "Daily max: \(CigarettePackMath.packsLabel(cigarettes: settings.dailyCigaretteLimit))",
                    value: Binding(
                        get: { Int((settings.dailyCigaretteLimitPacks * 2).rounded()) },
                        set: {
                            settings.dailyCigaretteLimitPacks = Double($0) / 2.0
                            save()
                        }
                    ),
                    in: 0...(AppLimits.cigaretteLimitMax * 2 / CigarettePackMath.perPack),
                    step: 1
                )
            }
            if settings.smokingMode == .quit {
                DatePicker(
                    "Quit date",
                    selection: Binding(
                        get: { settings.quitDate ?? Date() },
                        set: {
                            settings.quitDate = $0
                            save()
                        }
                    ),
                    in: ...Date(),
                    displayedComponents: .date
                )
                .controlSize(.small)
            }
        }
    }

    private func drinkingPanel(_ settings: AppSettings) -> some View {
        SettingsPanel(
            title: "Drinking",
            systemImage: "wineglass",
            subtitle: settings.drinkingMode.subtitle,
            fillsHeight: true
        ) {
            Picker("Mode", selection: Binding(
                get: { settings.drinkingMode },
                set: {
                    settings.drinkingMode = $0
                    if $0 == .quit, settings.alcoholQuitDate == nil { settings.alcoholQuitDate = Date() }
                    save()
                }
            )) {
                ForEach(DrinkingMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            if settings.drinkingMode == .reduce {
                Stepper(
                    "Daily max: \(settings.dailyDrinkLimit) drinks",
                    value: Binding(
                        get: { settings.dailyDrinkLimit },
                        set: {
                            settings.dailyDrinkLimit = $0
                            save()
                        }
                    ),
                    in: 0...AppLimits.drinkLimitMax,
                    step: 1
                )
            }
            if settings.drinkingMode == .quit {
                DatePicker(
                    "Quit date",
                    selection: Binding(
                        get: { settings.alcoholQuitDate ?? Date() },
                        set: {
                            settings.alcoholQuitDate = $0
                            save()
                        }
                    ),
                    in: ...Date(),
                    displayedComponents: .date
                )
                .controlSize(.small)
            }
        }
    }

    private func bathroomPanel(_ settings: AppSettings) -> some View {
        SettingsPanel(
            title: "Bathroom",
            systemImage: "toilet.fill",
            subtitle: "Quick-add urine and stool in the popover when this is on."
        ) {
            Toggle("Show bathroom on the day sheet", isOn: Binding(
                get: { settings.showBathroomSection },
                set: {
                    settings.showBathroomSection = $0
                    save()
                }
            ))
            .toggleStyle(.checkbox)
            Text("Adds urine and stool taps in the popover. On iPhone it stays collapsed until you expand it.")
                .appFont(.caption2)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func save() {
        modelContext.saveAndNotifyJournal()
    }
}
