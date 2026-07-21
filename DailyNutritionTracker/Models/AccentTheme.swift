import SwiftUI

enum AccentTheme: String, CaseIterable, Identifiable, Codable {
    case onPlan
    case cyan
    case green
    case lime
    case slate
    case navy
    case indigo
    case purple
    case pink
    case orange
    case red

    var id: String { rawValue }

    var title: String {
        switch self {
        case .onPlan: return "OnPlan Blue"
        case .cyan: return "Cyan"
        case .green: return "Green"
        case .lime: return "Lime"
        case .slate: return "Slate"
        case .navy: return "Navy"
        case .indigo: return "Indigo"
        case .purple: return "Purple"
        case .pink: return "Pink"
        case .orange: return "Orange"
        case .red: return "Red"
        }
    }

    /// Brand-aligned accents; default is OnPlan Blue from the brand kit.
    var color: Color {
        switch self {
        case .onPlan: return .onPlanBlue
        case .cyan: return .onPlanCyan
        case .green: return .onPlanGreen
        case .lime: return .onPlanLime
        case .slate: return .onPlanMuted
        case .navy: return .onPlanSlate
        case .indigo: return Color(red: 0.35, green: 0.35, blue: 0.75)
        case .purple: return Color(red: 0.55, green: 0.30, blue: 0.75)
        case .pink: return Color(red: 0.85, green: 0.30, blue: 0.55)
        case .orange: return Color(red: 0.90, green: 0.45, blue: 0.15)
        case .red: return Color(red: 0.80, green: 0.25, blue: 0.25)
        }
    }
}
