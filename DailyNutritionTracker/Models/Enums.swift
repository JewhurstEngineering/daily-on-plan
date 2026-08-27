import Foundation
import OnPlanCore

enum DaySectionID: String, CaseIterable, Identifiable {
    case dailyStatus
    case goals
    case weight
    case smoking
    case drinking
    case feelings
    case protein
    case fasting
    case checklist
    case workouts
    case hydration
    case bathroom
    case supplements

    var id: String { rawValue }

    var settingsTitle: String {
        switch self {
        case .dailyStatus: return "Daily status"
        case .goals: return "Goals"
        case .weight: return "Weight & BMI"
        case .smoking: return "Smoking"
        case .drinking: return "Drinking"
        case .feelings: return "Feelings & cravings"
        case .protein: return "Protein"
        case .fasting: return "Fasting"
        case .checklist: return "Fats, veggies & more"
        case .workouts: return "Workouts"
        case .hydration: return "Hydration"
        case .bathroom: return "Bathroom"
        case .supplements: return "Supplements"
        }
    }

    /// Sections the user can reorder (header stays pinned).
    static var defaultReorderableOrder: [DaySectionID] {
        [.goals, .weight, .smoking, .drinking, .feelings, .protein, .fasting, .checklist, .workouts, .hydration, .bathroom, .supplements]
    }

    /// Mirrors the icon each section already passes to its own `SectionCard` — centralized here
    /// so the Today jump bar doesn't need a third copy of this mapping.
    var systemImage: String {
        switch self {
        case .dailyStatus: return "calendar"
        case .goals: return "target"
        case .weight: return "scalemass"
        case .smoking: return "smoke"
        case .drinking: return "wineglass"
        case .feelings: return "heart.text.square"
        case .protein: return "fork.knife.circle"
        case .fasting: return "clock"
        case .checklist: return "leaf"
        case .workouts: return "figure.run"
        case .hydration: return "drop.fill"
        case .bathroom: return "toilet.fill"
        case .supplements: return "pills"
        }
    }

    var collapsedMessage: String {
        switch self {
        case .weight, .smoking, .drinking, .bathroom:
            return "Hidden for privacy — tap the chevron to show."
        default:
            return "Collapsed — tap the chevron to show."
        }
    }
}

enum SmokingMode: String, CaseIterable, Identifiable, Codable {
    case off
    case count
    case reduce
    case quit

    var id: String { rawValue }

    var title: String {
        switch self {
        case .off: return "Off"
        case .count: return "Count"
        case .reduce: return "Reduce"
        case .quit: return "Quit"
        }
    }

    var subtitle: String {
        switch self {
        case .off: return "Hide the smoking section"
        case .count: return "Log each cig or pack with a time"
        case .reduce: return "Log cigs/packs against a daily max"
        case .quit: return "Quit date, smoke-free days, and urge log"
        }
    }

    var showsSection: Bool { self != .off }
}

enum DrinkingMode: String, CaseIterable, Identifiable, Codable {
    case off
    case count
    case reduce
    case quit

    var id: String { rawValue }

    var title: String {
        switch self {
        case .off: return "Off"
        case .count: return "Count"
        case .reduce: return "Reduce"
        case .quit: return "Quit"
        }
    }

    var subtitle: String {
        switch self {
        case .off: return "Hide the drinking section"
        case .count: return "Log each drink with a time"
        case .reduce: return "Log drinks against a daily max"
        case .quit: return "Quit date, alcohol-free days, and urge log"
        }
    }

    var showsSection: Bool { self != .off }
}

enum CigarettePackMath {
    static let perPack = 20

    static func cigarettes(forPacks packs: Double) -> Int {
        max(0, Int((packs * Double(perPack)).rounded()))
    }

    static func packs(forCigarettes cigs: Int) -> Double {
        Double(cigs) / Double(perPack)
    }

    static func packsLabel(cigarettes: Int) -> String {
        let packs = packs(forCigarettes: cigarettes)
        if abs(packs * 2 - (packs * 2).rounded()) < 0.01 {
            let halves = Int((packs * 2).rounded())
            if halves == 0 { return "0 packs" }
            if halves == 1 { return "½ pack" }
            if halves % 2 == 0 {
                let whole = halves / 2
                return whole == 1 ? "1 pack" : "\(whole) packs"
            }
            let whole = halves / 2
            return whole == 0 ? "½ pack" : "\(whole)½ packs"
        }
        return String(format: "%.1f packs", packs)
    }

