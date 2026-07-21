import SwiftUI

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
    case slate
    case navy

    var id: String { rawValue }

    /// Themes shown in Settings (brand-aligned only).
    static var pickerCases: [AccentTheme] { allCases }

    var title: String {
        switch self {
        case .onPlan: return "Default"
        case .cyan: return "Cyan"
        case .green: return "Green"
        case .lime: return "Lime"
        case .slate: return "Slate"
        case .navy: return "Navy"
        }
    }

    var subtitle: String {
        switch self {
        case .onPlan:
            return "OnPlan brand — blue actions, cyan progress, green for on-plan"
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
        case .slate: return .onPlanMuted
        case .navy: return .onPlanSlate
        }
    }

    /// Protein ring, hydration fills — cyan under Default.
    var progress: Color {
        switch self {
        case .onPlan: return .onPlanCyan
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
}

// MARK: - Environment

private struct AccentThemeKey: EnvironmentKey {
    static let defaultValue: AccentTheme = .onPlan
}

extension EnvironmentValues {
    var accentTheme: AccentTheme {
        get { self[AccentThemeKey.self] }
        set { self[AccentThemeKey.self] = newValue }
    }
}
