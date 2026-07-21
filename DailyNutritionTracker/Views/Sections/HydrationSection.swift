import SwiftUI
import SwiftData

struct HydrationSection: View {
    @Bindable var log: DailyLog
    @Bindable var settings: AppSettings
    let date: Date
    var onOpenSettings: (() -> Void)? = nil
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var healthKit: HealthKitService

    @State private var showBottleMenu = false
    @State private var showConfig = false

    private var bottleOz: Double { max(settings.defaultBottleOz, 1) }

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

    private var targetSlotCount: Int {
        max(1, Int(ceil(Double(settings.hydrationTargetOz) / bottleOz)))
    }

    private var slots: [Double?] {
        var result = log.waterSlots
        while result.count < targetSlotCount { result.append(nil) }
        return result
    }

    var body: some View {
        SectionCard(
            title: "Hydration",
            systemImage: "drop.fill",
            isCollapsed: settings.sectionCollapsedBinding(.hydration, context: modelContext),
            collapsedMessage: DaySectionID.hydration.collapsedMessage,
            trailing: {
                Button {
                    showConfig = true
                } label: {
                    Image(systemName: "gearshape.fill")
                }
                .accessibilityLabel("Configure hydration goals")
            }
        ) {
            Text("\(log.waterOz) oz · target \(settings.hydrationTargetOz) oz")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Button {
                showBottleMenu = true
            } label: {
                HStack {
                    Text("Drink size")
                    Spacer()
                    Text(nextBottleLabel)
                        .foregroundStyle(.secondary)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)
            .confirmationDialog("Drink size", isPresented: $showBottleMenu, titleVisibility: .visible) {
                ForEach(bottleOptions, id: \.value) { option in
                    Button(option.label) {
                        settings.defaultBottleOz = option.value
                        try? modelContext.save()
                    }
                }
                Button("Cancel", role: .cancel) {}
            }

            Text("Tap a bottle to fill or undo. +\(nextBottleLabel) adds another bottle beyond the target grid.")
                .font(.caption2)
                .foregroundStyle(.secondary)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 8) {
                ForEach(Array(slots.enumerated()), id: \.offset) { index, value in
                    let filled = value != nil
                    GlassButton(
                        isFilled: filled,
                        label: filled ? formatOz(value!) : nextBottleLabel
                    ) {
                        if index < log.waterSlots.count || filled {
                            log.toggleWaterSlot(at: index, fillOz: bottleOz)
                        } else {
                            log.ensureWaterSlotCount(targetSlotCount)
                            log.toggleWaterSlot(at: index, fillOz: bottleOz)
                        }
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
                    log.appendFilledWaterSlot(oz: bottleOz)
                    persist()
                }
                .buttonStyle(.bordered)
            }
        }
        .sheet(isPresented: $showConfig) {
            HydrationConfigSheet(settings: settings, onOpenFullSettings: {
                showConfig = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    onOpenSettings?()
                }
            })
        }
        .onAppear {
            if log.waterSlots.count < targetSlotCount {
                log.ensureWaterSlotCount(targetSlotCount)
                try? modelContext.save()
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

struct HydrationConfigSheet: View {
    @Bindable var settings: AppSettings
    var onOpenFullSettings: (() -> Void)? = nil
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    private var bottleOptions: [(label: String, value: Double)] {
        [
            ("8 oz glass", 8),
            ("12 oz", 12),
            ("16.9 oz bottle", 16.9),
            ("20 oz", 20),
            ("24 oz", 24)
        ]
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Set your daily water target and default drink size. The bottle grid updates from these values.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("Daily goal") {
                    Stepper(
                        "\(settings.hydrationTargetOz) oz",
                        value: Binding(
                            get: { settings.hydrationTargetOz },
                            set: {
                                settings.hydrationTargetOz = $0
                                try? modelContext.save()
                            }
                        ),
                        in: 32...200,
                        step: 8
                    )
                }

                Section("Default drink size") {
                    Picker("Bottle", selection: Binding(
                        get: { settings.defaultBottleOz },
                        set: {
                            settings.defaultBottleOz = $0
                            try? modelContext.save()
                        }
                    )) {
                        ForEach(bottleOptions, id: \.value) { option in
                            Text(option.label).tag(option.value)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }

                if onOpenFullSettings != nil {
                    Section {
                        Button("Open full Settings…") {
                            onOpenFullSettings?()
                        }
                    }
                }
            }
            .navigationTitle("Hydration Goals")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
