import Foundation

enum MealSuggestor {
    /// Builds a draft meal from prefers (if any) else catalog, respecting phase + excludes + remaining protein budget.
    static func suggest(
        settings: AppSettings,
        remainingProteinCalories: Int
    ) -> [MealComponent] {
        let phase = settings.phase
        let excludes = Set(settings.excludedFoodNames.map { $0.lowercased() })
        let prefers = Set(settings.preferredFoodNames.map { $0.lowercased() })

        func allowed(_ food: CatalogFood) -> Bool {
            if excludes.contains(food.name.lowercased()) { return false }
            if food.phase == .week2Plus && phase == .week1 { return false }
            return true
        }

        func pool(category: FoodCategory) -> [CatalogFood] {
            let base = FoodCatalog.foods(category: category, phase: phase).filter(allowed)
            if prefers.isEmpty { return base }
            let preferred = base.filter { prefers.contains($0.name.lowercased()) }
            return preferred.isEmpty ? base : preferred
        }

        var components: [MealComponent] = []
        let budget = max(remainingProteinCalories, 70)
        let targetProtein = min(budget, max(budget / 3, 110))

        let proteins = pool(category: .protein)
        if let protein = pickProtein(from: proteins, targetCalories: targetProtein) {
            components.append(protein)
        }

        let veggies = pool(category: .vegetable).shuffled()
        for veg in veggies.prefix(2) {
            components.append(MealComponent(from: veg))
        }

        if phase.allowsFatsAndFruits {
            if let fat = pool(category: .fat).randomElement() {
                components.append(MealComponent(from: fat))
            }
            if let fruit = pool(category: .fruit).randomElement() {
                components.append(MealComponent(from: fruit))
            }
        }

        return components
    }

    private static func pickProtein(from foods: [CatalogFood], targetCalories: Int) -> MealComponent? {
        guard !foods.isEmpty else { return nil }
        let candidates = foods.shuffled()
        for food in candidates.prefix(12) {
            let unit: Int
            if let per = food.proteinCategory?.caloriesPerServing {
                unit = max(per, 1)
            } else {
                unit = max(food.calories, 1)
            }
            var servings = (Double(targetCalories) / Double(unit)).rounded()
            servings = max(1, min(servings, 12))
            // Prefer whole multipliers for oz-style proteins
            if food.servingLabel.contains("oz") {
                servings = max(1, (servings / 1).rounded())
            }
            return MealComponent(from: food, servings: servings)
        }
        return nil
    }
}

@MainActor
enum MealLogger {
    static func apply(
        components: [MealComponent],
        to log: DailyLog,
        settings: AppSettings
    ) {
        for component in components {
            switch component.category {
            case .protein:
                let servingText: String
                if abs(component.servings - 1) < 0.01 {
                    servingText = component.servingLabel
                } else {
                    servingText = String(format: "%.1f× %@", component.servings, component.servingLabel)
                }
                let category = component.proteinCategory ?? ProteinCategory.other.rawValue
                let entry = ProteinEntry(
                    name: component.name,
                    servingSize: servingText,
                    calories: component.totalCalories,
                    proteinCategory: category,
                    servings: component.servings,
                    hydrationOz: settings.suggestedHydrationOz(
                        forProteinCategory: category,
                        servings: component.servings
                    )
                )
                log.proteins.append(entry)
            case .vegetable:
                let raw = ChecklistStorage.encode(
                    name: component.name,
                    amount: component.amount ?? component.servingLabel
                )
                ChecklistStorage.appendUnique(raw, to: &log.checkedFatsAndVeggies)
            case .fat:
                let raw = ChecklistStorage.encode(
                    name: component.name,
                    amount: component.amount ?? component.servingLabel
                )
                ChecklistStorage.appendUnique(raw, to: &log.checkedFats)
            case .fruit:
                let raw = ChecklistStorage.encode(
                    name: component.name,
                    amount: component.amount ?? component.servingLabel
                )
                if !log.checkedFruits.contains(where: { ChecklistStorage.name(of: $0) == component.name }) {
                    log.checkedFruits.append(raw)
                }
            case .misc:
                guard log.checkedMiscItems.count < AppLimits.miscDailyLimit else { continue }
                let raw = ChecklistStorage.encode(
                    name: component.name,
                    amount: component.amount ?? component.servingLabel
                )
                if !log.checkedMiscItems.contains(where: { ChecklistStorage.name(of: $0) == component.name }) {
                    log.checkedMiscItems.append(raw)
                }
            }
        }
        _ = settings // phase already respected at build time
    }
}
