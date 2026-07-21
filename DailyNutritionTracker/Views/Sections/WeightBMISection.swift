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
    @FocusState private var weightFocused: Bool

    private var displayWeight: String {
        guard let weight else { return "—" }
        if settings.usesMetricWeight {
            return String(format: "%.1f kg", weight.weightLbs * 0.453592)
        }
        return String(format: "%.1f lb", weight.weightLbs)
    }

    private var bmi: Double? {
        guard let weight else { return nil }
        return BMICalculator.bmi(weightLbs: weight.weightLbs, heightInches: settings.heightInches)
    }

    private var deltaText: String? {
        guard let weight,
              let prior = recentWeights.first(where: { $0.date < weight.date }) else { return nil }
        let delta = weight.weightLbs - prior.weightLbs
        let unit = settings.usesMetricWeight ? "kg" : "lb"
        let value = settings.usesMetricWeight ? delta * 0.453592 : delta
        let sign = value >= 0 ? "+" : ""
        return String(format: "%@%.1f %@", sign, value, unit)
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
                        Text(deltaText + " vs prior")
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
            }

            if !recentWeights.isEmpty {
                Text("Weight trend")
                    .font(.subheadline.weight(.semibold))
                Chart(recentWeights.reversed(), id: \.id) { entry in
                    LineMark(
                        x: .value("Date", entry.date),
                        y: .value("Weight", settings.usesMetricWeight ? entry.weightLbs * 0.453592 : entry.weightLbs)
                    )
                    PointMark(
                        x: .value("Date", entry.date),
                        y: .value("Weight", settings.usesMetricWeight ? entry.weightLbs * 0.453592 : entry.weightLbs)
                    )
                }
                .frame(height: 140)
                .chartYAxisLabel(settings.usesMetricWeight ? "kg" : "lb")
            }
        }
        .keyboardDoneToolbar(focus: $weightFocused)
        .onAppear { syncDraft() }
        .onChange(of: weight?.weightLbs) { _, _ in
            if !weightFocused { syncDraft() }
        }
        .onChange(of: settings.usesMetricWeight) { _, _ in syncDraft() }
    }

    private var parsedDraft: Double? {
        guard let value = Double(draftText.replacingOccurrences(of: ",", with: ".")), value > 0 else { return nil }
        return value
    }

    private func syncDraft() {
        if let weight {
            draftText = settings.usesMetricWeight
                ? String(format: "%.1f", weight.weightLbs * 0.453592)
                : String(format: "%.1f", weight.weightLbs)
        }
    }

    private func commit() {
        guard let value = parsedDraft else { return }
        weightFocused = false
        Keyboard.dismiss()
        let lbs = settings.usesMetricWeight ? value / 0.453592 : value
        onSave(lbs)
        // Keep the typed value visible; sync from saved entry next appear/change.
        draftText = settings.usesMetricWeight
            ? String(format: "%.1f", value)
            : String(format: "%.1f", value)
    }
}
