import Foundation

enum DaySectionID: String, CaseIterable, Identifiable {
    case dailyStatus
    case weight
    case smoking
    case drinking
    case feelings
    case protein
    case checklist
    case workouts
    case hydration
    case bathroom
    case supplements

    var id: String { rawValue }

    var settingsTitle: String {
        switch self {
        case .dailyStatus: return "Daily status"
        case .weight: return "Weight & BMI"
        case .smoking: return "Smoking"
        case .drinking: return "Drinking"
        case .feelings: return "Feelings & cravings"
        case .protein: return "Protein"
        case .checklist: return "Fats, veggies & more"
        case .workouts: return "Workouts"
        case .hydration: return "Hydration"
        case .bathroom: return "Bathroom"
        case .supplements: return "Supplements"
        }
    }

    /// Sections the user can reorder (header stays pinned).
    static var defaultReorderableOrder: [DaySectionID] {
        [.weight, .smoking, .drinking, .feelings, .protein, .checklist, .workouts, .hydration, .bathroom, .supplements]
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

enum FeelingIntensity: String, CaseIterable, Identifiable {
    case small = "S"
    case medium = "M"
    case large = "L"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .small: return "Small"
        case .medium: return "Medium"
        case .large: return "Large"
        }
    }
}

enum FeelingType: String, CaseIterable, Identifiable {
    case feelingGood = "Feeling good"
    case feelNormal = "Feel normal"
    case energetic = "Energetic"
    case highEnergy = "High Energy"
    case sleepy = "Sleepy"
    case foggy = "Foggy"
    case fatigued = "Fatigued"
    case exhausted = "Exhausted"
    case hungerPang = "Hunger pang"
    case fullSatisfied = "Full/Satisfied"
    case cravingSweets = "Craving Sweets"
    case cravingSalty = "Craving Salty"
    case anxious = "Anxious"
    case stressed = "Stressed"
    case frenetic = "Frenetic"

    /// Legacy labels still present in historical logs.
    static let legacyHungry = "Hungry"
    static let legacyLowEnergy = "Low Energy"
    static let legacyAnxiousStressed = "Anxious/Stressed"

    var id: String { rawValue }

    var category: FeelingCategory {
        switch self {
        case .feelingGood, .feelNormal: return .mood
        case .energetic, .highEnergy, .sleepy, .foggy, .fatigued, .exhausted: return .energy
        case .hungerPang, .fullSatisfied: return .hunger
        case .cravingSweets, .cravingSalty: return .cravings
        case .anxious, .stressed, .frenetic: return .emotions
        }
    }

    var needsIntensity: Bool {
        self == .hungerPang
    }

    var systemImage: String {
        switch self {
        case .feelingGood: return "sun.max.fill"
        case .feelNormal: return "face.smiling"
        case .energetic: return "bolt.fill"
        case .highEnergy: return "bolt.circle.fill"
        case .sleepy: return "moon.zzz.fill"
        case .foggy: return "cloud.fog.fill"
        case .fatigued: return "battery.25"
        case .exhausted: return "battery.0"
        case .hungerPang: return "fork.knife"
        case .fullSatisfied: return "checkmark.circle"
        case .cravingSweets: return "birthday.cake"
        case .cravingSalty: return "drop.fill"
        case .anxious: return "brain.head.profile"
        case .stressed: return "exclamationmark.triangle"
        case .frenetic: return "arrow.triangle.2.circlepath"
        }
    }

    static func items(in category: FeelingCategory) -> [FeelingType] {
        allCases.filter { $0.category == category }
    }

    func displayType(intensity: FeelingIntensity?) -> String {
        if needsIntensity, let intensity {
            return "\(rawValue) (\(intensity.rawValue))"
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

    init(
        id: String = UUID().uuidString,
        name: String,
        category: FoodCategory,
        servingLabel: String,
        unitCalories: Int,
        proteinCategory: String? = nil,
        servings: Double = 1,
        amount: String? = nil
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.servingLabel = servingLabel
        self.unitCalories = unitCalories
        self.proteinCategory = proteinCategory
        self.servings = servings
        self.amount = amount
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

    var displayAmount: String {
        if category == .protein {
            return String(format: "%.1f× · %d kcal", servings, totalCalories)
        }
        let amt = amount?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return amt.isEmpty ? servingLabel : amt
    }
}

struct SupplementDefinition: Identifiable, Codable, Hashable {
    var id: String
    var name: String
    var dosesPerDay: Int
    var isEnabled: Bool

    init(id: String, name: String, dosesPerDay: Int, isEnabled: Bool = true) {
        self.id = id
        self.name = name
        self.dosesPerDay = dosesPerDay
        self.isEnabled = isEnabled
    }

    static let defaults: [SupplementDefinition] = [
        .init(id: "prescription", name: "Prescription", dosesPerDay: 3),
        .init(id: "vita-super", name: "Vita Super", dosesPerDay: 3),
        .init(id: "calcium", name: "Calcium 4 Blend", dosesPerDay: 2),
        .init(id: "fat-burner", name: "Fat Burner", dosesPerDay: 2),
        .init(id: "inner-balance", name: "Inner Balance", dosesPerDay: 4),
        .init(id: "omega-3", name: "Omega 3", dosesPerDay: 2),
        .init(id: "stay-slim", name: "Stay Slim", dosesPerDay: 2, isEnabled: false),
        .init(id: "medi-bolic", name: "Medi-Bolic Melts", dosesPerDay: 1, isEnabled: false),
        .init(id: "plateau", name: "Plateau Buster", dosesPerDay: 2, isEnabled: false)
    ]

    static var defaultJSON: String {
        let data = try! JSONEncoder().encode(defaults)
        return String(data: data, encoding: .utf8)!
    }

    func doseKey(_ index: Int) -> String {
        "\(id)#\(index)"
    }

    /// Decodes older saves that omit `isEnabled`.
    enum CodingKeys: String, CodingKey {
        case id, name, dosesPerDay, isEnabled
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        dosesPerDay = try container.decode(Int.self, forKey: .dosesPerDay)
        isEnabled = try container.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? true
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
}
