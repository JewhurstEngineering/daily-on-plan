import OnPlanCore
import SwiftUI

struct PhoneThemeSettings: View {
    @EnvironmentObject private var store: OnPlanStore
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        Form {
            Section("Appearance") {
                Picker("Appearance", selection: appearanceBinding) {
                    ForEach(DisplayPreferences.AppearanceMode.allCases, id: \.self) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section("Color") {
                ForEach(DisplayPreferences.ColorTheme.allCases) { option in
                    Button {
                        store.updatePreferences { $0.colorTheme = option }
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
            set: { value in store.updatePreferences { $0.appearanceMode = value } }
        )
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
