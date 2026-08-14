import Foundation

/// Per-device chrome prefs (theme, layout, a11y). Not CloudKit — journal settings live in SwiftData `AppSettings`.
public struct DisplayPreferences: Codable, Sendable, Equatable {
    public var launchAtLogin: Bool
    public var showInMenuBar: Bool
    public var menuBarFormat: MenuBarFormat
    public var menuBarLabelStyle: MenuBarLabelStyle
    public var menuBar: SurfaceToggles
    public var popover: SurfaceToggles
    public var appearanceMode: AppearanceMode
    public var colorTheme: ColorTheme
    public var customThemeColors: CustomThemeColors
    public var interfaceSize: InterfaceSize
    public var textSize: InterfaceSize
    public var colorVision: ColorVision
    public var distinguishWithoutColor: Bool
    public var highContrast: Bool
    /// iPhone-configured Watch quick-add (pushed to Watch in the day snapshot).
    public var watchQuickAdd: WatchQuickAdd
    /// Per-Mac mute. Reminder times still live in CloudKit `AppSettings`.
    public var notifyOnThisMac: Bool

    public enum AppearanceMode: String, Codable, Sendable, CaseIterable {
        case system
        case light
        case dark

        public var title: String {
            switch self {
            case .system: return "System"
            case .light: return "Light"
            case .dark: return "Dark"
            }
        }
    }

    public struct ThemeSwatch: Codable, Sendable, Equatable {
        public var red: Double
        public var green: Double
        public var blue: Double

        public init(red: Double, green: Double, blue: Double) {
            self.red = Self.clamp(red)
            self.green = Self.clamp(green)
            self.blue = Self.clamp(blue)
        }

        public init(hex: String) {
            var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
            if s.hasPrefix("#") { s.removeFirst() }
            guard s.count == 6, let v = UInt32(s, radix: 16) else {
                self.init(red: 0.5, green: 0.5, blue: 0.5)
                return
            }
            self.init(
                red: Double((v >> 16) & 0xFF) / 255,
                green: Double((v >> 8) & 0xFF) / 255,
                blue: Double(v & 0xFF) / 255
            )
        }

        private static func clamp(_ v: Double) -> Double { min(1, max(0, v)) }

        public var hexString: String {
            String(
                format: "#%02X%02X%02X",
                Int((red * 255).rounded()),
                Int((green * 255).rounded()),
                Int((blue * 255).rounded())
            )
        }
    }

    public struct CustomThemeColors: Codable, Sendable, Equatable {
        public var protein: ThemeSwatch
        public var water: ThemeSwatch
        public var plan: ThemeSwatch
        public var weight: ThemeSwatch

        public static let `default` = CustomThemeColors(
            protein: ThemeSwatch(hex: "#3B82F6"),
            water: ThemeSwatch(hex: "#18D6E6"),
            plan: ThemeSwatch(hex: "#22C55E"),
            weight: ThemeSwatch(hex: "#1E293B")
        )

        public init(protein: ThemeSwatch, water: ThemeSwatch, plan: ThemeSwatch, weight: ThemeSwatch) {
            self.protein = protein
            self.water = water
            self.plan = plan
            self.weight = weight
        }
    }

    public enum ColorTheme: String, Codable, Sendable, CaseIterable, Identifiable {
        case onPlan
        case original
        case system
        case ink
        case harbor
        case forest
        case tokyoNight
        case catppuccin
        case dracula
        case nord
        case solarized
        case oneDark
        case gruvbox
        case monokai
        case nightOwl
        case synthwave
        case ayu
        case github
        case custom

        public var id: String { rawValue }

        public var title: String {
            switch self {
            case .onPlan: return "On Plan"
            case .original: return "Original"
            case .system: return "System"
            case .ink: return "Ink"
            case .harbor: return "Harbor"
            case .forest: return "Forest"
            case .tokyoNight: return "Tokyo Night"
            case .catppuccin: return "Catppuccin"
            case .dracula: return "Dracula"
            case .nord: return "Nord"
            case .solarized: return "Solarized"
            case .oneDark: return "One Dark"
            case .gruvbox: return "Gruvbox"
            case .monokai: return "Monokai"
            case .nightOwl: return "Night Owl"
            case .synthwave: return "SynthWave ’84"
            case .ayu: return "Ayu"
            case .github: return "GitHub"
            case .custom: return "Custom"
            }
        }

        public var subtitle: String {
            switch self {
            case .onPlan: return "Brand blue, cyan water, green plan"
            case .original: return "The first shipped blue / purple / teal"
            case .system: return "Your accent color and system greens"
            case .ink: return "High-contrast print, almost no hue"
            case .harbor: return "Slate and copper"
            case .forest: return "Moss, bark, cream"
            case .tokyoNight: return "Midnight neon — cyan, pink, gold"
            case .catppuccin: return "Soothing pastels, mocha / latte"
            case .dracula: return "Purple canvas, neon accents"
            case .nord: return "Arctic frost and aurora"
            case .solarized: return "Precision teal-gray contrast"
            case .oneDark: return "Atom’s chalky dark slate"
            case .gruvbox: return "Warm sand, rust, and olive"
            case .monokai: return "Classic pink, cyan, and lime"
            case .nightOwl: return "Navy night, readable lavenders"
            case .synthwave: return "Retrowave pinks and laser green"
            case .ayu: return "Warm gold on near-black iron"
            case .github: return "github.com dark / light"
            case .custom: return "Pick protein, water, plan, and weight colors"
            }
        }
    }

