import Foundation
import OnPlanCore
import SwiftData

/// Encodes checklist rows as `name|||amount` (legacy plain names still parse).
enum ChecklistStorage {
    static let separator = "|||"

    static func encode(name: String, amount: String) -> String {
        let trimmedAmount = amount.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedAmount.isEmpty { return name }
        return "\(name)\(separator)\(trimmedAmount)"
    }

    static func parse(_ raw: String) -> (name: String, amount: String) {
        guard let range = raw.range(of: separator) else {
            return (raw, "")
        }
        let name = String(raw[..<range.lowerBound])
        let amount = String(raw[range.upperBound...])
        return (name, amount)
    }

    static func name(of raw: String) -> String { parse(raw).name }

    static func display(_ raw: String) -> String {
        let parsed = parse(raw)
        if parsed.amount.isEmpty { return parsed.name }
        return "\(parsed.name) · \(parsed.amount)"
    }

    static func isFat(_ raw: String) -> Bool {
        let name = name(of: raw)
        return FoodCatalog.fats.contains { $0.name == name }
    }

    static func isVegetable(_ raw: String) -> Bool {
        let name = name(of: raw)
        return FoodCatalog.vegetables.contains { $0.name == name }
    }

    static func appendUnique(_ encoded: String, to array: inout [String]) {
        let itemName = name(of: encoded)
        guard !array.contains(where: { name(of: $0) == itemName }) else { return }
        array.append(encoded)
    }

    static func vegetables(in log: DailyLog) -> [String] {
        log.checkedFatsAndVeggies.filter { !isFat($0) }
    }

    static func fats(in log: DailyLog) -> [String] {
        if !log.checkedFats.isEmpty {
            return log.checkedFats
        }
        return log.checkedFatsAndVeggies.filter(isFat)
    }

    /// Moves fat items out of the combined veggies array into `checkedFats`. Safe to call repeatedly.
    static func migrateFatsSplit(on log: DailyLog) {
        let fatRaws = log.checkedFatsAndVeggies.filter(isFat)
        guard !fatRaws.isEmpty else { return }
        for raw in fatRaws {
            appendUnique(raw, to: &log.checkedFats)
        }
        log.checkedFatsAndVeggies.removeAll(where: isFat)
    }

    static func defaultAmount(for name: String, category: FoodCategory) -> String {
        let foods: [CatalogFood]
        switch category {
        case .vegetable: foods = FoodCatalog.vegetables
        case .fat: foods = FoodCatalog.fats
        case .fruit: foods = FoodCatalog.fruits
        case .misc: foods = FoodCatalog.misc
        case .protein: foods = FoodCatalog.proteins
        }
        return foods.first(where: { $0.name == name })?.servingLabel ?? "1 serving"
    }
}

struct SuggestionItem: Identifiable, Hashable {
    var id: String { name }
    let name: String
    let subtitle: String?
    let calories: Int?
    let proteinCategory: String?
    let servings: Double
    let amount: String?
    /// Macros for the whole suggested amount, carried over from the last time it was logged.
    let macros: Macros?

    init(
        name: String,
        subtitle: String? = nil,
        calories: Int? = nil,
        proteinCategory: String? = nil,
        servings: Double = 1,
        amount: String? = nil,
        macros: Macros? = nil
    ) {
        self.name = name
        self.subtitle = subtitle
        self.calories = calories
        self.proteinCategory = proteinCategory
        self.servings = servings
        self.amount = amount
        self.macros = macros
    }
}

@MainActor
enum UsageSuggestions {
    static func proteinChips(in context: ModelContext, limit: Int = 8) -> [SuggestionItem] {
        let logs = allLogs(in: context)
        let entries = logs.flatMap(\.proteins).sorted { $0.time > $1.time }
        if entries.isEmpty {
            return FoodCatalog.quickProteinPresets.map {
                SuggestionItem(
                    name: $0.name,
                    subtitle: $0.servingLabel,
                    calories: $0.calories,
                    proteinCategory: $0.proteinCategory?.rawValue,
                    servings: $0.servingsPerUnit
                )
            }
        }

        var latest: [SuggestionItem] = []
        var seen = Set<String>()
        for entry in entries {
            if seen.insert(entry.name).inserted {
                latest.append(chip(from: entry))
            }
            if latest.count >= limit { break }
        }

        let popularNames = rankedNames(entries.map(\.name), limit: limit)
        var popular: [SuggestionItem] = []
        for name in popularNames where !latest.contains(where: { $0.name == name }) {
            if let sample = entries.first(where: { $0.name == name }) {
                popular.append(chip(from: sample))
            }
        }

        return Array((latest + popular).prefix(limit))
    }

    /// Recently created saved meals for one-tap whole-plate logging.
    static func recentMealChips(meals: [SavedMeal], limit: Int = 4) -> [SavedMeal] {
        Array(meals.sorted { $0.createdAt > $1.createdAt }.prefix(limit))
    }

