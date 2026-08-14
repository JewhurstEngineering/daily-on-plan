import SwiftUI
import SwiftData
import Charts
import OnPlanCore

struct MacBodySettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var allSettings: [AppSettings]
    @Query(sort: \WeightEntry.date) private var allWeights: [WeightEntry]
    @State private var heightFeet = 5
    @State private var heightInchesPart = 8
    @State private var goalWeightText = ""
    @State private var todayWeightText = ""
    @FocusState private var goalWeightFocused: Bool
    @FocusState private var todayWeightFocused: Bool

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
                title: "Body",
                systemImage: "figure.stand",
                subtitle: "Height drives BMI. Today’s weight is the journal, not a chrome pref."
            ) {
                Toggle("Use kilograms", isOn: Binding(
                    get: { settings.usesMetricWeight },
                    set: {
                        settings.usesMetricWeight = $0
                        save()
                    }
                ))
                .toggleStyle(.checkbox)

                HStack {
                    Text("Height")
                        .appFont(.subheadline)
                    Spacer()
                    Picker("Feet", selection: $heightFeet) {
                        ForEach(4...7, id: \.self) { Text("\($0) ft").tag($0) }
                    }
                    .labelsHidden()
                    .frame(width: 72)
                    Picker("Inches", selection: $heightInchesPart) {
                        ForEach(0...11, id: \.self) { Text("\($0) in").tag($0) }
                    }
                    .labelsHidden()
                    .frame(width: 72)
                }

                Stepper(
                    settings.hasAge ? "Age: \(settings.ageYears)" : "Age: not set",
                    value: Binding(
                        get: { settings.ageYears > 0 ? settings.ageYears : 30 },
                        set: {
                            settings.ageYears = $0
                            save()
                        }
                    ),
                    in: 10...120
                )

                labeledField("Today", text: $todayWeightText, unit: settings, focus: $todayWeightFocused)
                if let bmiLine = todayBMILine(settings) {
                    Text(bmiLine)
                        .appFont(.subheadline, weight: .semibold)
                } else if settings.hasHeight {
                    Text("Enter today’s weight to see BMI.")
                        .appFont(.caption2)
                        .foregroundStyle(.secondary)
                }

                labeledField("Goal", text: $goalWeightText, unit: settings, focus: $goalWeightFocused)
                if settings.hasGoalWeight {
                    Button("Clear goal", role: .destructive) {
                        settings.goalWeightLbs = nil
                        goalWeightText = ""
                        save()
                    }
                    .controlSize(.small)
                }

                if !allWeights.isEmpty {
                    macWeightTrend(settings)
                }
                if bmiChartRows(settings).count >= 2 {
                    macBMITrend(settings)
                }
            }
        }
        .onAppear { load(settings) }
        .onChange(of: heightFeet) { _, _ in persistHeight(settings) }
        .onChange(of: heightInchesPart) { _, _ in persistHeight(settings) }
        .onChange(of: goalWeightFocused) { _, focused in
            if !focused { commitGoalWeight(settings) }
        }
        .onChange(of: todayWeightFocused) { _, focused in
            if !focused { commitTodayWeight(settings) }
        }
        .onChange(of: settings.usesMetricWeight) { _, _ in
            loadTodayWeight(settings)
            loadGoalWeight(settings)
        }
    }

    private func displayWeight(_ lbs: Double, settings: AppSettings) -> Double {
        settings.usesMetricWeight ? lbs * 0.453592 : lbs
    }

    private func bmiChartRows(_ settings: AppSettings) -> [(date: Date, value: Double)] {
        guard settings.hasHeight else { return [] }
        return allWeights.compactMap { entry in
            guard let bmi = BMICalculator.bmi(weightLbs: entry.weightLbs, heightInches: settings.heightInches) else {
                return nil
            }
            return (entry.date, bmi)
        }
    }

    private func macWeightTrend(_ settings: AppSettings) -> some View {
        let values = allWeights.map { displayWeight($0.weightLbs, settings: settings) }
        let goal = settings.goalWeightLbs.map { displayWeight($0, settings: settings) }
        return VStack(alignment: .leading, spacing: 6) {
            Text("Weight trend")
                .appFont(.caption, weight: .semibold)
                .foregroundStyle(.secondary)
            Chart {
                ForEach(allWeights) { entry in
                    LineMark(
                        x: .value("Date", entry.date),
                        y: .value("Weight", displayWeight(entry.weightLbs, settings: settings))
                    )
                    PointMark(
                        x: .value("Date", entry.date),
                        y: .value("Weight", displayWeight(entry.weightLbs, settings: settings))
                    )
                }
                if let goal {
                    RuleMark(y: .value("Goal", goal))
                        .foregroundStyle(.orange)
                        .lineStyle(StrokeStyle(dash: [4, 3]))
                }
            }
            .frame(height: 140)
            .chartYAxisLabel(settings.usesMetricWeight ? "kg" : "lb")
            .chartPaddedYScale(
                values: values,
                goal: goal,
                pad: ChartValueScale.weightPad(usesMetric: settings.usesMetricWeight)
            )
        }
    }

    private func macBMITrend(_ settings: AppSettings) -> some View {
        let rows = bmiChartRows(settings)
        let goal = settings.goalWeightLbs.flatMap {
            BMICalculator.bmi(weightLbs: $0, heightInches: settings.heightInches)
        }
        return VStack(alignment: .leading, spacing: 6) {
            Text("BMI trend")
                .appFont(.caption, weight: .semibold)
                .foregroundStyle(.secondary)
            Chart {
                ForEach(rows, id: \.date) { row in
                    LineMark(
                        x: .value("Date", row.date),
                        y: .value("BMI", row.value)
                    )
                    PointMark(
                        x: .value("Date", row.date),
                        y: .value("BMI", row.value)
                    )
                }
                if let goal {
                    RuleMark(y: .value("Goal BMI", goal))
                        .foregroundStyle(.orange)
                        .lineStyle(StrokeStyle(dash: [4, 3]))
                }
            }
            .frame(height: 140)
            .chartPaddedYScale(
                values: rows.map(\.value),
                goal: goal,
                pad: ChartValueScale.bmiPad(heightInches: settings.heightInches)
            )
        }
    }

    private func labeledField(
        _ title: String,
        text: Binding<String>,
        unit settings: AppSettings,
        focus: FocusState<Bool>.Binding
    ) -> some View {
        HStack {
            Text(title)
                .appFont(.subheadline)
            TextField(title, text: text)
                .textFieldStyle(.roundedBorder)
                .focused(focus)
                .onChange(of: text.wrappedValue) { _, newValue in
                    let filtered = newValue.filter { $0.isNumber || $0 == "." || $0 == "," }
                    if filtered != newValue { text.wrappedValue = filtered }
                }
            Text(settings.usesMetricWeight ? "kg" : "lb")
                .foregroundStyle(.secondary)
                .frame(width: 24, alignment: .leading)
        }
    }

    private func load(_ settings: AppSettings) {
        loadGoalWeight(settings)
        loadTodayWeight(settings)
        let total = Int(settings.heightInches)
        if total > 0 {
            heightFeet = total / 12
            heightInchesPart = total % 12
        }
    }

    private func loadGoalWeight(_ settings: AppSettings) {
        if let goal = settings.goalWeightLbs {
            let value = settings.usesMetricWeight ? goal * 0.453592 : goal
            goalWeightText = String(format: "%.1f", value)
        } else {
            goalWeightText = ""
        }
    }

    private func loadTodayWeight(_ settings: AppSettings) {
        guard let weight = DataStore.weight(for: Date(), in: modelContext) else {
            todayWeightText = ""
            return
        }
        let value = settings.usesMetricWeight ? weight.weightLbs * 0.453592 : weight.weightLbs
        todayWeightText = String(format: "%.1f", value)
    }

    private func persistHeight(_ settings: AppSettings) {
        settings.heightInches = Double(heightFeet * 12 + heightInchesPart)
        save()
    }

    private func commitTodayWeight(_ settings: AppSettings) {
        let cleaned = todayWeightText.replacingOccurrences(of: ",", with: ".").trimmingCharacters(in: .whitespaces)
        if cleaned.isEmpty { return }
        guard let value = Double(cleaned), value > 0 else {
            loadTodayWeight(settings)
            return
        }
        let lbs = settings.usesMetricWeight ? value / 0.453592 : value
        if let existing = DataStore.weight(for: Date(), in: modelContext) {
            existing.weightLbs = lbs
            existing.timeLogged = Date()
        } else {
            modelContext.insert(WeightEntry(date: Date(), weightLbs: lbs))
        }
        todayWeightText = String(format: "%.1f", value)
        save()
    }

    private func commitGoalWeight(_ settings: AppSettings) {
        let cleaned = goalWeightText.replacingOccurrences(of: ",", with: ".").trimmingCharacters(in: .whitespaces)
        if cleaned.isEmpty { return }
        guard let value = Double(cleaned), value > 0 else {
            loadGoalWeight(settings)
            return
        }
        settings.goalWeightLbs = settings.usesMetricWeight ? value / 0.453592 : value
        goalWeightText = String(format: "%.1f", value)
        save()
    }

    private func todayBMILine(_ settings: AppSettings) -> String? {
        guard let weight = DataStore.weight(for: Date(), in: modelContext),
              let bmi = BMICalculator.bmi(weightLbs: weight.weightLbs, heightInches: settings.heightInches)
        else { return nil }
        return String(format: "Today’s BMI: %.1f · %@", bmi, BMICalculator.category(for: bmi))
    }

    private func save() {
        modelContext.saveAndNotifyJournal()
    }
}