    static let quickPackOptions: [Double] = [0.5, 1, 1.5, 2]
}

/// Preset off-plan reasons — countable in reports. Users can add custom chips that stick.
enum OffPlanReasonCatalog {
    static let presets: [String] = [
        "Pizza",
        "Beer",
        "Wine",
        "Sweets",
        "Bread / carbs",
        "Fast food",
        "Restaurant",
        "Alcohol",
        "Social event",
        "Stress eating"
    ]

    static let maxCustomLength = 24
}

enum ProgramPhase: String, CaseIterable, Identifiable, Codable {
    case week1 = "week1"
    case week2Plus = "week2Plus"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .week1: return "Week 1"
        case .week2Plus: return "Week 2 & Beyond"
        }
    }

    var allowsFatsAndFruits: Bool {
        self == .week2Plus
    }
}

enum FoodCategory: String, CaseIterable, Identifiable, Codable {
    case protein
    case vegetable
    case fat
    case fruit
    case misc

    var id: String { rawValue }

    var title: String {
        switch self {
        case .protein: return "Protein"
        case .vegetable: return "Vegetables"
        case .fat: return "Fats"
        case .fruit: return "Fruits"
        case .misc: return "Miscellaneous"
        }
    }
}

enum ProteinCategory: String, CaseIterable, Identifiable, Codable {
    case veryLean
    case lean
    case mediumFat
    case shake
    case snack
    case substitution
    case other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .veryLean: return "Very Lean"
        case .lean: return "Lean"
        case .mediumFat: return "Medium Fat"
        case .shake: return "Protein Shakes"
        case .snack: return "Snacks & Meals"
        case .substitution: return "Substitutions"
        case .other: return "Other"
        }
    }

    /// Calories per standardized serving from the Week 1 chart.
    var caloriesPerServing: Int? {
        switch self {
        case .veryLean: return 35
        case .lean: return 55
        case .mediumFat: return 75
        default: return nil
        }
    }
}

enum FeelingCategory: String, CaseIterable, Identifiable {
    case mood = "Mood"
    case energy = "Energy"
    case hunger = "Hunger"
    case cravings = "Cravings"
    case emotions = "Emotions"

    var id: String { rawValue }
}

/// Three intensity tiers; labels are context-specific per feeling type.
enum FeelingIntensity: String, CaseIterable, Identifiable {
    case low = "1"
    case medium = "2"
    case high = "3"

    var id: String { rawValue }
}

enum FeelingType: String, CaseIterable, Identifiable {
    case feelGreat = "Feel Great"
    case feelGood = "Feel Good"
    case feelNormal = "Feel normal"
    case feelBad = "Feel Bad"

    case energetic = "Energetic"
    case highEnergy = "High Energy"
    case sleepy = "Sleepy"
    case foggy = "Foggy"
    case fatigued = "Fatigued"
    case exhausted = "Exhausted"

    case hungry = "Hungry"
    case fullSatisfied = "Full/Satisfied"

    case cravingSweets = "Craving Sweets"
    case cravingSalty = "Craving Salty"
    case cravingAlcohol = "Crave Alcohol"

    case anxious = "Anxious"
    case stressed = "Stressed"
    case frenetic = "Frenetic"
    case irritable = "Irritable"
    case overwhelmed = "Overwhelmed"
    case restless = "Restless"
    case frustrated = "Frustrated"

    /// Legacy labels still present in historical logs.
    static let legacyHungry = "Hungry"
    static let legacyHungerPang = "Hunger pang"
    static let legacyFeelingGood = "Feeling good"
    static let legacyLowEnergy = "Low Energy"
    static let legacyAnxiousStressed = "Anxious/Stressed"

    var id: String { rawValue }

    var category: FeelingCategory {
        switch self {
        case .feelGreat, .feelGood, .feelNormal, .feelBad: return .mood
        case .energetic, .highEnergy, .sleepy, .foggy, .fatigued, .exhausted: return .energy
        case .hungry, .fullSatisfied: return .hunger
        case .cravingSweets, .cravingSalty, .cravingAlcohol: return .cravings
        case .anxious, .stressed, .frenetic, .irritable, .overwhelmed, .restless, .frustrated:
            return .emotions
        }
    }

