import SwiftUI
import OnPlanCore

struct PhoneWatchSettings: View {
    @EnvironmentObject private var store: OnPlanStore

    var body: some View {
        Form {
            Section {
                ForEach(0..<WatchQuickAdd.slotCount, id: \.self) { index in
                    Picker("Button \(index + 1)", selection: slotBinding(index)) {
                        ForEach(WatchQuickAdd.Action.allCases) { action in
                            Label(action.title, systemImage: action.systemImage)
                                .tag(action)
                        }
                    }
                }
            } header: {
                Text("Quick-add buttons")
            } footer: {
                Text("These three actions appear on the Watch Quick Add page. Water and electrolytes open a size list.")
            }

            Section {
                ForEach(WatchQuickAdd.sizePresets, id: \.self) { oz in
                    Toggle(sizeLabel(oz), isOn: sizeBinding(oz))
                }
            } header: {
                Text("Hydration sizes")
            } footer: {
                Text("Shown after you tap Water or Electrolytes on the Watch. Keep at least one size on.")
            }
        }
        .navigationTitle("Apple Watch")
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear {
            PhoneWatchBridge.shared.pushSnapshot()
        }
    }

    private func slotBinding(_ index: Int) -> Binding<WatchQuickAdd.Action> {
        Binding(
            get: {
                let slots = store.preferences.watchQuickAdd.resolvedSlots
                return index < slots.count ? slots[index] : .water
            },
            set: { newValue in
                store.updatePreferences { prefs in
                    var slots = prefs.watchQuickAdd.resolvedSlots
                    while slots.count <= index { slots.append(.water) }
                    slots[index] = newValue
                    prefs.watchQuickAdd.slots = slots
                }
                PhoneWatchBridge.shared.pushSnapshot()
            }
        )
    }

    private func sizeBinding(_ oz: Double) -> Binding<Bool> {
        Binding(
            get: { store.preferences.watchQuickAdd.hydrationSizesOz.contains(oz) },
            set: { isOn in
                store.updatePreferences { prefs in
                    var sizes = prefs.watchQuickAdd.hydrationSizesOz
                    if isOn {
                        if !sizes.contains(oz) { sizes.append(oz) }
                    } else if sizes.count > 1 {
                        sizes.removeAll { $0 == oz }
                    }
                    prefs.watchQuickAdd.hydrationSizesOz = sizes.sorted()
                }
                PhoneWatchBridge.shared.pushSnapshot()
            }
        )
    }

    private func sizeLabel(_ oz: Double) -> String {
        if oz == oz.rounded() { return "\(Int(oz)) oz" }
        return String(format: "%.1f oz", oz)
    }
}
