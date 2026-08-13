import SwiftUI
import OnPlanCore

struct LayoutSettingsView: View {
    @EnvironmentObject private var store: OnPlanStore
    @State private var appearanceEpoch = 0

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top, spacing: 12) {
                    SettingsPanel(
                        title: "Menu bar",
                        systemImage: "menubar.rectangle",
                        subtitle: "Metrics in the system menu bar."
                    ) {
                        metricToggles(menuToggle)
                    }
                    .frame(maxWidth: .infinity, alignment: .top)

                    SettingsPanel(
                        title: "Display",
                        systemImage: "slider.horizontal.3",
                        subtitle: "Shared menu bar presentation."
                    ) {
                        Toggle("Show title text in menu bar", isOn: showMenuBarBinding)
                            .toggleStyle(.checkbox)

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Density")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                            Picker("Density", selection: formatBinding) {
                                Text("Compact").tag(DisplayPreferences.MenuBarFormat.compact)
                                Text("Detailed").tag(DisplayPreferences.MenuBarFormat.detailed)
                            }
                            .pickerStyle(.segmented)
                            .labelsHidden()
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Labels")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                            Picker("Labels", selection: labelStyleBinding) {
                                Text("Icons").tag(DisplayPreferences.MenuBarLabelStyle.icons)
                                Text("Words").tag(DisplayPreferences.MenuBarLabelStyle.shortWords)
                            }
                            .pickerStyle(.segmented)
                            .labelsHidden()
                        }

                        Text(labelStyleHelp)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)

                        Text("Detailed shows every enabled metric. Compact shows protein, water, or plan status.")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .top)

                    SettingsPanel(
                        title: "Popover",
                        systemImage: "rectangle.portrait.on.rectangle.portrait",
                        subtitle: "Metrics in the click panel."
                    ) {
                        metricToggles(popoverToggle)
                    }
                    .frame(maxWidth: .infinity, alignment: .top)
                }
                .id(appearanceEpoch)

                SettingsPanel(
                    title: "Live example",
                    systemImage: "eye",
                    subtitle: "Menu bar text from the toggles above."
                ) {
                    let title = MenuBarFormatter.title(
                        snapshot: store.snapshot,
                        preferences: store.preferences
                    )
                    HStack(spacing: 8) {
                        AppLogo(size: 16, template: true)
                        if store.preferences.showInMenuBar {
                            Text(title)
                                .font(.caption.weight(.medium).monospacedDigit())
                        } else {
                            Text("(icon only)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.primary.opacity(0.06))
                    )
                }
            }
            .padding(16)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                appearanceEpoch += 1
            }
        }
    }

    @ViewBuilder
    private func metricToggles(
        _ binding: (WritableKeyPath<DisplayPreferences.SurfaceToggles, Bool>) -> Binding<Bool>
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            MetricToggleRow(title: "Followed plan", systemImage: "checkmark.seal", isOn: binding(\.followedPlan))
            MetricToggleRow(title: "Ketosis", systemImage: "flame", isOn: binding(\.ketosis))
            MetricToggleRow(title: "Protein", systemImage: "fork.knife", isOn: binding(\.protein))
            MetricToggleRow(title: "Water", systemImage: "drop", isOn: binding(\.water))
            MetricToggleRow(title: "Smoking", systemImage: "smoke", isOn: binding(\.smoking))
            MetricToggleRow(title: "Drinking", systemImage: "wineglass", isOn: binding(\.drinking))
            MetricToggleRow(title: "Bathroom", systemImage: "toilet", isOn: binding(\.bathroom))
        }
    }

    private var labelStyleHelp: String {
        switch store.preferences.menuBarLabelStyle {
        case .icons:
            return "Icons: ✓ / P 240 / W 32 stand in for each metric."
        case .shortWords:
            return "Words: “Plan · Protein 240 · Water 32 oz”."
        }
    }

    private var showMenuBarBinding: Binding<Bool> {
        Binding(
            get: { store.preferences.showInMenuBar },
            set: { value in
                var prefs = store.preferences
                prefs.showInMenuBar = value
                store.applyPreferences(prefs)
            }
        )
    }

    private var formatBinding: Binding<DisplayPreferences.MenuBarFormat> {
        Binding(
            get: { store.preferences.menuBarFormat },
            set: { value in
                var prefs = store.preferences
                prefs.menuBarFormat = value
                store.applyPreferences(prefs)
            }
        )
    }

    private var labelStyleBinding: Binding<DisplayPreferences.MenuBarLabelStyle> {
        Binding(
            get: { store.preferences.menuBarLabelStyle },
            set: { value in
                var prefs = store.preferences
                prefs.menuBarLabelStyle = value
                store.applyPreferences(prefs)
            }
        )
    }

    private func menuToggle(_ keyPath: WritableKeyPath<DisplayPreferences.SurfaceToggles, Bool>) -> Binding<Bool> {
        Binding(
            get: { store.preferences.menuBar[keyPath: keyPath] },
            set: { value in
                var prefs = store.preferences
                prefs.menuBar[keyPath: keyPath] = value
                store.applyPreferences(prefs)
            }
        )
    }

    private func popoverToggle(_ keyPath: WritableKeyPath<DisplayPreferences.SurfaceToggles, Bool>) -> Binding<Bool> {
        Binding(
            get: { store.preferences.popover[keyPath: keyPath] },
            set: { value in
                var prefs = store.preferences
                prefs.popover[keyPath: keyPath] = value
                store.applyPreferences(prefs)
            }
        )
    }
}
