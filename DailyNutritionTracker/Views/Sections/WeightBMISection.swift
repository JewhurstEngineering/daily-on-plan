import SwiftUI
import SwiftData
import Charts

struct WeightBMISection: View {
    let selectedDate: Date
    let weight: WeightEntry?
    let recentWeights: [WeightEntry]
    @Bindable var settings: AppSettings
    let onSave: (Double) -> Void
    var onOpenSettings: (() -> Void)? = nil

    @Environment(\.modelContext) private var modelContext
    @State private var draftText = ""
    @State private var showGoalEditor = false
    @State private var isEditingWeight = false
    @FocusState private var weightFocused: Bool

    private var unitLabel: String { settings.usesMetricWeight ? "kg" : "lb" }

    private var displayWeight: String {
        guard let weight else { return "—" }
        return String(format: "%.1f %@", displayValue(lbs: weight.weightLbs), unitLabel)
    }

    private var bmi: Double? {
        guard let weight else { return nil }
        return BMICalculator.bmi(weightLbs: weight.weightLbs, heightInches: settings.heightInches)
    }

    private var deltaText: String? {
        guard let weight,
              let prior = recentWeights.first(where: { $0.date < weight.date }) else { return nil }
        let delta = weight.weightLbs - prior.weightLbs
        let value = displayValue(lbs: delta)
        let sign = value >= 0 ? "+" : ""
        return String(format: "%@%.1f %@ vs prior", sign, value, unitLabel)
    }

    private var goalDisplayLbs: Double? { settings.goalWeightLbs }

    private var toGoText: String? {
        guard let goal = goalDisplayLbs, let weight else { return nil }
        let delta = weight.weightLbs - goal
        let value = displayValue(lbs: abs(delta))
        if abs(delta) < 0.05 {
            return "At goal"
        }
        if delta > 0 {
            return String(format: "%.1f %@ to go", value, unitLabel)
        }
        return String(format: "%.1f %@ under goal", value, unitLabel)
    }

    private var chartGoalValue: Double? {
        guard let goal = goalDisplayLbs else { return nil }
        return displayValue(lbs: goal)
    }