    /// Recent snack-category protein entries for one-tap Snack sheet.
    static func snackChips(in context: ModelContext, limit: Int = 6) -> [SuggestionItem] {
        let logs = allLogs(in: context)
        let entries = logs
            .flatMap(\.proteins)
            .filter { $0.proteinCategory == ProteinCategory.snack.rawValue }
            .sorted { $0.time > $1.time }

        if entries.isEmpty { return [] }

        var latest: [SuggestionItem] = []
        var seen = Set<String>()
        for entry in entries {
            if seen.insert(entry.name.lowercased()).inserted {
                latest.append(
                    SuggestionItem(
                        name: entry.name,
                        subtitle: entry.servingSize,
                        calories: entry.calories,
                        proteinCategory: ProteinCategory.snack.rawValue,
                        servings: max(entry.servings, 1)
                    )
                )
            }
            if latest.count >= limit { break }
        }
        return latest
    }

    static func checklistChips(
        category: FoodCategory,
        phase: ProgramPhase,
        in context: ModelContext,
        limit: Int = 6
    ) -> [SuggestionItem] {
        let logs = allLogs(in: context)
        let raws: [String]
        switch category {
        case .fruit:
            raws = logs.flatMap(\.checkedFruits)
        case .misc:
            raws = logs.flatMap(\.checkedMiscItems)
        case .fat:
            raws = logs.flatMap { ChecklistStorage.fats(in: $0) }
        case .vegetable:
            raws = logs.flatMap { ChecklistStorage.vegetables(in: $0) }
        default:
            raws = logs.flatMap(\.checkedFatsAndVeggies)
        }

        if raws.isEmpty {
            let defaults: [CatalogFood]
            switch category {
            case .vegetable:
                defaults = Array(FoodCatalog.vegetables.prefix(6))
            case .fat:
                defaults = phase.allowsFatsAndFruits ? Array(FoodCatalog.fats.filter(\.isHealthier).prefix(6)) : []
            case .fruit:
                defaults = phase.allowsFatsAndFruits ? Array(FoodCatalog.fruits.prefix(6)) : []
            case .misc:
                defaults = [
                    FoodCatalog.misc.first(where: { $0.name.contains("Hot sauce") }),
                    FoodCatalog.misc.first(where: { $0.name.contains("Almond milk") }),
                    FoodCatalog.misc.first(where: { $0.name.contains("Pickles") }),
                    FoodCatalog.misc.first(where: { $0.name.contains("Lemon") })
                ].compactMap { $0 }
            default:
                defaults = []
            }
            return defaults.map {
                SuggestionItem(name: $0.name, subtitle: $0.servingLabel, amount: $0.servingLabel)
            }
        }

        var latest: [SuggestionItem] = []
        var seen = Set<String>()
        for raw in raws.reversed() {
            let parsed = ChecklistStorage.parse(raw)
            if seen.insert(parsed.name).inserted {
                let amount = parsed.amount.isEmpty
                    ? ChecklistStorage.defaultAmount(for: parsed.name, category: category)
                    : parsed.amount
                latest.append(SuggestionItem(name: parsed.name, subtitle: amount, amount: amount))
            }
            if latest.count >= limit { break }
        }
        return latest
    }

    static func workoutChips(in context: ModelContext, limit: Int = 8) -> [SuggestionItem] {
        let defaults = [
            "Interactive Exercise", "Brisk walking", "Strength training", "Cycling", "Yoga",
            "Swimming", "Running", "Cardio", "Calisthenics"
        ]
        let logs = allLogs(in: context)
        let names = logs.flatMap(\.workouts).sorted { $0.timeLogged > $1.timeLogged }.map(\.activityName)
        if names.isEmpty {
            return defaults.map { SuggestionItem(name: $0) }
        }
        var latest: [String] = []
        var seen = Set<String>()
        for name in names where seen.insert(name).inserted {
            latest.append(name)
            if latest.count >= limit { break }
        }
        let popular = rankedNames(names, limit: limit).filter { !latest.contains($0) }
        return Array((latest + popular).prefix(limit)).map { SuggestionItem(name: $0) }
    }

    /// Chip uses last-logged servings + total kcal so one tap repeats the same amount.
    private static func chip(from entry: ProteinEntry) -> SuggestionItem {
        let servings = max(entry.servings, 0.5)
        let total = max(entry.calories, 1)
        let subtitle: String
        if abs(servings - 1) < 0.01 {
            subtitle = "\(entry.servingSize) · \(total) kcal"
        } else {
            subtitle = String(format: "%.1f× · %d kcal", servings, total)
        }
        return SuggestionItem(
            name: entry.name,
            subtitle: subtitle,
            calories: total,
            proteinCategory: entry.proteinCategory,
            servings: servings,
            macros: entry.macros
        )
    }

    private static func rankedNames(_ names: [String], limit: Int) -> [String] {
        var counts: [String: Int] = [:]
        for name in names { counts[name, default: 0] += 1 }
        return counts.sorted { lhs, rhs in
            if lhs.value == rhs.value { return lhs.key < rhs.key }
            return lhs.value > rhs.value
        }
        .prefix(limit)
        .map(\.key)
    }

    private static func allLogs(in context: ModelContext) -> [DailyLog] {
        let descriptor = FetchDescriptor<DailyLog>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        return (try? context.fetch(descriptor)) ?? []
    }
}
