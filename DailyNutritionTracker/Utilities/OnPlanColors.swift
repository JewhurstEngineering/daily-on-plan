import SwiftUI

extension Color {
    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch cleaned.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }

    // MARK: - OnPlan brand tokens (from OnPlan_Brand_Kit)

    static let onPlanDeepNavy = Color(hex: "#071426")
    static let onPlanNavy = Color(hex: "#0F172A")
    static let onPlanSlate = Color(hex: "#1E293B")
    static let onPlanBlue = Color(hex: "#3B82F6")
    static let onPlanCyan = Color(hex: "#18D6E6")
    static let onPlanCyan2 = Color(hex: "#00AFC4")
    static let onPlanGreen = Color(hex: "#22C55E")
    static let onPlanLime = Color(hex: "#98EC39")
    static let onPlanMuted = Color(hex: "#64748B")
    static let onPlanLight = Color(hex: "#F8FAFC")
    static let onPlanWhite = Color(hex: "#FFFFFF")
    static let onPlanInk = Color(hex: "#091423")
    static let onPlanSilver = Color(hex: "#CBD5E1")
}