    var body: some View {
        SectionCard(
            title: "Weight & BMI",
            systemImage: "scalemass",
            isCollapsed: settings.sectionCollapsedBinding(.weight, context: modelContext),
            collapsedMessage: DaySectionID.weight.collapsedMessage
        ) {
            Text("BMI is calculated from today’s weight and your height in Settings.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            if !settings.hasHeight {
                Button {
                    onOpenSettings?()
                } label: {
                    Label("Set height to unlock BMI", systemImage: "ruler")
                }
                .buttonStyle(.bordered)
            } else {
                Text("Height: \(settings.heightDisplay)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Weight")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(displayWeight)
                        .font(.largeTitle.bold().monospacedDigit())
                    if let deltaText {
                        Text(deltaText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text("BMI")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if let bmi {
                        Text(String(format: "%.1f", bmi))
                            .font(.title.bold().monospacedDigit())
                        Text(BMICalculator.category(for: bmi))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("—")
                            .font(.title.bold())
                            .foregroundStyle(.tertiary)
                        Text(settings.hasHeight ? "Log weight" : "Need height")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            goalBlock

            if isEditingWeight {
                HStack {
                    TextField(settings.usesMetricWeight ? "Weight (kg)" : "Weight (lb)", text: $draftText)
                        .keyboardType(.decimalPad)
                        .textFieldStyle(.roundedBorder)
                        .focused($weightFocused)
                    Button("Save") {
                        commit()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(parsedDraft == nil)
                    Button("Cancel") {
                        isEditingWeight = false
                        weightFocused = false
                        Keyboard.dismiss()
                        draftText = ""
                    }
                    .buttonStyle(.bordered)
                }
            } else {
                Button {
                    syncDraftForEdit()
                    isEditingWeight = true
                    weightFocused = true
                } label: {
                    Label(weight == nil ? "Log weight" : "Update weight", systemImage: "pencil")
                }
                .buttonStyle(.bordered)
            }

            if !recentWeights.isEmpty {
                Text("Weight trend")
                    .font(.subheadline.weight(.semibold))
                Chart {
                    ForEach(recentWeights.reversed(), id: \.id) { entry in
                        LineMark(
                            x: .value("Date", entry.date),
                            y: .value("Weight", displayValue(lbs: entry.weightLbs))
                        )
                        PointMark(
                            x: .value("Date", entry.date),
                            y: .value("Weight", displayValue(lbs: entry.weightLbs))
                        )
                    }
                    if let chartGoalValue {
                        RuleMark(y: .value("Goal", chartGoalValue))
                            .foregroundStyle(.orange)
                            .lineStyle(StrokeStyle(dash: [4, 3]))
                            .annotation(position: .top, alignment: .trailing) {
                                Text("Goal")
                                    .font(.caption2)
                                    .foregroundStyle(.orange)
                            }
                    }
                }
                .frame(height: 140)
                .chartYAxisLabel(unitLabel)
            }
        }
        .keyboardDoneToolbar(focus: $weightFocused)
        .sheet(isPresented: $showGoalEditor) {
            GoalWeightConfigSheet(settings: settings)
        }
        .onAppear {
            // Keep input hidden unless user is actively editing.
            if weight != nil { isEditingWeight = false }
        }
        .onChange(of: weight?.weightLbs) { _, _ in
            if !isEditingWeight { draftText = "" }
        }
        .onChange(of: settings.usesMetricWeight) { _, _ in
            if isEditingWeight { syncDraftForEdit() }
        }
    }

    @ViewBuilder
    private var goalBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Goal weight")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if let goal = goalDisplayLbs {
                        Text(String(format: "%.1f %@", displayValue(lbs: goal), unitLabel))
                            .font(.title3.bold().monospacedDigit())
                        if let toGoText {
                            Text(toGoText)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else if weight == nil {
                            Text("Log today’s weight to see progress")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        Text("Not set")
                            .font(.title3.bold())
                            .foregroundStyle(.tertiary)
                    }
                }
                Spacer()
                Button(goalDisplayLbs == nil ? "Set goal" : "Edit goal") {
                    showGoalEditor = true
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(.vertical, 4)
    }

    private var parsedDraft: Double? {
        guard let value = Double(draftText.replacingOccurrences(of: ",", with: ".")), value > 0 else { return nil }
        return value
    }

    private func displayValue(lbs: Double) -> Double {
        settings.usesMetricWeight ? lbs * 0.453592 : lbs
    }

    private func syncDraftForEdit() {
        if let weight {
            draftText = String(format: "%.1f", displayValue(lbs: weight.weightLbs))
        } else {
            draftText = ""
        }
    }

    private func commit() {
        guard let value = parsedDraft else { return }
        weightFocused = false
        Keyboard.dismiss()
        let lbs = settings.usesMetricWeight ? value / 0.453592 : value
        onSave(lbs)
        draftText = ""
        isEditingWeight = false
    }
}

struct GoalWeightConfigSheet: View {
    @Bindable var settings: AppSettings
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var goalText = ""
    @FocusState private var goalFocused: Bool

    private var unitLabel: String { settings.usesMetricWeight ? "kg" : "lb" }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        TextField("Goal", text: $goalText)
                            .keyboardType(.decimalPad)
                            .focused($goalFocused)
                        Text(unitLabel)
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Target weight")
                } footer: {
                    Text("Shown on the Weight card and in Snapshot with a goal line on the trend chart.")
                }

                if settings.hasGoalWeight {
                    Section {
                        Button("Clear goal", role: .destructive) {
                            settings.goalWeightLbs = nil
                            try? modelContext.save()
                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle("Goal Weight")
            .navigationBarTitleDisplayMode(.inline)
            .keyboardDoneToolbar(focus: $goalFocused)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        Keyboard.dismiss()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        commit()
                    }
                    .disabled(parsedGoal == nil)
                }
            }
            .onAppear {
                if let goal = settings.goalWeightLbs {
                    let value = settings.usesMetricWeight ? goal * 0.453592 : goal
                    goalText = String(format: "%.1f", value)
                }
            }
        }
    }

    private var parsedGoal: Double? {
        guard let value = Double(goalText.replacingOccurrences(of: ",", with: ".")), value > 0 else { return nil }
        return value
    }

    private func commit() {
        guard let value = parsedGoal else { return }
        Keyboard.dismiss()
        settings.goalWeightLbs = settings.usesMetricWeight ? value / 0.453592 : value
        try? modelContext.save()
        dismiss()
    }
}
