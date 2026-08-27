import SwiftUI
import SwiftData

/// Protein goal editor for Settings → Goals. The old rows all pushed `SettingsView`
/// ("Program & Body"), so there was no way to change just the protein target.
struct ProteinGoalSettingsForm: View {
    @Bindable var settings: AppSettings
    @Environment(\.modelContext) private var modelContext
    @State private var goalText = ""
    @FocusState private var goalFocused: Bool

    var body: some View {
        Form {
            Section {
                HStack {
                    Text("Daily goal")
                    Spacer()
                    TextField("kcal", text: $goalText)
                        .onPlanKeyboard(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .focused($goalFocused)
                        .frame(maxWidth: 100)
                    Text("kcal")
                        .foregroundStyle(.secondary)
                }
                Stepper(
                    "Adjust: \(settings.defaultProteinGoal) kcal",
                    value: Binding(
                        get: { settings.defaultProteinGoal },
                        set: { apply($0) }
                    ),
                    in: AppLimits.proteinGoalMin...AppLimits.proteinGoalMax,
                    step: AppLimits.proteinGoalStep
                )
            } header: {
                Text("Protein")
            } footer: {
                Text("Today’s protein ring uses this goal. Past days keep whatever they were saved with.")
            }
        }
        .navigationTitle("Protein goal")
        .onPlanInlineNav()
        .keyboardDoneToolbar(focus: $goalFocused)
        .onAppear { goalText = "\(settings.defaultProteinGoal)" }
        .onChange(of: goalFocused) { _, focused in
            if !focused { commitText() }
        }
    }

    private func apply(_ goal: Int) {
        DataStore.setDefaultProteinGoal(goal, in: modelContext)
        goalText = "\(settings.defaultProteinGoal)"
        modelContext.saveAndNotifyJournal()
    }

    private func commitText() {
        if let value = Int(goalText.filter(\.isNumber)) {
            apply(value)
        } else {
            goalText = "\(settings.defaultProteinGoal)"
        }
    }
}

/// Height and goal weight, which the Settings Goals row promised but previously
/// opened Program & Body instead.
struct BodyMetricsSettingsForm: View {
    @Bindable var settings: AppSettings
    @Environment(\.modelContext) private var modelContext
    @State private var heightFeet = 5
    @State private var heightInchesPart = 8
    @State private var goalWeightText = ""
    @FocusState private var goalWeightFocused: Bool

    var body: some View {
        Form {
            Section {
                Toggle("Use kilograms", isOn: Binding(
                    get: { settings.usesMetricWeight },
                    set: {
                        settings.usesMetricWeight = $0
                        save()
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

                HStack {
                    TextField("Goal weight", text: $goalWeightText)
                        .onPlanKeyboard(.decimalPad)
                        .focused($goalWeightFocused)
                    Text(settings.usesMetricWeight ? "kg" : "lb")
                        .foregroundStyle(.secondary)
                }
                if settings.hasGoalWeight {
                    Button("Clear goal weight", role: .destructive) {
                        settings.goalWeightLbs = nil
                        goalWeightText = ""
                        save()
                    }
                }
            } header: {
                Text("Goal weight & height")
            } footer: {
                Text("Height is used for BMI. Goal weight shows on Today’s weight card.")
            }
            .onChange(of: heightFeet) { _, _ in persistHeight() }
            .onChange(of: heightInchesPart) { _, _ in persistHeight() }
            .onChange(of: goalWeightFocused) { _, focused in
                if !focused { commitGoalWeight() }
            }
        }
        .navigationTitle("Goal weight & height")
        .onPlanInlineNav()
        .keyboardDoneToolbar(focus: $goalWeightFocused)
        .onAppear(perform: load)
        .onDisappear { commitGoalWeight() }
    }

    private func load() {
        if let goal = settings.goalWeightLbs {
            let value = settings.usesMetricWeight ? goal * 0.453592 : goal
            goalWeightText = String(format: "%.1f", value)
        } else {
            goalWeightText = ""
        }
        let total = Int(settings.heightInches)
        if total > 0 {
            heightFeet = total / 12
            heightInchesPart = total % 12
        }
    }

    private func persistHeight() {
        settings.heightInches = Double(heightFeet * 12 + heightInchesPart)
        save()
    }

    private func commitGoalWeight() {
        let cleaned = goalWeightText.replacingOccurrences(of: ",", with: ".")
            .trimmingCharacters(in: .whitespaces)
        if cleaned.isEmpty { return }
        guard let value = Double(cleaned), value > 0 else {
            if let goal = settings.goalWeightLbs {
                let display = settings.usesMetricWeight ? goal * 0.453592 : goal
                goalWeightText = String(format: "%.1f", display)
            }
            return
        }
        settings.goalWeightLbs = settings.usesMetricWeight ? value / 0.453592 : value
        goalWeightText = String(format: "%.1f", value)
        save()
    }

    private func save() {
        modelContext.saveAndNotifyJournal()
    }
}