    var needsIntensity: Bool {
        switch self {
        case .hungry, .cravingSweets, .cravingSalty, .cravingAlcohol,
             .anxious, .stressed, .frenetic, .irritable, .overwhelmed, .restless, .frustrated:
            return true
        default:
            return false
        }
    }

    /// Requires drinking mode ≠ off.
    var requiresAlcoholTracking: Bool {
        self == .cravingAlcohol
    }

    var systemImage: String {
        switch self {
        case .feelGreat: return "sun.max.fill"
        case .feelGood: return "sun.min.fill"
        case .feelNormal: return "face.smiling"
        case .feelBad: return "cloud.rain.fill"
        case .energetic: return "bolt.fill"
        case .highEnergy: return "bolt.circle.fill"
        case .sleepy: return "moon.zzz.fill"
        case .foggy: return "cloud.fog.fill"
        case .fatigued: return "battery.25"
        case .exhausted: return "battery.0"
        case .hungry: return "fork.knife"
        case .fullSatisfied: return "checkmark.circle"
        case .cravingSweets: return "birthday.cake"
        case .cravingSalty: return "drop.fill"
        case .cravingAlcohol: return "wineglass.fill"
        case .anxious: return "brain.head.profile"
        case .stressed: return "exclamationmark.triangle"
        case .frenetic: return "arrow.triangle.2.circlepath"
        case .irritable: return "flame"
        case .overwhelmed: return "water.waves"
        case .restless: return "figure.walk.motion"
        case .frustrated: return "hand.raised.fill"
        }
    }

    /// Short title for intensity tier buttons.
    func intensityTitle(_ intensity: FeelingIntensity) -> String {
        switch (self, intensity) {
        case (.hungry, .low): return "Peckish"
        case (.hungry, .medium): return "Hungry"
        case (.hungry, .high): return "Ravenous"

        case (.cravingSweets, .low): return "Faint"
        case (.cravingSweets, .medium): return "Persistent"
        case (.cravingSweets, .high): return "Insatiable"

        case (.cravingSalty, .low): return "Subtle"
        case (.cravingSalty, .medium): return "Pronounced"
        case (.cravingSalty, .high): return "Overpowering"

        case (.cravingAlcohol, .low): return "Fleeting"
        case (.cravingAlcohol, .medium): return "Compelling"
        case (.cravingAlcohol, .high): return "Urgent"

        case (.anxious, .low): return "Mild"
        case (.anxious, .medium): return "Moderate"
        case (.anxious, .high): return "Severe"

        case (.stressed, .low): return "Manageable"
        case (.stressed, .medium): return "Heavy"
        case (.stressed, .high): return "Crushing"

        case (.frenetic, .low): return "Restless"
        case (.frenetic, .medium): return "Scattered"
        case (.frenetic, .high): return "Chaotic"

        case (.irritable, .low): return "Mild"
        case (.irritable, .medium): return "Edgy"
        case (.irritable, .high): return "Explosive"

        case (.overwhelmed, .low): return "Slight"
        case (.overwhelmed, .medium): return "Heavy"
        case (.overwhelmed, .high): return "Flooded"

        case (.restless, .low): return "Fidgety"
        case (.restless, .medium): return "Unsettled"
        case (.restless, .high): return "Agitated"

        case (.frustrated, .low): return "Annoyed"
        case (.frustrated, .medium): return "Frustrated"
        case (.frustrated, .high): return "Furious"

        default:
            switch intensity {
            case .low: return "Low"
            case .medium: return "Medium"
            case .high: return "High"
            }
        }
    }

