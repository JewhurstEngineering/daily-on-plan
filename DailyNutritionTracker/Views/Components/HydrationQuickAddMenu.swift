import SwiftUI

/// The fill menu shown by long-pressing an empty bottle on the Hydration page, and by
/// long-pressing the hydration button on Today. Defined once so the two can never offer
/// different options.
struct HydrationQuickAddMenu: View {
    /// Bottle sizes offered under each drink kind.
    static let bottleOptions: [(label: String, value: Double)] = [
        ("8 oz glass", 8),
        ("12 oz", 12),
        ("16.9 oz bottle", 16.9),
        ("20 oz", 20),
        ("24 oz", 24)
    ]

    let onFill: (Double, HydrationDrinkKind, HydrationOtherSubtype?) -> Void
    /// Omitted where there is no scanner to reach (the menu simply drops the item).
    var onScan: (() -> Void)?

    var body: some View {
        Menu {
            ForEach(Self.bottleOptions, id: \.value) { option in
                Button(option.label) { onFill(option.value, .water, nil) }
            }
        } label: {
            Label("Fill as water", systemImage: "waterbottle.fill")
        }

        Menu {
            ForEach(Self.bottleOptions, id: \.value) { option in
                Button(option.label) { onFill(option.value, .electrolyte, nil) }
            }
        } label: {
            Label("Fill as electrolyte", systemImage: "bolt.fill")
        }

        Menu {
            ForEach(HydrationOtherSubtype.allCases) { subtype in
                Menu {
                    ForEach(Self.bottleOptions, id: \.value) { option in
                        Button(option.label) { onFill(option.value, .other, subtype) }
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

        if let onScan {
            Button(action: onScan) {
                Label("Scan barcode", systemImage: "barcode.viewfinder")
            }
        }
    }
}
