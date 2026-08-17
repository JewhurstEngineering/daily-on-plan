import OnPlanCore
import SwiftData
import SwiftUI

struct PhoneThemeSettings: View {
    @EnvironmentObject private var store: OnPlanStore
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        Form {
            Section {
                Picker("Appearance", selection: appearanceBinding) {
                    ForEach(DisplayPreferences.AppearanceMode.allCases, id: \.self) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.menu)
            } header: {
                Text("Appearance")
            } footer: {
                Text("Light, dark, and this palette also apply to Today — not only this Settings page.")
            }

            Section("Color") {
                ForEach(DisplayPreferences.ColorTheme.allCases) { option in
                    Button {
                        applyColorTheme(option)
                    } label: {
                        HStack(spacing: 10) {
                            themeSwatches(option)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(option.title)
                                    .foregroundStyle(.primary)
                                Text(option.subtitle)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }
                            Spacer()
                            if store.preferences.colorTheme == option {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(Color.accentColor)
                            }
                        }
                    }
                }
            }

            if store.preferences.colorTheme == .custom {
                Section("Custom colors") {
                    customPicker("Protein", \.protein)
                    customPicker("Water", \.water)
                    customPicker("Plan", \.plan)
                    customPicker("Weight", \.weight)
                }
            }
        }
        .navigationTitle("Theme")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func themeSwatches(_ option: DisplayPreferences.ColorTheme) -> some View {
        let palette = ThemePalette.resolved(option, scheme: scheme, custom: store.preferences.customThemeColors)
        return HStack(spacing: 3) {
            ForEach(Array(palette.swatches.enumerated()), id: \.offset) { _, color in
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(color)
                    .frame(width: 14, height: 22)
            }
        }
    }

    private var appearanceBinding: Binding<DisplayPreferences.AppearanceMode> {
        Binding(
            get: { store.preferences.appearanceMode },
            set: applyAppearance
        )
    }

    private func applyAppearance(_ mode: DisplayPreferences.AppearanceMode) {
        store.updatePreferences { $0.appearanceMode = mode }
    }

    private func applyColorTheme(_ option: DisplayPreferences.ColorTheme) {
        store.updatePreferences { $0.colorTheme = option }
    }

    private func customPicker(
        _ title: String,
        _ keyPath: WritableKeyPath<DisplayPreferences.CustomThemeColors, DisplayPreferences.ThemeSwatch>
    ) -> some View {
        ColorPicker(
            title,
            selection: Binding(
                get: { store.preferences.customThemeColors[keyPath: keyPath].color },
                set: { newColor in
                    store.updatePreferences {
                        $0.customThemeColors[keyPath: keyPath] = DisplayPreferences.ThemeSwatch(newColor)
                    }
                }
            ),
            supportsOpacity: false
        )
    }
}