    /// Supporting line under each intensity option.
    func intensitySubtitle(_ intensity: FeelingIntensity) -> String {
        switch (self, intensity) {
        case (.hungry, .low): return "Could eat, could wait"
        case (.hungry, .medium): return "Ready for a full meal"
        case (.hungry, .high): return "Urgent need for food"

        case (.cravingSweets, .low): return "Passing thought of sweets"
        case (.cravingSweets, .medium): return "Actively looking for a treat"
        case (.cravingSweets, .high): return "Must have sugar now"

        case (.cravingSalty, .low): return "Slight desire for chips"
        case (.cravingSalty, .medium): return "Specifically seeking savory"
        case (.cravingSalty, .high): return "Fixated on salt"

        case (.cravingAlcohol, .low): return "Brief habitual thought"
        case (.cravingAlcohol, .medium): return "Needs conscious willpower"
        case (.cravingAlcohol, .high): return "Intense physical urge"

        case (.anxious, .low): return "Background noise"
        case (.anxious, .medium): return "Distracting and tense"
        case (.anxious, .high): return "Overwhelming"

        case (.stressed, .low): return "Standard daily pressure"
        case (.stressed, .medium): return "Feeling weighed down"
        case (.stressed, .high): return "At the breaking point"

        case (.frenetic, .low): return "A little fidgety"
        case (.frenetic, .medium): return "Racing thoughts, hard to focus"
        case (.frenetic, .high): return "Bouncing off the walls"

        case (.irritable, .low): return "Easily bothered"
        case (.irritable, .medium): return "Short fuse"
        case (.irritable, .high): return "Hard to stay calm"

        case (.overwhelmed, .low): return "A bit much"
        case (.overwhelmed, .medium): return "Hard to keep up"
        case (.overwhelmed, .high): return "Can’t take more"

        case (.restless, .low): return "Can’t quite settle"
        case (.restless, .medium): return "Need to move / shift"
        case (.restless, .high): return "Can’t sit still"

        case (.frustrated, .low): return "Minor irritation"
        case (.frustrated, .medium): return "Blocked and annoyed"
        case (.frustrated, .high): return "Boiling over"

        default: return ""
        }
    }

    var intensityPrompt: String {
        switch self {
        case .hungry: return "How hungry?"
        case .cravingSweets, .cravingSalty, .cravingAlcohol: return "How strong is the craving?"
        case .anxious: return "How anxious?"
        case .stressed: return "How stressed?"
        case .frenetic: return "How frenetic?"
        case .irritable: return "How irritable?"
        case .overwhelmed: return "How overwhelmed?"
        case .restless: return "How restless?"
        case .frustrated: return "How frustrated?"
        default: return "How strong?"
        }
    }

    static func items(in category: FeelingCategory, alcoholTrackingEnabled: Bool = false) -> [FeelingType] {
        allCases.filter { type in
            guard type.category == category else { return false }
            if type.requiresAlcoholTracking { return alcoholTrackingEnabled }
            return true
        }
    }

    func displayType(intensity: FeelingIntensity?) -> String {
        if needsIntensity, let intensity {
            return "\(rawValue) (\(intensityTitle(intensity)))"
        }
        return rawValue
    }
}

struct CatalogFood: Identifiable, Hashable, Codable {
    var id: String { "\(category.rawValue)-\(name)-\(servingLabel)" }
    let name: String
    let category: FoodCategory
    let servingLabel: String
    let calories: Int
    let phase: ProgramPhase
    let proteinCategory: ProteinCategory?
    let servingsPerUnit: Double
    let isHealthier: Bool
    let isHighFiber: Bool

    init(
        name: String,
        category: FoodCategory,
        servingLabel: String,
        calories: Int,
        phase: ProgramPhase = .week1,
        proteinCategory: ProteinCategory? = nil,
        servingsPerUnit: Double = 1,
        isHealthier: Bool = false,
        isHighFiber: Bool = false
    ) {
        self.name = name
        self.category = category
        self.servingLabel = servingLabel
        self.calories = calories
        self.phase = phase
        self.proteinCategory = proteinCategory
        self.servingsPerUnit = servingsPerUnit
        self.isHealthier = isHealthier
        self.isHighFiber = isHighFiber
    }
}

/// One ingredient in a saved / suggested meal.
struct MealComponent: Identifiable, Hashable, Codable {
    var id: String
    var name: String
    var category: FoodCategory
    var servingLabel: String
    var unitCalories: Int
    var proteinCategory: String?
    var servings: Double
    var amount: String?
    /// Macros for **one** serving; scaled by `servings` when the component is logged.
    var unitMacros: Macros?

