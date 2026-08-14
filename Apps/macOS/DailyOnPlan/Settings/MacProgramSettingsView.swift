import SwiftUI
import SwiftData
import OnPlanCore

struct MacProgramSettingsView: View {
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
            MacSettingsTwoColumn {
                SettingsPanel(
                    title: "Program",
                    systemImage: "flag.checkered",
                    subtitle: "Phase and default protein goal. Syncs with iPhone.",
                    fillsHeight: true
                ) {
                    Picker("Phase", selection: Binding(
                        get: { settings.phase },
                        set: {
                            settings.phase = $0
                            save()
                        }
                    )) {
                        ForEach(ProgramPhase.allCases) { phase in
                            Text(phase.title).tag(phase)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()

                    Text(settings.phase == .week1 ? "Week 1 holds fats and fruit." : "Week 2+ allows fats and fruit.")
                        .appFont(.caption2)
                        .foregroundStyle(.secondary)

                    Stepper(
                        "Protein goal: \(settings.defaultProteinGoal) kcal",
                        value: Binding(
                            get: { settings.defaultProteinGoal },
                            set: {
                                settings.defaultProteinGoal = $0
                                save()
                            }
                        ),
                        in: AppLimits.proteinGoalMin...AppLimits.proteinGoalMax,
                        step: 1
                    )
                }
            } right: {
                SettingsPanel(
                    title: "Hunger scale",
                    systemImage: "fork.knife.circle",
                    subtitle: HungerScale.guidance,
                    fillsHeight: true
                ) {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
                        ForEach(HungerScale.levels, id: \.0) { level in
                            HStack(alignment: .firstTextBaseline, spacing: 6) {
                                Text("\(level.0)")
                                    .appFont(.caption, weight: .semibold, mono: true)
                                    .frame(width: 16, alignment: .trailing)
                                Text(level.1)
                                    .appFont(.caption2)
                                    .foregroundStyle(.secondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }
                }
            }
        }
    }

    private func save() {
        modelContext.saveAndNotifyJournal()
    }
}
