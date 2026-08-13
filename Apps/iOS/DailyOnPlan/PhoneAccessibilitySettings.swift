import OnPlanCore
import SwiftUI

struct PhoneAccessibilitySettings: View {
    @EnvironmentObject private var store: OnPlanStore
    @Environment(\.appTheme) private var theme

    var body: some View {
        Form {
            Section {
                Picker("Text size", selection: textSizeBinding) {
                    ForEach(DisplayPreferences.InterfaceSize.allCases) { size in
                        Text(size.title).tag(size)
                    }
                }
                .pickerStyle(.segmented)
            } header: {
                Text("Text size")
            } footer: {
                Text("Makes labels larger. Does not zoom the layout.")
            }

            Section("Color vision") {
                ForEach(DisplayPreferences.ColorVision.allCases) { option in
                    Button {
                        store.updatePreferences { prefs in
                            prefs.colorVision = option
                            if option != .typical {
                                prefs.distinguishWithoutColor = true
                            }
                        }
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(option.title)
                                    .foregroundStyle(.primary)
                                Text(option.subtitle)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if store.preferences.colorVision == option {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(Color.accentColor)
                            }
                        }
                    }
                }
            }

            Section {
                Toggle("Patterns on progress bars", isOn: patternsBinding)
                Toggle("High contrast borders", isOn: contrastBinding)
                previewBar("Protein", 24)
                previewBar("Water", 62)
                previewBar("Plan", 91)
            } header: {
                Text("Don’t rely on color alone")
            }
        }
        .navigationTitle("Accessibility")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func previewBar(_ title: String, _ percent: Double) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .font(.caption.weight(.semibold))
                Spacer()
                Text("\(Int(percent))%")
                    .font(.caption.monospacedDigit().weight(.bold))
                    .foregroundStyle(theme.color(forPool: title, percent: percent))
            }
            UsageProgressBar(
                percent: percent,
                tint: theme.color(forPool: title, percent: percent),
                pattern: .forPool(title)
            )
        }
    }

    private var textSizeBinding: Binding<DisplayPreferences.InterfaceSize> {
        Binding(
            get: { store.preferences.textSize },
            set: { value in store.updatePreferences { $0.textSize = value } }
        )
    }

    private var patternsBinding: Binding<Bool> {
        Binding(
            get: { store.preferences.distinguishWithoutColor },
            set: { value in store.updatePreferences { $0.distinguishWithoutColor = value } }
        )
    }

    private var contrastBinding: Binding<Bool> {
        Binding(
            get: { store.preferences.highContrast },
            set: { value in store.updatePreferences { $0.highContrast = value } }
        )
    }
}