    init(
        id: String = UUID().uuidString,
        name: String,
        category: FoodCategory,
        servingLabel: String,
        unitCalories: Int,
        proteinCategory: String? = nil,
        servings: Double = 1,
        amount: String? = nil,
        unitMacros: Macros? = nil
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.servingLabel = servingLabel
        self.unitCalories = unitCalories
        self.proteinCategory = proteinCategory
        self.servings = servings
        self.amount = amount
        self.unitMacros = unitMacros
    }

    init(from food: CatalogFood, servings: Double = 1, amount: String? = nil) {
        let unit: Int
        if let per = food.proteinCategory?.caloriesPerServing {
            unit = per
        } else {
            unit = food.calories
        }
        self.init(
            id: food.id,
            name: food.name,
            category: food.category,
            servingLabel: food.servingLabel,
            unitCalories: unit,
            proteinCategory: food.proteinCategory?.rawValue,
            servings: servings,
            amount: amount ?? (food.category == .protein ? nil : food.servingLabel)
        )
    }

    var totalCalories: Int {
        Int((Double(unitCalories) * servings).rounded())
    }

    /// Macros for the amount actually eaten.
    var totalMacros: Macros? {
        unitMacros?.scaled(by: servings)
    }

    var displayAmount: String {
        if category == .protein {
            return String(format: "%.1f× · %d kcal", servings, totalCalories)
        }
        let amt = amount?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return amt.isEmpty ? servingLabel : amt
    }
}

struct SupplementReminderTime: Codable, Hashable, Identifiable {
    var hour: Int
    var minute: Int

    var id: String { "\(hour):\(minute)" }

    init(hour: Int, minute: Int) {
        self.hour = min(max(hour, 0), 23)
        self.minute = min(max(minute, 0), 59)
    }
}

struct SupplementDefinition: Identifiable, Codable, Hashable {
    var id: String
    var name: String
    var dosesPerDay: Int
    var isEnabled: Bool
    /// When true, schedules one daily notification per dose time.
    var reminderEnabled: Bool
    /// One time per dose (length should match `dosesPerDay`).
    var reminderTimes: [SupplementReminderTime]

    init(
        id: String,
        name: String,
        dosesPerDay: Int,
        isEnabled: Bool = true,
        reminderEnabled: Bool = false,
        reminderTimes: [SupplementReminderTime]? = nil
    ) {
        self.id = id
        self.name = name
        self.dosesPerDay = dosesPerDay
        self.isEnabled = isEnabled
        self.reminderEnabled = reminderEnabled
        self.reminderTimes = reminderTimes ?? Self.defaultTimes(for: dosesPerDay)
        syncReminderTimes()
    }

    /// Old clinic SKU names keyed by stable id. User-renamed items are left alone.
    static let clinicNameReplacements: [String: (old: [String], new: String)] = [
        "vita-super": (["Vita Super"], "Multivitamin"),
        "calcium": (["Calcium 4 Blend"], "Calcium"),
        "fat-burner": (["Fat Burner"], "Fat burner"),
        "inner-balance": (["Inner Balance"], "Digestive support"),
        "omega-3": (["Omega 3"], "Omega-3"),
        "stay-slim": (["Stay Slim"], "Appetite support"),
        "medi-bolic": (["Medi-Bolic Melts"], "Protein melts"),
        "plateau": (["Plateau Buster"], "Plateau support")
    ]

    static let defaults: [SupplementDefinition] = [
        .init(id: "prescription", name: "Prescription", dosesPerDay: 3),
        .init(id: "vita-super", name: "Multivitamin", dosesPerDay: 3),
        .init(id: "calcium", name: "Calcium", dosesPerDay: 2),
        .init(id: "fat-burner", name: "Fat burner", dosesPerDay: 2),
        .init(id: "inner-balance", name: "Digestive support", dosesPerDay: 4),
        .init(id: "omega-3", name: "Omega-3", dosesPerDay: 2),
        .init(id: "stay-slim", name: "Appetite support", dosesPerDay: 2, isEnabled: false),
        .init(id: "medi-bolic", name: "Protein melts", dosesPerDay: 1, isEnabled: false),
        .init(id: "plateau", name: "Plateau support", dosesPerDay: 2, isEnabled: false)
    ]

    static func migratingClinicNames(_ defs: [SupplementDefinition]) -> [SupplementDefinition] {
        defs.map { def in
            guard let mapping = clinicNameReplacements[def.id],
                  mapping.old.contains(def.name) else { return def }
            var copy = def
            copy.name = mapping.new
            return copy
        }
    }

