import SwiftUI
import SwiftData
import Charts

struct WeightBMISection: View {
    let selectedDate: Date
    let weight: WeightEntry?
    let recentWeights: [WeightEntry]
    let settings: AppSettings
    let onSave: (Double) -> Void

    @State private var draftText = ""
    @State private var showTrend = false

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
        SectionCard(title: "Weight & BMI", systemImage: "scalemass") {
            if !settings.hasHeight {
                Text("Set your height in Settings to calculate BMI.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(displayWeight)
                        .font(.largeTitle.bold().monospacedDigit())
                    if let deltaText {
                        Text(deltaText + " vs prior")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                if let bmi {
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(String(format: "%.1f", bmi))
                            .font(.title.bold().monospacedDigit())
                        Text(BMICalculator.category(for: bmi))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            HStack {
                TextField(settings.usesMetricWeight ? "kg" : "lb", text: $draftText)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(.roundedBorder)
                Button("Save") {
                    commit()
                }
                .buttonStyle(.borderedProminent)
                .disabled(parsedDraft == nil)
            }

            if recentWeights.count > 1 {
                Button {
                    showTrend.toggle()
                } label: {
                    Label(showTrend ? "Hide trend" : "Show trend", systemImage: "chart.line.uptrend.xyaxis")
                }
                if showTrend {
                    Chart(recentWeights.reversed(), id: \.id) { entry in
                        LineMark(
                            x: .value("Date", entry.date),
                            y: .value("Weight", entry.weightLbs)
                        )
                        PointMark(
                            x: .value("Date", entry.date),
                            y: .value("Weight", entry.weightLbs)
                        )
                    }
                    .frame(height: 120)
                }
            }
        }
        .onAppear {
            if let weight {
                draftText = settings.usesMetricWeight
                    ? String(format: "%.1f", weight.weightLbs * 0.453592)
                    : String(format: "%.1f", weight.weightLbs)
            }
        }
        .onChange(of: weight?.weightLbs) { _, _ in
            if let weight {
                draftText = settings.usesMetricWeight
                    ? String(format: "%.1f", weight.weightLbs * 0.453592)
                    : String(format: "%.1f", weight.weightLbs)
            }
        }
    }

    private var parsedDraft: Double? {
        guard let value = Double(draftText.replacingOccurrences(of: ",", with: ".")), value > 0 else { return nil }
        return value
    }

    private func commit() {
        guard let value = parsedDraft else { return }
        let lbs = settings.usesMetricWeight ? value / 0.453592 : value
        onSave(lbs)
    }
}
