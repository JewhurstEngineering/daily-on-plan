import Foundation

struct EatingProteinRow: Identifiable, Hashable {
    let id: UUID
    let time: Date
    let name: String
    let servingSize: String
    let calories: Int
    let hydrationOz: Double
}

struct EatingChecklistRow: Identifiable, Hashable {
    var id: String { "\(category.rawValue)-\(name)-\(amount)" }
    let category: FoodCategory
    let name: String
    let amount: String

    var display: String {
        if amount.isEmpty { return name }
        return "\(name) · \(amount)"
    }

    var categoryLabel: String {
        switch category {
        case .vegetable: return "Veg"
        case .fat: return "Fat"
        case .fruit: return "Fruit"
        case .misc: return "Misc"
        case .protein: return "Protein"
        }
    }
}

struct EatingHydrationSlotRow: Identifiable, Hashable {
    let id: Int
    let oz: Double
    let isElectrolyte: Bool

    var amountLabel: String {
        oz == oz.rounded() ? String(format: "%.0f oz", oz) : String(format: "%.1f oz", oz)
    }

    var label: String {
        isElectrolyte ? "\(amountLabel) electrolyte" : amountLabel
    }
}

struct EatingHydrationGroup: Identifiable, Hashable {
    var id: String { "\(oz)-\(isElectrolyte)" }
    let count: Int
    let oz: Double
    let isElectrolyte: Bool

    var label: String {
        let amount = oz == oz.rounded() ? String(format: "%.0f oz", oz) : String(format: "%.1f oz", oz)
        let unit = isElectrolyte ? "\(amount) electrolyte" : amount
        if count <= 1 { return unit }
        return "\(count) × \(unit)"
    }
}

struct EatingDaySummary: Identifiable, Hashable {
    var id: Date { date }
    let date: Date
    let proteinCalories: Int
    let proteinGoal: Int
    let hydrationOz: Int
    let hydrationTargetOz: Int
    let proteinDrinkHydrationOz: Int
    let electrolyteDrinkCount: Int
    let proteins: [EatingProteinRow]
    let checklist: [EatingChecklistRow]
    let hydrationSlots: [EatingHydrationSlotRow]

    var formattedDay: String { DateHelpers.formattedDay(date) }

    var vegetableCount: Int {
        checklist.filter { $0.category == .vegetable }.count
    }

    var fatCount: Int {
        checklist.filter { $0.category == .fat }.count
    }

    var fruitCount: Int {
        checklist.filter { $0.category == .fruit }.count
    }

    var miscCount: Int {
        checklist.filter { $0.category == .misc }.count
    }

    var hasIntake: Bool {
        !proteins.isEmpty || !checklist.isEmpty || hydrationOz > 0
    }

    /// Bottles grouped by oz + electrolyte, e.g. "9 × 16.9 oz".
    var groupedHydrationSlots: [EatingHydrationGroup] {
        var order: [(oz: Double, isElectrolyte: Bool)] = []
        var counts: [String: Int] = [:]
        for slot in hydrationSlots {
            let key = "\(slot.oz)-\(slot.isElectrolyte)"
            if counts[key] == nil {
                order.append((slot.oz, slot.isElectrolyte))
            }
            counts[key, default: 0] += 1
        }
        return order.map { item in
            EatingHydrationGroup(
                count: counts["\(item.oz)-\(item.isElectrolyte)"] ?? 0,
                oz: item.oz,
                isElectrolyte: item.isElectrolyte
            )
        }
    }