    static var defaultJSON: String {
        let data = try! JSONEncoder().encode(defaults)
        return String(data: data, encoding: .utf8)!
    }

    func doseKey(_ index: Int) -> String {
        "\(id)#\(index)"
    }

    static func defaultTimes(for doses: Int) -> [SupplementReminderTime] {
        let presets: [[(Int, Int)]] = [
            [(8, 0)],
            [(8, 0), (20, 0)],
            [(8, 0), (13, 0), (20, 0)],
            [(8, 0), (12, 0), (16, 0), (20, 0)],
            [(8, 0), (11, 0), (14, 0), (17, 0), (20, 0)],
            [(8, 0), (10, 0), (12, 0), (15, 0), (17, 0), (20, 0)],
            [(7, 30), (9, 30), (11, 30), (13, 30), (15, 30), (17, 30), (20, 0)],
            [(7, 0), (9, 0), (11, 0), (13, 0), (15, 0), (17, 0), (19, 0), (21, 0)]
        ]
        let count = min(max(doses, 1), 8)
        let pairs = presets[count - 1]
        return pairs.map { SupplementReminderTime(hour: $0.0, minute: $0.1) }
    }

    mutating func syncReminderTimes() {
        let target = min(max(dosesPerDay, 1), 8)
        dosesPerDay = target
        let defaults = Self.defaultTimes(for: target)
        if reminderTimes.count < target {
            reminderTimes.append(contentsOf: defaults.dropFirst(reminderTimes.count))
        } else if reminderTimes.count > target {
            reminderTimes = Array(reminderTimes.prefix(target))
        }
    }

    /// Decodes older saves that omit newer fields.
    enum CodingKeys: String, CodingKey {
        case id, name, dosesPerDay, isEnabled, reminderEnabled, reminderTimes
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        dosesPerDay = try container.decode(Int.self, forKey: .dosesPerDay)
        isEnabled = try container.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? true
        reminderEnabled = try container.decodeIfPresent(Bool.self, forKey: .reminderEnabled) ?? false
        reminderTimes = try container.decodeIfPresent([SupplementReminderTime].self, forKey: .reminderTimes)
            ?? Self.defaultTimes(for: dosesPerDay)
        syncReminderTimes()
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(dosesPerDay, forKey: .dosesPerDay)
        try container.encode(isEnabled, forKey: .isEnabled)
        try container.encode(reminderEnabled, forKey: .reminderEnabled)
        try container.encode(reminderTimes, forKey: .reminderTimes)
    }
}

enum FastingPreset: String, CaseIterable, Identifiable, Codable {
    case sixteenEight = "16:8"
    case eighteenSix = "18:6"
    case twentyFour = "20:4"
    case omad = "OMAD"
    case custom = "custom"

    var id: String { rawValue }

    var title: String { rawValue }

    var defaultFastHours: Double {
        switch self {
        case .sixteenEight: return 16
        case .eighteenSix: return 18
        case .twentyFour: return 20
        case .omad: return 23
        case .custom: return 16
        }
    }

    var blurb: String {
        switch self {
        case .sixteenEight: return "Eat 8 hours, fast 16."
        case .eighteenSix: return "Eat 6 hours, fast 18."
        case .twentyFour: return "Eat 4 hours, fast 20."
        case .omad: return "One meal, about 1 hour."
        case .custom: return "Pick your own fast length."
        }
    }
}

enum HungerScale {
    static let guidance = "Start eating at 3 or 4. Stop at 5 or 6. Eating earlier or later often leads to overeating."

    static let levels: [(Int, String)] = [
        (10, "Sick or stuffed"),
        (9, "Very uncomfortably full"),
        (8, "Uncomfortably full"),
        (7, "Full — a little uncomfortable"),
        (6, "Perfectly comfortable / satisfied"),
        (5, "Comfortable — could eat a little more"),
        (4, "Slightly uncomfortable — early hunger"),
        (3, "Uncomfortably hungry — stomach rumbling"),
        (2, "Very uncomfortable — irritable"),
        (1, "Weak and light-headed")
    ]

    static func label(for value: Int) -> String {
        levels.first(where: { $0.0 == value })?.1 ?? ""
    }
}

