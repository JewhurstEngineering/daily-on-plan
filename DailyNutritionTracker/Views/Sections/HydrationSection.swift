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
    @State private var showBarcodeScanner = false
    @State private var isLookingUpBarcode = false
    @State private var barcodeError: String?
    @State private var confirmCandidate: DrinkScanCandidate?
    @State private var scanTargetIndex: Int?

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

    private var typeSummary: String {
        let filled = log.waterSlots.compactMap { $0 }
        guard !filled.isEmpty else { return "Long-press a bottle for type + size, or scan a drink" }
        var counts: [String: Int] = [:]
        var order: [String] = []
        for slot in filled {
            let key = slot.displayLabel
            if counts[key] == nil { order.append(key) }
            counts[key, default: 0] += 1
        }
        return order.map { "\($0) ×\(counts[$0] ?? 0)" }.joined(separator: " · ")
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
                Image(systemName: log.hasElectrolyteDrink ? "bolt.fill" : "drop.fill")
                    .foregroundStyle(log.hasElectrolyteDrink ? Color.orange : Color.secondary)
                Text(typeSummary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 10) {
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

                Button {
                    scanTargetIndex = nil
                    showBarcodeScanner = true
                } label: {
                    Label("Scan", systemImage: "barcode.viewfinder")
                }
                .buttonStyle(.bordered)
            }
            .confirmationDialog("Drink size", isPresented: $showBottleMenu, titleVisibility: .visible) {
                ForEach(bottleOptions, id: \.value) { option in
                    Button(option.label) {
                        settings.defaultBottleOz = option.value
                        try? modelContext.save()
                    }
                }
                Button("Cancel", role: .cancel) {}
            }

            Text("Tap to fill or undo. Long-press for water / electrolyte / other and size. Scan a package to confirm oz + type.")
                .font(.caption2)
                .foregroundStyle(.secondary)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 8) {
                ForEach(Array(slots.enumerated()), id: \.offset) { index, value in
                    let filled = value != nil
                    GlassButton(
                        isFilled: filled,
                        drinkKind: value?.kind ?? .water,
                        otherSubtype: value?.otherSubtype,
                        isElectrolyte: value?.isElectrolyte == true,
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
                            filledContextMenu(index: index, record: value!)
                        } else {
                            emptyContextMenu(index: index)
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
        .sheet(isPresented: $showBarcodeScanner) {
            BarcodeScannerSheet { code in
                Task { await lookupBarcode(code) }
            }
        }
        .sheet(item: $confirmCandidate) { candidate in
            HydrationDrinkConfirmSheet(candidate: candidate, defaultOz: bottleOz) { oz, kind, subtype in
                applyScannedDrink(oz: oz, kind: kind, otherSubtype: subtype)
            }
        }
        .alert("Lookup", isPresented: Binding(
            get: { barcodeError != nil },
            set: { if !$0 { barcodeError = nil } }
        )) {
            Button("OK", role: .cancel) { barcodeError = nil }
        } message: {
            Text(barcodeError ?? "")
        }
        .overlay {
            if isLookingUpBarcode {
                ZStack {
                    Color.black.opacity(0.2).ignoresSafeArea()
                    ProgressView("Looking up…")
                        .padding(20)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
            }
        }
        .onAppear {
            if log.waterSlots.count < targetSlotCount {
                log.ensureWaterSlotCount(targetSlotCount)
                try? modelContext.save()
            }
        }
    }

    @ViewBuilder
    private func emptyContextMenu(index: Int) -> some View {
        Menu {
            ForEach(bottleOptions, id: \.value) { option in
                Button(option.label) {
                    ensureAndFill(index: index, oz: option.value, kind: .water)
                }
            }
        } label: {
            Label("Fill as water", systemImage: "waterbottle.fill")
        }
        Menu {
            ForEach(bottleOptions, id: \.value) { option in
                Button(option.label) {
                    ensureAndFill(index: index, oz: option.value, kind: .electrolyte)
                }
            }
        } label: {
            Label("Fill as electrolyte", systemImage: "bolt.fill")
        }
        Menu {
            ForEach(HydrationOtherSubtype.allCases) { subtype in
                Menu {
                    ForEach(bottleOptions, id: \.value) { option in
                        Button(option.label) {
                            ensureAndFill(index: index, oz: option.value, kind: .other, otherSubtype: subtype)
                        }
                    }
                } label: {
                    Label(
                        subtype.title,
                        systemImage: WaterSlotRecord(oz: 1, kind: .other, otherSubtype: subtype).resolvedSystemImage
                    )
                }
            }
        } label: {
            Label("Fill as other", systemImage: "drop.fill")
        }
        Button {
            scanTargetIndex = index
            showBarcodeScanner = true
        } label: {
            Label("Scan barcode", systemImage: "barcode.viewfinder")
        }
    }

    @ViewBuilder
    private func filledContextMenu(index: Int, record: WaterSlotRecord) -> some View {
        Button {
            log.setWaterSlotKind(at: index, kind: .water)
            persist()
        } label: {
            Label("Mark as water", systemImage: "waterbottle.fill")
        }
        Button {
            log.setWaterSlotKind(at: index, kind: .electrolyte)
            persist()
        } label: {
            Label("Mark as electrolyte", systemImage: "bolt.fill")
        }
        Menu {
            ForEach(HydrationOtherSubtype.allCases) { subtype in
                Button {
                    log.setWaterSlotKind(at: index, kind: .other, otherSubtype: subtype)
                    persist()
                } label: {
                    Label(
                        subtype.title,
                        systemImage: WaterSlotRecord(oz: 1, kind: .other, otherSubtype: subtype).resolvedSystemImage
                    )
                }
            }
        } label: {
            Label("Mark as other", systemImage: "drop.fill")
        }
        Button("Clear", role: .destructive) {
            log.toggleWaterSlot(at: index, fillOz: bottleOz)
            persist()
        }
    }

    private func ensureAndFill(
        index: Int,
        oz: Double,
        kind: HydrationDrinkKind,
        otherSubtype: HydrationOtherSubtype? = nil
    ) {
        if index >= log.waterSlots.count {
            log.ensureWaterSlotCount(targetSlotCount)
        }
        log.setWaterSlot(at: index, oz: oz, kind: kind, otherSubtype: otherSubtype)
        persist()
    }

    private func applyScannedDrink(oz: Double, kind: HydrationDrinkKind, otherSubtype: HydrationOtherSubtype?) {
        if let index = scanTargetIndex {
            ensureAndFill(index: index, oz: oz, kind: kind, otherSubtype: otherSubtype)
        } else {
            log.fillNextWaterSlot(
                oz: oz,
                ensuringMinimumSlots: targetSlotCount,
                kind: kind,
                otherSubtype: otherSubtype
            )
            persist()
        }
        scanTargetIndex = nil
    }

    private func lookupBarcode(_ code: String) async {
        await MainActor.run { isLookingUpBarcode = true }
        do {
            let candidate = try await OpenFoodFactsClient.drink(barcode: code)
            await MainActor.run {
                isLookingUpBarcode = false
                confirmCandidate = candidate
            }
        } catch {
            await MainActor.run {
                isLookingUpBarcode = false
                barcodeError = error.localizedDescription
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
        WidgetReloader.reloadAll()
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
                    Text("Type any number like 180. Long-press bottles to set water, electrolyte, or other (tea, soda…).")
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
                            in: 4...40,
                            step: 1
                        )
                    }
                } header: {
                    Text("Protein drinks")
                }

                if onOpenFullSettings != nil {
                    Section {
                        Button("Open full Hydration settings") {
                            onOpenFullSettings?()
                        }
                    }
                }
            }
            .navigationTitle("Hydration Goals")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        commitTarget()
                        dismiss()
                    }
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        targetFocused = false
                        commitTarget()
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
        if let value = Int(targetText), value > 0 {
            settings.hydrationTargetOz = min(400, max(16, value))
            targetText = "\(settings.hydrationTargetOz)"
            try? modelContext.save()
        }
    }
}