    static func make(log: DailyLog, settings: AppSettings) -> EatingDaySummary {
        let proteins = log.sortedProteins.map { entry in
            EatingProteinRow(
                id: entry.id,
                time: entry.time,
                name: entry.name,
                servingSize: entry.servingSize,
                calories: entry.calories,
                hydrationOz: entry.hydrationOz
            )
        }

        var checklist: [EatingChecklistRow] = []
        for raw in log.checkedFatsAndVeggies {
            let parsed = ChecklistStorage.parse(raw)
            let category: FoodCategory
            if FoodCatalog.vegetables.contains(where: { $0.name == parsed.name }) {
                category = .vegetable
            } else if FoodCatalog.fats.contains(where: { $0.name == parsed.name }) {
                category = .fat
            } else {
                category = .misc
            }
            checklist.append(EatingChecklistRow(category: category, name: parsed.name, amount: parsed.amount))
        }
        for raw in log.checkedFruits {
            let parsed = ChecklistStorage.parse(raw)
            checklist.append(EatingChecklistRow(category: .fruit, name: parsed.name, amount: parsed.amount))
        }
        for raw in log.checkedMiscItems {
            let parsed = ChecklistStorage.parse(raw)
            checklist.append(EatingChecklistRow(category: .misc, name: parsed.name, amount: parsed.amount))
        }

        let filledSlots = log.waterSlots.compactMap { $0 }
        let hydrationSlots = filledSlots.enumerated().map { index, slot in
            EatingHydrationSlotRow(id: index, oz: slot.oz, isElectrolyte: slot.isElectrolyte)
        }

        return EatingDaySummary(
            date: DateHelpers.startOfDay(log.date),
            proteinCalories: log.totalProteinCalories,
            proteinGoal: log.proteinGoal,
            hydrationOz: log.totalHydrationOz(settings: settings),
            hydrationTargetOz: settings.hydrationTargetOz,
            proteinDrinkHydrationOz: log.proteinHydrationOz(settings: settings),
            electrolyteDrinkCount: log.electrolyteDrinkCount,
            proteins: proteins,
            checklist: checklist,
            hydrationSlots: hydrationSlots
        )
    }

    /// Days in the snapshot that have protein, checklist foods, or hydration.
    /// Falls back to all logged days if none qualify.
    static func daysWithIntake(from snapshot: ReportSnapshot) -> [EatingDaySummary] {
        let all = snapshot.logs
            .sorted { $0.date < $1.date }
            .map { make(log: $0, settings: snapshot.settings) }
        let withIntake = all.filter(\.hasIntake)
        return withIntake.isEmpty ? all : withIntake
    }
}

struct EatingWeekSummary: Identifiable, Hashable {
    var id: Date { weekStart }
    let weekStart: Date
    let weekEnd: Date
    let days: [EatingDaySummary]
    let avgProtein: Double
    let avgWater: Double
    let avgVeggiesPerDay: Double
    let topProteins: [NamedCount]

    var title: String {
        let start = weekStart.formatted(.dateTime.month(.abbreviated).day())
        let end = weekEnd.formatted(.dateTime.month(.abbreviated).day())
        return "\(start) – \(end)"
    }

    var loggedDays: Int { days.count }

    static func weeks(from days: [EatingDaySummary]) -> [EatingWeekSummary] {
        let calendar = Calendar.current
        guard !days.isEmpty else { return [] }

        var buckets: [Date: [EatingDaySummary]] = [:]
        for day in days {
            let weekStart = calendar.dateInterval(of: .weekOfYear, for: day.date)?.start
                ?? calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: day.date))
                ?? day.date
            let key = DateHelpers.startOfDay(weekStart)
            buckets[key, default: []].append(day)
        }

        return buckets.keys.sorted().map { weekStart -> EatingWeekSummary in
            let weekDays = (buckets[weekStart] ?? []).sorted { $0.date < $1.date }
            let weekEnd = calendar.date(byAdding: .day, value: 6, to: weekStart) ?? weekStart
            let count = Double(weekDays.count)
            let avgProtein = count == 0 ? 0 :
                Double(weekDays.reduce(0) { $0 + $1.proteinCalories }) / count
            let avgWater = count == 0 ? 0 :
                Double(weekDays.reduce(0) { $0 + $1.hydrationOz }) / count
            let avgVeggies = count == 0 ? 0 :
                Double(weekDays.reduce(0) { $0 + $1.vegetableCount }) / count

            var proteinCounts: [String: Int] = [:]
            for day in weekDays {
                for protein in day.proteins {
                    proteinCounts[protein.name, default: 0] += 1
                }
            }
            let topProteins = proteinCounts
                .map { NamedCount(name: $0.key, count: $0.value) }
                .sorted {
                    if $0.count == $1.count { return $0.name < $1.name }
                    return $0.count > $1.count
                }
                .prefix(3)
                .map { $0 }

            return EatingWeekSummary(
                weekStart: weekStart,
                weekEnd: weekEnd,
                days: weekDays,
                avgProtein: avgProtein,
                avgWater: avgWater,
                avgVeggiesPerDay: avgVeggies,
                topProteins: Array(topProteins)
            )
        }
    }
}
