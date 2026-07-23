import SwiftUI
import UIKit

enum AppearanceMode: String, CaseIterable, Identifiable, Codable {
    case system
    case light
    case dark
    case sunriseSunset

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        case .sunriseSunset: return "Sunrise–Sunset"
        }
    }

    /// Static schemes for System / Light / Dark. Sunrise–Sunset needs `resolvedColorScheme(at:)`.
    var preferredColorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        case .sunriseSunset: return SolarDaylight.isDaylight(at: Date()) ? .light : .dark
        }
    }

    func resolvedColorScheme(at date: Date) -> ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        case .sunriseSunset: return SolarDaylight.isDaylight(at: date) ? .light : .dark
        }
    }
}

/// Approximate local sunrise/sunset from timezone (no location permission).
enum SolarDaylight {
    static func isDaylight(at date: Date, timeZone: TimeZone = .current) -> Bool {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let coords = estimatedCoordinates(for: timeZone)
        guard let window = sunriseSunset(on: date, latitude: coords.lat, longitude: coords.lon, timeZone: timeZone) else {
            let hour = calendar.component(.hour, from: date)
            return (7..<19).contains(hour)
        }
        return date >= window.sunrise && date < window.sunset
    }

    static func estimatedCoordinates(for timeZone: TimeZone) -> (lat: Double, lon: Double) {
        let hours = Double(timeZone.secondsFromGMT()) / 3600.0
        return (lat: 40.0, lon: hours * 15.0)
    }

    /// Compact sunrise/sunset estimate (temperate latitudes). Values are local clock times.
    static func sunriseSunset(
        on date: Date,
        latitude: Double,
        longitude: Double,
        timeZone: TimeZone
    ) -> (sunrise: Date, sunset: Date)? {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let dayStart = calendar.startOfDay(for: date)
        let dayOfYear = Double(calendar.ordinality(of: .day, in: .year, for: dayStart) ?? 1)

        // Declination of the sun (radians).
        let decl = 23.44 * .pi / 180 * sin(2 * .pi * (284 + dayOfYear) / 365)
        let latRad = latitude * .pi / 180
        let cosHA = -tan(latRad) * tan(decl)
        // Polar day/night fallback.
        guard cosHA > -1, cosHA < 1 else { return nil }
        let hourAngleHours = acos(cosHA) * 12 / .pi

        // Equation of time (~minutes) + longitude offset from timezone meridian.
        let b = 2 * .pi * (dayOfYear - 81) / 364
        let eot = 9.87 * sin(2 * b) - 7.53 * cos(b) - 1.5 * sin(b)
        let tzMeridian = Double(timeZone.secondsFromGMT(for: dayStart)) / 240.0 // seconds → degrees (360/24h)
        let longitudeCorrectionHours = (tzMeridian - longitude) / 15.0
        let solarNoonHours = 12 + longitudeCorrectionHours - eot / 60.0

        let sunriseHours = solarNoonHours - hourAngleHours
        let sunsetHours = solarNoonHours + hourAngleHours

        func clockTime(fromHours hours: Double) -> Date? {
            let clamped = min(max(hours, 0), 23.99)
            let h = Int(clamped)
            let m = Int((clamped - Double(h)) * 60)
            return calendar.date(bySettingHour: h, minute: m, second: 0, of: dayStart)
        }

        guard let sunrise = clockTime(fromHours: sunriseHours),
              let sunset = clockTime(fromHours: sunsetHours) else { return nil }
        return (sunrise, sunset)
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
