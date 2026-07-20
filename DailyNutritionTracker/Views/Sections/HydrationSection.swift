import SwiftUI
import SwiftData

struct HydrationSection: View {
    @Bindable var log: DailyLog
    @Bindable var settings: AppSettings
    let date: Date
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var healthKit: HealthKitService

    private var bottleOz: Double { max(settings.defaultBottleOz, 1) }

    private var filledCount: Int {
        Int((Double(log.waterOz) / bottleOz).rounded(.down))
    }

    private var displayedBottles: Int {
        let targetBottles = Int(ceil(Double(settings.hydrationTargetOz) / bottleOz))
        let needed = max(filledCount + 1, targetBottles, 4)
        return min(max(needed, 4), 24)
    }

    private var bottleLabel: String {
        if abs(bottleOz.rounded() - bottleOz) < 0.05 {
            return "\(Int(bottleOz.rounded()))oz"
        }
        return String(format: "%.1foz", bottleOz)
    }

    var body: some View {
        SectionCard(title: "Hydration", systemImage: "drop.fill") {
            Text("\(log.waterOz) oz · target \(settings.hydrationTargetOz) oz · \(bottleLabel) bottles")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Picker("Bottle size", selection: Binding(
                get: { settings.defaultBottleOz },
                set: {
                    settings.defaultBottleOz = $0
                    try? modelContext.save()
                }
            )) {
                Text("8 oz glass").tag(8.0)
                Text("12 oz").tag(12.0)
                Text("16.9 oz bottle").tag(16.9)
                Text("20 oz").tag(20.0)
                Text("24 oz").tag(24.0)
            }
            .pickerStyle(.menu)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 8) {
                ForEach(0..<displayedBottles, id: \.self) { index in
                    GlassButton(index: index, filledCount: filledCount, label: bottleLabel) {
                        setFilled(index + 1)
                    }
                }
            }

            HStack {
                Button("Clear") {
                    log.waterOz = 0
                    persist()
                }
                Spacer()
                Button("+\(bottleLabel)") {
                    log.waterOz += Int(bottleOz.rounded())
                    persist()
                }
                .buttonStyle(.bordered)
                Stepper(
                    "Adjust",
                    value: Binding(
                        get: { log.waterOz },
                        set: { newValue in
                            log.waterOz = max(0, newValue)
                            persist()
                        }
                    ),
                    in: 0...400,
                    step: max(1, Int(bottleOz.rounded()))
                )
                .labelsHidden()
            }
        }
    }

    private func setFilled(_ count: Int) {
        if count == filledCount {
            log.waterOz = max(0, Int((Double(count - 1) * bottleOz).rounded()))
        } else {
            log.waterOz = Int((Double(count) * bottleOz).rounded())
        }
        persist()
    }

    private func persist() {
        try? modelContext.save()
        Task {
            await healthKit.writeWater(ounces: log.waterOz, on: date)
        }
    }
}
