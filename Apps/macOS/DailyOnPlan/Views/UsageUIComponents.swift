import SwiftUI
import AppKit
import OnPlanCore

struct MacSettingsThreeColumn<First: View, Second: View, Third: View>: View {
    @ViewBuilder var first: () -> First
    @ViewBuilder var second: () -> Second
    @ViewBuilder var third: () -> Third
    @State private var height: CGFloat = 0

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            first()
                .reportMatchedHeight()
                .frame(maxWidth: .infinity, alignment: .top)
                .fillMatchedHeight(height)
            second()
                .reportMatchedHeight()
                .frame(maxWidth: .infinity, alignment: .top)
                .fillMatchedHeight(height)
            third()
                .reportMatchedHeight()
                .frame(maxWidth: .infinity, alignment: .top)
                .fillMatchedHeight(height)
        }
        .onPreferenceChange(MatchedHeightKey.self) { height = $0 }
    }
}

struct MacSettingsTwoColumn<Left: View, Right: View>: View {
    @ViewBuilder var left: () -> Left
    @ViewBuilder var right: () -> Right
    @State private var height: CGFloat = 0

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            left()
                .reportMatchedHeight()
                .frame(maxWidth: .infinity, alignment: .top)
                .fillMatchedHeight(height)
            right()
                .reportMatchedHeight()
                .frame(maxWidth: .infinity, alignment: .top)
                .fillMatchedHeight(height)
        }
        .onPreferenceChange(MatchedHeightKey.self) { height = $0 }
    }
}

struct MacSettingsFillStack<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            content()
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

struct SettingsPanel<Content: View>: View {
    let title: String
    var systemImage: String
    var subtitle: String? = nil
    var compact: Bool = false
    var fillsHeight: Bool = false
    @ViewBuilder var content: () -> Content
    @Environment(\.appTheme) private var theme
    @Environment(\.appHighContrast) private var highContrast

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 8 : 12) {
            HStack(spacing: compact ? 8 : 10) {
                Image(systemName: systemImage)
                    .font(compact ? .body : .title3)
                    .foregroundStyle(theme.tint)
                    .frame(width: compact ? 22 : 28, height: compact ? 22 : 28)
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .appFont(compact ? .subheadline : .headline, weight: .semibold)
                    if let subtitle {
                        Text(subtitle)
                            .appFont(.caption2)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer(minLength: 0)
            }
            content()
            if fillsHeight {
                Spacer(minLength: 0)
            }
        }
        .padding(compact ? 10 : 14)
        .frame(maxWidth: .infinity, maxHeight: fillsHeight ? .infinity : nil, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: compact ? 12 : 14, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: compact ? 12 : 14, style: .continuous)
                .strokeBorder(
                    Color.primary.opacity(highContrast ? 0.42 : 0.08),
                    lineWidth: highContrast ? 2 : 1
                )
        )
    }
}

struct MacSettingsScroll<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 16) {
                content
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(nsColor: .windowBackgroundColor))
        .scrollBounceBehavior(.basedOnSize)
    }
}

struct MatchedHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

extension View {
    func reportMatchedHeight() -> some View {
        background(
            GeometryReader { geo in
                Color.clear.preference(key: MatchedHeightKey.self, value: geo.size.height)
            }
        )
    }

    func fillMatchedHeight(_ height: CGFloat) -> some View {
        frame(minHeight: height > 0 ? height : nil, alignment: .top)
    }
}

struct MetricToggleRow: View {
    let title: String
    let systemImage: String
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: 10) {
            Label(title, systemImage: systemImage)
                .labelStyle(.titleAndIcon)
                .appFont(.subheadline)
            Spacer(minLength: 8)
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .toggleStyle(ReliableSwitchToggleStyle())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(title)
        .accessibilityValue(isOn ? "On" : "Off")
    }
}

struct ReliableSwitchToggleStyle: ToggleStyle {
    var onColor: Color? = nil

    func makeBody(configuration: Configuration) -> some View {
        ThemedSwitch(configuration: configuration, onColor: onColor)
    }
}

private struct ThemedSwitch: View {
    let configuration: ToggleStyleConfiguration
    var onColor: Color?
    @Environment(\.appTheme) private var theme

    var body: some View {
        let isOn = configuration.isOn
        let fill = onColor ?? theme.tint
        HStack(spacing: 0) {
            configuration.label
            Capsule()
                .fill(isOn ? fill : Color.primary.opacity(0.18))
                .frame(width: 34, height: 20)
                .overlay(alignment: isOn ? .trailing : .leading) {
                    Circle()
                        .fill(Color(nsColor: .windowBackgroundColor))
                        .shadow(color: .black.opacity(0.22), radius: 1, y: 0.5)
                        .frame(width: 16, height: 16)
                        .padding(2)
                }
                .animation(.easeInOut(duration: 0.12), value: isOn)
                .onTapGesture { configuration.isOn.toggle() }
        }
    }
}
