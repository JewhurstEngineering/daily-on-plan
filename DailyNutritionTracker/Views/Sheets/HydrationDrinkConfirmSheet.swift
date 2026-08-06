import SwiftUI

struct HydrationDrinkConfirmSheet: View {
    let candidate: DrinkScanCandidate
    let defaultOz: Double
    var onConfirm: (Double, HydrationDrinkKind, HydrationOtherSubtype?) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var ounces: Double = 16.9
    @State private var ouncesText = "16.9"
    @State private var kind: HydrationDrinkKind = .water
    @State private var otherSubtype: HydrationOtherSubtype = .other
    @FocusState private var ouncesFocused: Bool

    private var previewRecord: WaterSlotRecord {
        WaterSlotRecord(
            oz: ounces,
            kind: kind,
            otherSubtype: kind == .other ? otherSubtype : nil
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 12) {
                        Image(systemName: previewRecord.resolvedSystemImage)
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)
                            .frame(width: 44)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(candidate.name)
                                .font(.headline)
                            if let brand = candidate.brand, !brand.isEmpty {
                                Text(brand)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Text(previewRecord.displayLabel)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section {
                    HStack {
                        Text("Ounces")
                        Spacer()
                        TextField("oz", text: $ouncesText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .focused($ouncesFocused)
                            .frame(maxWidth: 90)
                            .onChange(of: ouncesText) { _, newValue in
                                let filtered = newValue.filter { $0.isNumber || $0 == "." || $0 == "," }
                                if filtered != newValue { ouncesText = filtered }
                                if let value = Double(filtered.replacingOccurrences(of: ",", with: ".")), value > 0 {
                                    ounces = value
                                }
                            }
                        Text("oz")
                            .foregroundStyle(.secondary)
                    }
                    Stepper(
                        value: Binding(
                            get: { ounces },
                            set: {
                                ounces = max(1, ($0 * 10).rounded() / 10)
                                ouncesText = ounces == ounces.rounded()
                                    ? String(format: "%.0f", ounces)
                                    : String(format: "%.1f", ounces)
                            }
                        ),
                        in: 1...64,
                        step: 0.5
                    ) {
                        Text(String(format: ounces == ounces.rounded() ? "%.0f oz" : "%.1f oz", ounces))
                    }
                } header: {
                    Text("Size")
                }

                Section("Type") {
                    Picker("Kind", selection: $kind) {
                        ForEach(HydrationDrinkKind.allCases) { item in
                            Label(item.title, systemImage: WaterSlotRecord(oz: 1, kind: item, otherSubtype: .other).resolvedSystemImage)
                                .tag(item)
                        }
                    }
                    .pickerStyle(.segmented)

                    if kind == .other {
                        Picker("Subtype", selection: $otherSubtype) {
                            ForEach(HydrationOtherSubtype.allCases) { subtype in
                                Label(
                                    subtype.title,
                                    systemImage: WaterSlotRecord(oz: 1, kind: .other, otherSubtype: subtype).resolvedSystemImage
                                )
                                .tag(subtype)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Confirm drink")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        ouncesFocused = false
                        if let typed = Double(ouncesText.replacingOccurrences(of: ",", with: ".")), typed > 0 {
                            ounces = typed
                        }
                        onConfirm(
                            max(ounces, 1),
                            kind,
                            kind == .other ? otherSubtype : nil
                        )
                        dismiss()
                    }
                    .disabled(ounces <= 0)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { ouncesFocused = false }
                }
            }
            .onAppear {
                kind = candidate.kind
                otherSubtype = candidate.otherSubtype ?? .other
                let oz = candidate.suggestedOz ?? defaultOz
                ounces = max(oz, 1)
                ouncesText = ounces == ounces.rounded()
                    ? String(format: "%.0f", ounces)
                    : String(format: "%.1f", ounces)
            }
        }
    }
}
