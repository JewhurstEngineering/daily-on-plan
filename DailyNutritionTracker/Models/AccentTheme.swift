import SwiftUI

enum AccentTheme: String, CaseIterable, Identifiable, Codable {
    case green
    case teal
    case blue
    case indigo
    case purple
    case pink
    case orange
    case red
    case brown
    case slate

    var id: String { rawValue }

    var title: String {
        rawValue.capitalized
    }

    /// Default matches the existing AccentColor asset (forest green).
    var color: Color {
        switch self {
        case .green: return Color(red: 0.18, green: 0.52, blue: 0.42)
        case .teal: return Color(red: 0.10, green: 0.55, blue: 0.55)
        case .blue: return Color(red: 0.20, green: 0.45, blue: 0.85)
        case .indigo: return Color(red: 0.35, green: 0.35, blue: 0.75)
        case .purple: return Color(red: 0.55, green: 0.30, blue: 0.75)
        case .pink: return Color(red: 0.85, green: 0.30, blue: 0.55)
        case .orange: return Color(red: 0.90, green: 0.45, blue: 0.15)
        case .red: return Color(red: 0.80, green: 0.25, blue: 0.25)
        case .brown: return Color(red: 0.55, green: 0.38, blue: 0.25)
        case .slate: return Color(red: 0.35, green: 0.40, blue: 0.48)
        }
    }
}