enum BMICalculator {
    static func bmi(weightLbs: Double, heightInches: Double) -> Double? {
        guard heightInches > 0, weightLbs > 0 else { return nil }
        return (weightLbs / (heightInches * heightInches)) * 703
    }

    static func category(for bmi: Double) -> String {
        switch bmi {
        case ..<18.5: return "Underweight"
        case ..<25: return "Normal"
        case ..<30: return "Overweight"
        default: return "Obese"
        }
    }
}

/// Y-axis domain so body-metric charts show movement instead of a 0–400 empty scale.
/// Weight: first/current high-water + 25 lb (or kg equivalent) on top, goal − 25 on the bottom.
/// The range only grows when a logged value or the goal crosses a pad edge.
enum ChartValueScale {
    static let weightPadPounds = 25.0
    static let lengthPadInches = 2.0
    static let fatPercentPad = 3.0
    static let proteinPadKcal = 50.0
    static let waterPadOz = 8.0
    static let countPad = 2.0

    static func weightPad(usesMetric: Bool) -> Double {
        usesMetric ? weightPadPounds * 0.453592 : weightPadPounds
    }

    static func lengthPad(usesMetric: Bool) -> Double {
        usesMetric ? lengthPadInches * 2.54 : lengthPadInches
    }

    /// Same visual pad as 25 lb, expressed in BMI points at this height.
    static func bmiPad(heightInches: Double) -> Double {
        guard heightInches > 0 else { return 2 }
        return (weightPadPounds / (heightInches * heightInches)) * 703
    }

    static func domain(
        values: [Double],
        goal: Double? = nil,
        pad: Double,
        floorAtZero: Bool = false
    ) -> ClosedRange<Double>? {
        var anchors = values.filter { $0.isFinite }
        if let goal, goal.isFinite { anchors.append(goal) }
        guard let minValue = anchors.min(), let maxValue = anchors.max() else { return nil }
        let padding = max(pad, 0)
        var low = minValue - padding
        var high = maxValue + padding
        if high <= low {
            high = low + max(padding * 2, 1)
        }
        if floorAtZero {
            low = max(0, low)
        }
        if high <= low {
            high = low + 1
        }
        return low...high
    }
}

/// Least-squares line through dated samples, for a chart trend overlay.
enum ChartTrendLine {
    struct Segment: Equatable {
        var startDate: Date
        var startValue: Double
        var endDate: Date
        var endValue: Double
    }

    static func leastSquares(dates: [Date], values: [Double]) -> Segment? {
        guard dates.count >= 2, dates.count == values.count else { return nil }
        let xs = dates.map(\.timeIntervalSince1970)
        let n = Double(xs.count)
        let sumX = xs.reduce(0, +)
        let sumY = values.reduce(0, +)
        let sumXY = zip(xs, values).reduce(0.0) { $0 + $1.0 * $1.1 }
        let sumXX = xs.reduce(0.0) { $0 + $1 * $1 }
        let denominator = n * sumXX - sumX * sumX
        guard denominator != 0 else { return nil }
        let slope = (n * sumXY - sumX * sumY) / denominator
        let intercept = (sumY - slope * sumX) / n
        func y(_ x: Double) -> Double { intercept + slope * x }
        return Segment(
            startDate: dates[0],
            startValue: y(xs[0]),
            endDate: dates[dates.count - 1],
            endValue: y(xs[xs.count - 1])
        )
    }
}

enum DateHelpers {
    static func startOfDay(_ date: Date) -> Date {
        Calendar.current.startOfDay(for: date)
    }

    static func isSameDay(_ a: Date, _ b: Date) -> Bool {
        Calendar.current.isDate(a, inSameDayAs: b)
    }

    static func formattedDay(_ date: Date) -> String {
        date.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())
    }

    static func formattedTime(_ date: Date) -> String {
        date.formatted(.dateTime.hour().minute())
    }

    static func formattedTimeStamp(_ date: Date, relativeTo now: Date = Date()) -> String {
        let time = formattedTime(date)
        if Calendar.current.isDate(date, inSameDayAs: now) {
            return time
        }
        if Calendar.current.isDateInYesterday(date) {
            return "Yesterday, \(time)"
        }
        return "\(date.formatted(.dateTime.month(.abbreviated).day())), \(time)"
    }
}
