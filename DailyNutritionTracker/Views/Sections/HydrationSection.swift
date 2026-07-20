import SwiftUI
import SwiftData

struct HydrationSection: View {
    @Bindable var log: DailyLog
    let date: Date
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var healthKit: HealthKitService

    private let glasses = 8
    private let ozPerGlass = 8

    private var filledCount: Int {
        min(max(log.waterOz / ozPerGlass, 0), glasses)
    }

    var body: some View {
        SectionCard(title: "Hydration", systemImage: "drop.fill") {
            Text("\(log.waterOz) oz · target \(glasses * ozPerGlass) oz")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 8) {
                ForEach(0..<glasses, id: \.self) { index in
                    GlassButton(index: index, filledCount: filledCount) {
                        setFilled(index + 1)
                    }
                }
            }

            HStack {
                Button("Clear") { setFilled(0) }
                Spacer()
                Stepper("Adjust oz", value: Binding(
                    get: { log.waterOz },
                    set: { newValue in
                        log.waterOz = max(0, newValue)
                        persist()
                    }
                ), in: 0...128, step: 8)
                .labelsHidden()
            }
        }
    }

    private func setFilled(_ count: Int) {
        // Tap glass N fills 1 through N; tapping the last filled glass clears to N-1
        if count == filledCount {
            log.waterOz = max(0, (count - 1) * ozPerGlass)
        } else {
            log.waterOz = count * ozPerGlass
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
