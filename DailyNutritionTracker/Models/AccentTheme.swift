import SwiftUI
import UIKit

enum AppearanceMode: String, CaseIterable, Identifiable, Codable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }

    /// `nil` means follow the iPhone’s Light/Dark setting.
    var preferredColorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

/// User-selectable look. **Default (OnPlan)** uses full brand roles; other options recolor primary only.
enum AccentTheme: String, CaseIterable, Identifiable, Codable {
    case onPlan
    case cyan
    case green
    case lime
    case teal
    case indigo
    case purple
    case rose
    case coral
    case orange
    case slate
    case navy
    case custom

    var id: String { rawValue }

    /// Preset swatches shown in Settings (excludes custom — that uses ColorPicker).
    static var pickerCases: [AccentTheme] {
        allCases.filter { $0 != .custom }
    }

    var title: String {
        switch self {
        case .onPlan: return "Default"
        case .cyan: return "Cyan"
        case .green: return "Green"
        case .lime: return "Lime"
        case .teal: return "Teal"
        case .indigo: return "Indigo"
        case .purple: return "Purple"
        case .rose: return "Rose"
        case .coral: return "Coral"
        case .orange: return "Orange"
        case .slate: return "Slate"
        case .navy: return "Navy"
        case .custom: return "Custom"
        }
    }

    var subtitle: String {
        switch self {
        case .onPlan:
            return "OnPlan brand — blue actions, cyan progress, green for on-plan"
        case .custom:
            return "Your color for buttons, links, and accents"
        default:
            return "Recolors primary controls; progress & success stay brand-tinted"
        }
    }

    /// Primary tint (buttons, links, section icons). Also used for `.tint(...)`.
    var primary: Color {
        switch self {
        case .onPlan: return .onPlanBlue
        case .cyan: return .onPlanCyan
        case .green: return .onPlanGreen
        case .lime: return .onPlanLime
        case .teal: return Color(hex: "#14B8A6")
        case .indigo: return Color(hex: "#6366F1")
        case .purple: return Color(hex: "#A855F7")
        case .rose: return Color(hex: "#F43F5E")
        case .coral: return Color(hex: "#F97066")
        case .orange: return Color(hex: "#F97316")
        case .slate: return .onPlanMuted
        case .navy: return .onPlanSlate
        case .custom: return .onPlanBlue // overridden via customAccentHex
        }
    }

    /// Protein ring, hydration fills — cyan under Default.
    var progress: Color {
        switch self {
        case .onPlan: return .onPlanCyan
        case .custom: return primary
        default: return primary
        }
    }

    /// Followed-plan / positive confirmation.
    var success: Color { .onPlanGreen }

    /// Over protein goal, soft warnings.
    var warning: Color { Color.orange }

    /// Swatch in the picker (Default shows a blue→cyan blend cue).
    var color: Color { primary }

    var pickerSecondary: Color? {
        self == .onPlan ? .onPlanCyan : nil
    }

    func resolvedPrimary(customHex: String?) -> Color {
        if self == .custom {
            return Color(hex: customHex ?? "#3B82F6")
        }
        return primary
    }

    func resolvedProgress(customHex: String?) -> Color {
        if self == .custom {
            return resolvedPrimary(customHex: customHex)
        }
        return progress
    }
}

// MARK: - Environment

private struct AccentThemeKey: EnvironmentKey {
    static let defaultValue: AccentTheme = .onPlan
}

private struct AccentPrimaryKey: EnvironmentKey {
    static let defaultValue: Color = AccentTheme.onPlan.primary
}

private struct AccentProgressKey: EnvironmentKey {
    static let defaultValue: Color = AccentTheme.onPlan.progress
}

extension EnvironmentValues {
    var accentTheme: AccentTheme {
        get { self[AccentThemeKey.self] }
        set { self[AccentThemeKey.self] = newValue }
    }

    var accentPrimary: Color {
        get { self[AccentPrimaryKey.self] }
        set { self[AccentPrimaryKey.self] = newValue }
    }

    var accentProgress: Color {
        get { self[AccentProgressKey.self] }
        set { self[AccentProgressKey.self] = newValue }
    }
}

extension Color {
    /// `#RRGGBB` for persistence (drops alpha).
    func toHexRGB() -> String? {
        let ui = UIColor(self)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        guard ui.getRed(&r, green: &g, blue: &b, alpha: &a) else { return nil }
        return String(
            format: "#%02X%02X%02X",
            Int(round(r * 255)),
            Int(round(g * 255)),
            Int(round(b * 255))
        )
    }
}

extension AppSettings {
    var accentPrimary: Color {
        accentTheme.resolvedPrimary(customHex: customAccentHex)
    }

    var accentProgress: Color {
        accentTheme.resolvedProgress(customHex: customAccentHex)
    }
}