    public enum InterfaceSize: String, Codable, Sendable, CaseIterable, Identifiable {
        case defaultSize = "default"
        case large
        case extraLarge

        public var id: String { rawValue }

        public var title: String {
            switch self {
            case .defaultSize: return "Default"
            case .large: return "Large"
            case .extraLarge: return "Extra Large"
            }
        }
    }

    public enum ColorVision: String, Codable, Sendable, CaseIterable, Identifiable {
        case typical
        case deuteranopia
        case protanopia
        case tritanopia
        case monochrome

        public var id: String { rawValue }

        public var title: String {
            switch self {
            case .typical: return "Typical"
            case .deuteranopia: return "Red–green (deuteranopia)"
            case .protanopia: return "Red–green (protanopia)"
            case .tritanopia: return "Blue–yellow (tritanopia)"
            case .monochrome: return "Monochrome"
            }
        }

        public var subtitle: String {
            switch self {
            case .typical: return "Your Theme colors as-is"
            case .deuteranopia: return "Okabe–Ito blues, orange, and yellow"
            case .protanopia: return "Blue, yellow, and gray — avoids dim reds"
            case .tritanopia: return "Vermillion, purple, and green"
            case .monochrome: return "Lightness only — use with patterns"
            }
        }
    }

    public enum MenuBarFormat: String, Codable, Sendable, CaseIterable {
        case compact
        case detailed
    }

    public enum MenuBarLabelStyle: String, Codable, Sendable, CaseIterable {
        case icons
        case shortWords
    }

    public struct SurfaceToggles: Codable, Sendable, Equatable {
        public var followedPlan: Bool
        public var ketosis: Bool
        public var protein: Bool
        public var water: Bool
        public var smoking: Bool
        public var drinking: Bool
        public var bathroom: Bool

        public static let menuBarDefault = SurfaceToggles(
            followedPlan: true,
            ketosis: false,
            protein: true,
            water: true,
            smoking: false,
            drinking: false,
            bathroom: false
        )

        public static let popoverDefault = SurfaceToggles(
            followedPlan: true,
            ketosis: true,
            protein: true,
            water: true,
            smoking: true,
            drinking: true,
            bathroom: true
        )

