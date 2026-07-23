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

    private var slots: [WaterSlotRecord?] {
        var result = log.waterSlots
        while result.count < targetSlotCount { result.append(nil) }
        return result
    }

    private var totalOz: Int { log.totalHydrationOz(settings: settings) }
    private var proteinOz: Int { log.proteinHydrationOz(settings: settings) }

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
            Text("\(totalOz) oz · target \(settings.hydrationTargetOz) oz")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HydrationProgressBar(
                current: totalOz,
                goal: settings.hydrationTargetOz,
                electrolyteSegments: HydrationRingSegments.electrolyteSegments(
                    slots: log.waterSlots,
                    goalOz: settings.hydrationTargetOz
                )
            )

            if proteinOz > 0 {
                Text("Includes \(proteinOz) oz from protein drinks")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 6) {
                Image(systemName: log.hasElectrolyteDrink ? "bolt.fill" : "bolt")
                    .foregroundStyle(log.hasElectrolyteDrink ? Color.orange : Color.secondary)
                Text(log.hasElectrolyteDrink
                     ? "Electrolyte logged (\(log.electrolyteDrinkCount))"
                     : "Long-press a bottle for type + size")
                    .font(.caption)
                    .foregroundStyle(log.hasElectrolyteDrink ? .primary : .secondary)
            }

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

            Text("Tap to fill or undo. Long-press for water/electrolyte and size. +\(nextBottleLabel) adds another bottle beyond the target grid.")
                .font(.caption2)
                .foregroundStyle(.secondary)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 8) {
                ForEach(Array(slots.enumerated()), id: \.offset) { index, value in
                    let filled = value != nil
                    let electrolyte = value?.isElectrolyte == true
                    GlassButton(
                        isFilled: filled,
                        isElectrolyte: electrolyte,
                        label: filled ? formatOz(value!.oz) : nextBottleLabel
                    ) {
                        if index < log.waterSlots.count || filled {
                            log.toggleWaterSlot(at: index, fillOz: bottleOz)
                        } else {
                            log.ensureWaterSlotCount(targetSlotCount)
                            log.toggleWaterSlot(at: index, fillOz: bottleOz)
                        }
                        persist()
                    }
                    .contextMenu {
                        if filled {
                            Button {
                                log.setWaterSlotElectrolyte(at: index, isElectrolyte: !electrolyte)
                                persist()
                            } label: {
                                Label(
                                    electrolyte ? "Mark as plain water" : "Mark as electrolyte",
                                    systemImage: electrolyte ? "waterbottle" : "bolt.fill"
                                )
                            }
                            Button("Clear", role: .destructive) {
                                log.toggleWaterSlot(at: index, fillOz: bottleOz)
                                persist()
                            }
                        } else {
                            Menu {
                                ForEach(bottleOptions, id: \.value) { option in
                                    Button(option.label) {
                                        ensureAndFill(index: index, oz: option.value, electrolyte: false)
                                    }
                                }
                            } label: {
                                Label("Fill as water", systemImage: "waterbottle.fill")
                            }
                            Menu {
                                ForEach(bottleOptions, id: \.value) { option in
                                    Button(option.label) {
                                        ensureAndFill(index: index, oz: option.value, electrolyte: true)
                                    }
                                }
                            } label: {
                                Label("Fill as electrolyte", systemImage: "bolt.fill")
                            }
                        }
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

    private func ensureAndFill(index: Int, oz: Double, electrolyte: Bool) {
        if index >= log.waterSlots.count {
            log.ensureWaterSlotCount(targetSlotCount)
        }
        log.setWaterSlot(at: index, oz: oz, isElectrolyte: electrolyte)
        persist()
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
            await healthKit.writeWater(ounces: log.totalHydrationOz(settings: settings), on: date)
        }
    }
}

struct HydrationConfigSheet: View {
    @Bindable var settings: AppSettings
    var onOpenFullSettings: (() -> Void)? = nil
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @FocusState private var targetFocused: Bool
    @State private var targetText = ""

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
                    Text("Set your daily water target and default drink size. The bottle grid size comes from the target; drink size is only how big each tap is.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section {
                    HStack {
                        TextField("Target", text: $targetText)
                            .keyboardType(.numberPad)
                            .focused($targetFocused)
                            .onChange(of: targetText) { _, newValue in
                                let digits = newValue.filter(\.isNumber)
                                if digits != newValue { targetText = digits }
                            }
                        Text("oz")
                            .foregroundStyle(.secondary)
                    }
                    Stepper(
                        "\(settings.hydrationTargetOz) oz",
                        value: Binding(
                            get: { settings.hydrationTargetOz },
                            set: {
                                settings.hydrationTargetOz = $0
                                targetText = "\($0)"
                                try? modelContext.save()
                            }
                        ),
                        in: 16...400,
                        step: 1
                    )
                } header: {
                    Text("Daily goal")
                } footer: {
                    Text("Type any number like 180. Not locked to bottle-size multiples. Long-press bottles on the day view to mark electrolytes.")
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

                Section {
                    Toggle("Protein drinks count toward hydration", isOn: Binding(
                        get: { settings.proteinDrinksCountTowardHydration },
                        set: {
                            settings.proteinDrinksCountTowardHydration = $0
                            try? modelContext.save()
                        }
                    ))
                    if settings.proteinDrinksCountTowardHydration {
                        Stepper(
                            "Default shake size: \(Int(settings.defaultShakeHydrationOz)) oz",
                            value: Binding(
                                get: { Int(settings.defaultShakeHydrationOz) },
                                set: {
                                    settings.defaultShakeHydrationOz = Double($0)
                                    try? modelContext.save()
                                }
                            ),
                            in: 4...32,
                            step: 1
                        )
                    }
                } header: {
                    Text("Protein drinks")
                } footer: {
                    Text("When on, protein shakes and ready-to-drink items add fluid ounces to today’s hydration total (in addition to protein calories).")
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
            .keyboardDoneToolbar(focus: $targetFocused)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        commitTarget()
                        Keyboard.dismiss()
                        dismiss()
                    }
                }
            }
            .onAppear {
                targetText = "\(settings.hydrationTargetOz)"
            }
            .onChange(of: targetFocused) { _, focused in
                if !focused { commitTarget() }
            }
        }
    }

    private func commitTarget() {
        if let value = Int(targetText.filter(\.isNumber)) {
            settings.hydrationTargetOz = min(max(value, 16), 400)
            targetText = "\(settings.hydrationTargetOz)"
            try? modelContext.save()
        }
    }
}
