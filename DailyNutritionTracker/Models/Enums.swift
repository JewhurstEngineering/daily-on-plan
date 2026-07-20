import Foundation

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

enum FeelingType: String, CaseIterable, Identifiable {
    case hungry = "Hungry"
    case cravingSweets = "Craving Sweets"
    case cravingSalty = "Craving Salty"
    case lowEnergy = "Low Energy"
    case anxiousStressed = "Anxious/Stressed"
    case fullSatisfied = "Full/Satisfied"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .hungry: return "fork.knife"
        case .cravingSweets: return "birthday.cake"
        case .cravingSalty: return "drop.fill"
        case .lowEnergy: return "battery.25"
        case .anxiousStressed: return "brain.head.profile"
        case .fullSatisfied: return "checkmark.circle"
        }
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

struct SupplementDefinition: Identifiable, Codable, Hashable {
    var id: String
    var name: String
    var dosesPerDay: Int

    static let defaults: [SupplementDefinition] = [
        .init(id: "prescription", name: "Prescription", dosesPerDay: 3),
        .init(id: "vita-super", name: "Vita Super", dosesPerDay: 3),
        .init(id: "calcium", name: "Calcium 4 Blend", dosesPerDay: 2),
        .init(id: "fat-burner", name: "Fat Burner", dosesPerDay: 2),
        .init(id: "inner-balance", name: "Inner Balance", dosesPerDay: 4),
        .init(id: "omega-3", name: "Omega 3", dosesPerDay: 2),
        .init(id: "stay-slim", name: "Stay Slim", dosesPerDay: 2),
        .init(id: "medi-bolic", name: "Medi-Bolic Melts", dosesPerDay: 1),
        .init(id: "plateau", name: "Plateau Buster", dosesPerDay: 2)
    ]

    static var defaultJSON: String {
        let data = try! JSONEncoder().encode(defaults)
        return String(data: data, encoding: .utf8)!
    }

    func doseKey(_ index: Int) -> String {
        "\(id)#\(index)"
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
