import SwiftUI
import SwiftData

struct HydrationSection: View {
    @Bindable var log: DailyLog
    @Bindable var settings: AppSettings
    let date: Date
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var healthKit: HealthKitService

    @State private var showBottleMenu = false

    private var bottleOz: Double { max(settings.defaultBottleOz, 1) }
    private var drinks: [Double] { log.waterDrinks }

    private var bottleOptions: [(label: String, value: Double)] {
        [
            ("8 oz glass", 8),
            ("12 oz", 12),
            ("16.9 oz bottle", 16.9),
            ("20 oz", 20),
            ("24 oz", 24)
        ]
    }

    private var nextBottleLabel: String { formatOz(bottleOz) }

    private var displayedSlotCount: Int {
        let targetSlots = max(4, Int(ceil(Double(settings.hydrationTargetOz) / bottleOz)))
        return min(max(drinks.count + 1, targetSlots), 24)
    }

    var body: some View {
        SectionCard(title: "Hydration", systemImage: "drop.fill") {
            Text("\(log.waterOz) oz · target \(settings.hydrationTargetOz) oz")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            // confirmationDialog avoids Menu/Picker scroll-jump inside ScrollView
            Button {
                showBottleMenu = true
            } label: {
                HStack {
                    Text("Next drink size")
                    Spacer()
                    Text(nextBottleLabel)
                        .foregroundStyle(.secondary)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)
            .confirmationDialog("Next drink size", isPresented: $showBottleMenu, titleVisibility: .visible) {
                ForEach(bottleOptions, id: \.value) { option in
                    Button(option.label) {
                        settings.defaultBottleOz = option.value
                        try? modelContext.save()
                    }
                }
                Button("Cancel", role: .cancel) {}
            }

            Text("Already logged drinks keep their size. Changing size only affects the next drink.")
                .font(.caption2)
                .foregroundStyle(.secondary)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 8) {
                ForEach(Array(drinks.enumerated()), id: \.offset) { index, oz in
                    GlassButton(isFilled: true, label: formatOz(oz)) {
                        log.removeWaterDrink(at: index)
                        persist()
                    }
                }
                ForEach(drinks.count..<displayedSlotCount, id: \.self) { _ in
                    GlassButton(isFilled: false, label: nextBottleLabel) {
                        log.addWaterDrink(oz: bottleOz)
                        persist()
                    }
                }
            }

            HStack {
                Button("Clear") {
                    log.clearWaterDrinks()
                    persist()
                }
                Spacer()
                Button("+\(nextBottleLabel)") {
                    log.addWaterDrink(oz: bottleOz)
                    persist()
                }
                .buttonStyle(.bordered)
            }
        }
    }

    private func formatOz(_ oz: Double) -> String {
        if abs(oz.rounded() - oz) < 0.05 {
            return "\(Int(oz.rounded()))oz"
        }
        return String(format: "%.1foz", oz)
    }

    private func persist() {
        try? modelContext.save()
        Task {
            await healthKit.writeWater(ounces: log.waterOz, on: date)
        }
    }
}