        public init(
            followedPlan: Bool,
            ketosis: Bool,
            protein: Bool,
            water: Bool,
            smoking: Bool,
            drinking: Bool,
            bathroom: Bool
        ) {
            self.followedPlan = followedPlan
            self.ketosis = ketosis
            self.protein = protein
            self.water = water
            self.smoking = smoking
            self.drinking = drinking
            self.bathroom = bathroom
        }

        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            followedPlan = try c.decodeIfPresent(Bool.self, forKey: .followedPlan) ?? true
            ketosis = try c.decodeIfPresent(Bool.self, forKey: .ketosis) ?? true
            protein = try c.decodeIfPresent(Bool.self, forKey: .protein) ?? true
            water = try c.decodeIfPresent(Bool.self, forKey: .water) ?? true
            smoking = try c.decodeIfPresent(Bool.self, forKey: .smoking) ?? true
            drinking = try c.decodeIfPresent(Bool.self, forKey: .drinking) ?? true
            bathroom = try c.decodeIfPresent(Bool.self, forKey: .bathroom) ?? true
        }
    }

    public static let `default` = DisplayPreferences(
        launchAtLogin: false,
        showInMenuBar: true,
        menuBarFormat: .detailed,
        menuBarLabelStyle: .icons,
        menuBar: .menuBarDefault,
        popover: .popoverDefault,
        appearanceMode: .system,
        colorTheme: .onPlan,
        customThemeColors: .default,
        interfaceSize: .defaultSize,
        textSize: .defaultSize,
        colorVision: .typical,
        distinguishWithoutColor: false,
        highContrast: false,
        watchQuickAdd: .default
    )

    public init(
        launchAtLogin: Bool,
        showInMenuBar: Bool,
        menuBarFormat: MenuBarFormat,
        menuBarLabelStyle: MenuBarLabelStyle = .icons,
        menuBar: SurfaceToggles,
        popover: SurfaceToggles,
        appearanceMode: AppearanceMode = .system,
        colorTheme: ColorTheme = .onPlan,
        customThemeColors: CustomThemeColors = .default,
        interfaceSize: InterfaceSize = .defaultSize,
        textSize: InterfaceSize = .defaultSize,
        colorVision: ColorVision = .typical,
        distinguishWithoutColor: Bool = false,
        highContrast: Bool = false,
        watchQuickAdd: WatchQuickAdd = .default,
        notifyOnThisMac: Bool = true
    ) {
        self.launchAtLogin = launchAtLogin
        self.showInMenuBar = showInMenuBar
        self.menuBarFormat = menuBarFormat
        self.menuBarLabelStyle = menuBarLabelStyle
        self.menuBar = menuBar
        self.popover = popover
        self.appearanceMode = appearanceMode
        self.colorTheme = colorTheme
        self.customThemeColors = customThemeColors
        self.interfaceSize = interfaceSize
        self.textSize = textSize
        self.colorVision = colorVision
        self.distinguishWithoutColor = distinguishWithoutColor
        self.highContrast = highContrast
        self.watchQuickAdd = watchQuickAdd
        self.notifyOnThisMac = notifyOnThisMac
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        launchAtLogin = try c.decodeIfPresent(Bool.self, forKey: .launchAtLogin) ?? false
        showInMenuBar = try c.decodeIfPresent(Bool.self, forKey: .showInMenuBar) ?? true
        menuBarFormat = try c.decodeIfPresent(MenuBarFormat.self, forKey: .menuBarFormat) ?? .detailed
        menuBarLabelStyle = try c.decodeIfPresent(MenuBarLabelStyle.self, forKey: .menuBarLabelStyle) ?? .icons
        menuBar = try c.decodeIfPresent(SurfaceToggles.self, forKey: .menuBar) ?? .menuBarDefault
        popover = try c.decodeIfPresent(SurfaceToggles.self, forKey: .popover) ?? .popoverDefault
        appearanceMode = try c.decodeIfPresent(AppearanceMode.self, forKey: .appearanceMode) ?? .system
        colorTheme = try c.decodeIfPresent(ColorTheme.self, forKey: .colorTheme) ?? .onPlan
        customThemeColors = try c.decodeIfPresent(CustomThemeColors.self, forKey: .customThemeColors) ?? .default
        interfaceSize = try c.decodeIfPresent(InterfaceSize.self, forKey: .interfaceSize) ?? .defaultSize
        textSize = try c.decodeIfPresent(InterfaceSize.self, forKey: .textSize) ?? interfaceSize
        colorVision = try c.decodeIfPresent(ColorVision.self, forKey: .colorVision) ?? .typical
        distinguishWithoutColor = try c.decodeIfPresent(Bool.self, forKey: .distinguishWithoutColor) ?? false
        highContrast = try c.decodeIfPresent(Bool.self, forKey: .highContrast) ?? false
        watchQuickAdd = try c.decodeIfPresent(WatchQuickAdd.self, forKey: .watchQuickAdd) ?? .default
        notifyOnThisMac = try c.decodeIfPresent(Bool.self, forKey: .notifyOnThisMac) ?? true
    }
}

public struct WatchQuickAdd: Codable, Sendable, Equatable {
    public var slots: [Action]
    public var hydrationSizesOz: [Double]

    public static let slotCount = 3
    public static let sizePresets: [Double] = [8, 12, 16.9, 20, 24, 33.8]

    public static let `default` = WatchQuickAdd(
        slots: [.water, .electrolyte, .smoking],
        hydrationSizesOz: [8, 12, 16.9, 24]
    )

    public init(slots: [Action], hydrationSizesOz: [Double]) {
        self.slots = Self.normalized(slots)
        self.hydrationSizesOz = hydrationSizesOz.isEmpty ? Self.default.hydrationSizesOz : hydrationSizesOz
    }

    public var resolvedSlots: [Action] { Self.normalized(slots) }

    public static func normalized(_ slots: [Action]) -> [Action] {
        var result = Array(slots.prefix(slotCount))
        let fallback: [Action] = [.water, .electrolyte, .smoking]
        while result.count < slotCount {
            result.append(fallback[result.count % fallback.count])
        }
        return result
    }

    public enum Action: String, Codable, Sendable, CaseIterable, Identifiable {
        case water
        case electrolyte
        case smoking
        case drinking
        case bathroomUrine
        case bathroomStool

        public var id: String { rawValue }

        public var title: String {
            switch self {
            case .water: return "Water"
            case .electrolyte: return "Electrolytes"
            case .smoking: return "Smoking"
            case .drinking: return "Drinking"
            case .bathroomUrine: return "Urine"
            case .bathroomStool: return "Stool"
            }
        }

        public var systemImage: String {
            switch self {
            case .water: return "drop.fill"
            case .electrolyte: return "bolt.fill"
            case .smoking: return "flame.fill"
            case .drinking: return "wineglass.fill"
            case .bathroomUrine: return "drop"
            case .bathroomStool: return "leaf"
            }
        }

        public var needsHydrationSize: Bool {
            self == .water || self == .electrolyte
        }
    }
}

public enum DisplayPreferenceStore {
    private static let key = "displayPreferences"

    public static func load(defaults: UserDefaults = .standard) -> DisplayPreferences {
        guard let data = defaults.data(forKey: key),
              let prefs = try? JSONDecoder().decode(DisplayPreferences.self, from: data)
        else {
            return .default
        }
        return prefs
    }

    public static func save(_ prefs: DisplayPreferences, defaults: UserDefaults = .standard) {
        if let data = try? JSONEncoder().encode(prefs) {
            defaults.set(data, forKey: key)
        }
    }
}
