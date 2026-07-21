import Foundation
import SwiftData

enum AppLimits {
    static let proteinGoalMin = 100
    static let proteinGoalMax = 3000
    static let proteinGoalStep = 1
    static let customFeelingMaxChars = 18
    static let miscDailyLimit = 4
    static let defaultBottleOz = 16.9
    static let hydrationTargetOz = 64
    static let defaultDailyCigaretteLimit = 20 // 1 pack
    static let defaultCigarettesPerPack = 20
    static let cigaretteLimitMax = 60
    static let defaultDailyDrinkLimit = 2
    static let drinkLimitMax = 20
}

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

    init(
        name: String,
        subtitle: String? = nil,
        calories: Int? = nil,
        proteinCategory: String? = nil,
        servings: Double = 1,
        amount: String? = nil
    ) {
        self.name = name
        self.subtitle = subtitle
        self.calories = calories
        self.proteinCategory = proteinCategory
        self.servings = servings
        self.amount = amount
    }
}

@MainActor
enum UsageSuggestions {
    static func proteinChips(in context: ModelContext, limit: Int = 8) -> [SuggestionItem] {
        let logs = allLogs(in: context)
        let entries = logs.flatMap(\.proteinEntries).sorted { $0.time > $1.time }
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
                let unit = unitCalories(for: entry)
                latest.append(
                    SuggestionItem(
                        name: entry.name,
                        subtitle: "1 serving · \(unit) kcal",
                        calories: unit,
                        proteinCategory: entry.proteinCategory,
                        servings: 1
                    )
                )
            }
            if latest.count >= limit { break }
        }

        let popularNames = rankedNames(entries.map(\.name), limit: limit)
        var popular: [SuggestionItem] = []
        for name in popularNames where !latest.contains(where: { $0.name == name }) {
            if let sample = entries.first(where: { $0.name == name }) {
                let unit = unitCalories(for: sample)
                popular.append(
                    SuggestionItem(
                        name: name,
                        subtitle: "1 serving · \(unit) kcal",
                        calories: unit,
                        proteinCategory: sample.proteinCategory,
                        servings: 1
                    )
                )
            }
        }

        return Array((latest + popular).prefix(limit))
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
        default:
            raws = logs.flatMap(\.checkedFatsAndVeggies).filter { raw in
                let name = ChecklistStorage.name(of: raw)
                switch category {
                case .vegetable: return FoodCatalog.vegetables.contains(where: { $0.name == name })
                case .fat: return FoodCatalog.fats.contains(where: { $0.name == name })
                default: return false
                }
            }
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
        let names = logs.flatMap(\.workoutEntries).sorted { $0.timeLogged > $1.timeLogged }.map(\.activityName)
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

    private static func unitCalories(for entry: ProteinEntry) -> Int {
        if entry.servings > 0 {
            return max(1, Int((Double(entry.calories) / entry.servings).rounded()))
        }
        if let cat = ProteinCategory(rawValue: entry.proteinCategory), let per = cat.caloriesPerServing {
            return per
        }
        return entry.calories
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
