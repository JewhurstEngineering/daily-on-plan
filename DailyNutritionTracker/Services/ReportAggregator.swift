import Foundation
import SwiftData

enum ReportRange: String, CaseIterable, Identifiable {
    case week7 = "7d"
    case days30 = "30d"
    case days90 = "90d"
    case custom = "Custom"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .week7: return "7 days"
        case .days30: return "30 days"
        case .days90: return "90 days"
        case .custom: return "Custom"
        }
    }

    func startDate(endingAt end: Date, customStart: Date?) -> Date {
        let endDay = DateHelpers.startOfDay(end)
        switch self {
        case .week7:
            return Calendar.current.date(byAdding: .day, value: -6, to: endDay) ?? endDay
        case .days30:
            return Calendar.current.date(byAdding: .day, value: -29, to: endDay) ?? endDay
        case .days90:
            return Calendar.current.date(byAdding: .day, value: -89, to: endDay) ?? endDay
        case .custom:
            return DateHelpers.startOfDay(customStart ?? endDay)
        }
    }
}

struct DailyMetricPoint: Identifiable {
    var id: Date { date }
    let date: Date
    let value: Double
    var label: String { date.formatted(.dateTime.month(.abbreviated).day()) }
}

struct NamedCount: Identifiable, Hashable {
    var id: String { name }
    let name: String
    let count: Int
}

enum HeatmapMetric: String, CaseIterable, Identifiable {
    case followedPlan
    case waterHit
    case proteinOnGoal
    case smokeFree
    case alcoholFree

    var id: String { rawValue }

    var title: String {
        switch self {
        case .followedPlan: return "Followed plan"
        case .waterHit: return "Water hit"
        case .proteinOnGoal: return "Protein ≤ goal"
        case .smokeFree: return "Smoke-free"
        case .alcoholFree: return "Alcohol-free"
        }
    }

    var shortTitle: String {
        switch self {
        case .followedPlan: return "Plan"
        case .waterHit: return "Water"
        case .proteinOnGoal: return "Protein"
        case .smokeFree: return "Smoke-free"
        case .alcoholFree: return "Alcohol-free"
        }
    }
}

struct HeatmapDay: Identifiable {
    var id: Date { date }
    let date: Date
    /// `nil` = no log that day; `true` = met; `false` = missed.
    let hit: Bool?
}

struct ReportSnapshot {
    let start: Date
    let end: Date
    let logs: [DailyLog]
    let weights: [WeightEntry]
    let bodyCompositions: [BodyCompositionReading]
    let measurements: [BodyMeasurementEntry]
    let settings: AppSettings

    var dayCount: Int {
        max(1, Calendar.current.dateComponents([.day], from: start, to: end).day.map { $0 + 1 } ?? logs.count)
    }

    // MARK: Protein

    var proteinSeries: [DailyMetricPoint] {
        logs.map { DailyMetricPoint(date: $0.date, value: Double($0.totalProteinCalories)) }
    }

    var proteinGoalSeries: [DailyMetricPoint] {
        logs.map { DailyMetricPoint(date: $0.date, value: Double($0.proteinGoal)) }
    }

    var avgProteinCalories: Double {
        guard !logs.isEmpty else { return 0 }
        return Double(logs.reduce(0) { $0 + $1.totalProteinCalories }) / Double(logs.count)
    }

    var daysOverProteinGoal: Int {
        logs.filter { $0.totalProteinCalories > $0.proteinGoal }.count
    }

    var topProteins: [NamedCount] {
        ranked(logs.flatMap(\.proteinEntries).map(\.name))
    }

    // MARK: Feelings

    var feelingCounts: [NamedCount] {
        ranked(logs.flatMap(\.feelingEntries).map(\.type))
    }

    var feelingsPerDay: [DailyMetricPoint] {
        logs.map { DailyMetricPoint(date: $0.date, value: Double($0.feelingEntries.count)) }
    }

    var totalFeelings: Int {
        logs.reduce(0) { $0 + $1.feelingEntries.count }
    }

    // MARK: Checklist

    var vegetableCounts: [NamedCount] {
        ranked(checklistNames(from: logs.flatMap { ChecklistStorage.vegetables(in: $0) }, category: .vegetable))
    }

    var fatCounts: [NamedCount] {
        ranked(checklistNames(from: logs.flatMap { ChecklistStorage.fats(in: $0) }, category: .fat))
    }

    var fruitCounts: [NamedCount] {
        ranked(checklistNames(from: logs.flatMap(\.checkedFruits), category: .fruit))
    }

    var miscCounts: [NamedCount] {
        ranked(logs.flatMap(\.checkedMiscItems).map { ChecklistStorage.name(of: $0) })
    }

    var veggiesPerDay: [DailyMetricPoint] {
        logs.map { log in
            DailyMetricPoint(date: log.date, value: Double(ChecklistStorage.vegetables(in: log).count))
        }
    }

    // MARK: Workouts

    var workoutMinutesSeries: [DailyMetricPoint] {
        logs.map { log in
            DailyMetricPoint(
                date: log.date,
                value: Double(log.workoutEntries.reduce(0) { $0 + $1.durationMinutes })
            )
        }
    }

    var workoutActivityCounts: [NamedCount] {
        ranked(logs.flatMap(\.workoutEntries).map(\.activityName))
    }

    var totalWorkoutMinutes: Int {
        logs.flatMap(\.workoutEntries).reduce(0) { $0 + $1.durationMinutes }
    }

    var totalWorkoutSessions: Int {
        logs.flatMap(\.workoutEntries).count
    }

    // MARK: Hydration

    var hydrationSeries: [DailyMetricPoint] {
        logs.map { DailyMetricPoint(date: $0.date, value: Double($0.totalHydrationOz(settings: settings))) }
    }

    var hydrationTarget: Double {
        Double(settings.hydrationTargetOz)
    }

    var daysAtHydrationTarget: Int {
        logs.filter { $0.totalHydrationOz(settings: settings) >= settings.hydrationTargetOz }.count
    }

    // MARK: Bathroom

    var urineSeries: [DailyMetricPoint] {
        logs.map { log in
            DailyMetricPoint(
                date: log.date,
                value: Double(log.bathroomEvents.filter { $0.kind == .urine }.count)
            )
        }
    }

    var stoolSeries: [DailyMetricPoint] {
        logs.map { log in
            DailyMetricPoint(
                date: log.date,
                value: Double(log.bathroomEvents.filter { $0.kind == .stool }.count)
            )
        }
    }

    var totalUrine: Int {
        logs.reduce(0) { $0 + $1.bathroomEvents.filter { $0.kind == .urine }.count }
    }

    var totalStool: Int {
        logs.reduce(0) { $0 + $1.bathroomEvents.filter { $0.kind == .stool }.count }
    }

    var daysWithBathroomLog: Int {
        logs.filter { !$0.bathroomEvents.isEmpty }.count
    }

    var showsBathroomReport: Bool {
        settings.showBathroomSection || totalUrine > 0 || totalStool > 0
    }

    // MARK: Weight

    var weightSeries: [DailyMetricPoint] {
        weights.map {
            let value = settings.usesMetricWeight ? $0.weightLbs * 0.453592 : $0.weightLbs
            return DailyMetricPoint(date: $0.date, value: value)
        }
    }

    var weightDelta: Double? {
        guard let first = weights.first, let last = weights.last, weights.count > 1 else { return nil }
        let delta = last.weightLbs - first.weightLbs
        return settings.usesMetricWeight ? delta * 0.453592 : delta
    }

    var latestBMI: Double? {
        guard let last = weights.last else { return nil }
        return BMICalculator.bmi(weightLbs: last.weightLbs, heightInches: settings.heightInches)
    }

    var goalWeightDisplay: Double? {
        guard let goal = settings.goalWeightLbs else { return nil }
        return settings.usesMetricWeight ? goal * 0.453592 : goal
    }

    var latestWeightDisplay: Double? {
        guard let last = weights.last else { return nil }
        return settings.usesMetricWeight ? last.weightLbs * 0.453592 : last.weightLbs
    }

    /// Latest weight minus goal (positive = still above goal).
    var weightToGoDisplay: Double? {
        guard let goal = settings.goalWeightLbs, let last = weights.last else { return nil }
        let delta = last.weightLbs - goal
        return settings.usesMetricWeight ? delta * 0.453592 : delta
    }

    // MARK: Body composition

    var fatPercentSeries: [DailyMetricPoint] {
        bodyCompositions.map { DailyMetricPoint(date: $0.date, value: $0.fatPercent) }
    }

    var bodyCompWeightSeries: [DailyMetricPoint] {
        bodyCompositions.map {
            let value = settings.usesMetricWeight ? $0.weightLbs * 0.453592 : $0.weightLbs
            return DailyMetricPoint(date: $0.date, value: value)
        }
    }

    var latestFatPercent: Double? {
        bodyCompositions.last.map(\.fatPercent)
    }

    var latestBodyCompBMI: Double? {
        bodyCompositions.last.map(\.bmi)
    }

    var latestBodyCompWeightDisplay: Double? {
        guard let last = bodyCompositions.last else { return nil }
        return settings.usesMetricWeight ? last.weightLbs * 0.453592 : last.weightLbs
    }

    var latestFatMassDisplay: Double? {
        guard let last = bodyCompositions.last else { return nil }
        return settings.usesMetricWeight ? last.fatMassLbs * 0.453592 : last.fatMassLbs
    }

    // MARK: Tape measurements

    var waistSeries: [DailyMetricPoint] {
        measurements.compactMap { entry in
            guard let waist = entry.waistInches else { return nil }
            let value = settings.usesMetricWeight ? waist * 2.54 : waist
            return DailyMetricPoint(date: entry.date, value: value)
        }
    }

    var neckSeries: [DailyMetricPoint] {
        measurements.compactMap { entry in
            guard let neck = entry.neckInches else { return nil }
            let value = settings.usesMetricWeight ? neck * 2.54 : neck
            return DailyMetricPoint(date: entry.date, value: value)
        }
    }

    var latestWaistDisplay: Double? {
        guard let waist = measurements.last(where: { $0.waistInches != nil })?.waistInches else { return nil }
        return settings.usesMetricWeight ? waist * 2.54 : waist
    }

    var latestMeasurementSummary: String? {
        measurements.last.map { $0.summaryLine(usesMetric: settings.usesMetricWeight) }
    }

    // MARK: Smoking

    var cigaretteSeries: [DailyMetricPoint] {
        logs.map { DailyMetricPoint(date: $0.date, value: Double($0.cigarettesSmoked)) }
    }

    var totalCigarettes: Int {
        logs.reduce(0) { $0 + $1.cigarettesSmoked }
    }

    var avgCigarettesPerDay: Double {
        guard !logs.isEmpty else { return 0 }
        return Double(totalCigarettes) / Double(logs.count)
    }

    var daysUnderCigaretteLimit: Int {
        guard let limit = settings.effectiveDailyCigaretteLimit else { return 0 }
        return logs.filter { $0.cigarettesSmoked <= limit }.count
    }

    var smokeFreeDaysInRange: Int {
        logs.filter { $0.cigarettesSmoked == 0 }.count
    }

    var totalUrges: Int {
        logs.reduce(0) { $0 + $1.cigaretteUrges.count }
    }

    var showsSmokingReport: Bool {
        settings.smokingMode.showsSection || totalCigarettes > 0 || totalUrges > 0
    }

    // MARK: Drinking

    var drinkSeries: [DailyMetricPoint] {
        logs.map { DailyMetricPoint(date: $0.date, value: Double($0.drinksLogged)) }
    }

    var totalDrinks: Int {
        logs.reduce(0) { $0 + $1.drinksLogged }
    }

    var avgDrinksPerDay: Double {
        guard !logs.isEmpty else { return 0 }
        return Double(totalDrinks) / Double(logs.count)
    }

    var daysUnderDrinkLimit: Int {
        guard let limit = settings.effectiveDailyDrinkLimit else { return 0 }
        return logs.filter { $0.drinksLogged <= limit }.count
    }

    var alcoholFreeDaysInRange: Int {
        logs.filter { $0.drinksLogged == 0 }.count
    }

    var totalDrinkUrges: Int {
        logs.reduce(0) { $0 + $1.drinkUrges.count }
    }

    var showsDrinkingReport: Bool {
        settings.drinkingMode.showsSection || totalDrinks > 0 || totalDrinkUrges > 0
    }

    // MARK: Supplements

    struct SupplementAdherence: Identifiable {
        var id: String { name }
        let name: String
        let completed: Int
        let possible: Int
        var percent: Double {
            guard possible > 0 else { return 0 }
            return Double(completed) / Double(possible) * 100
        }
    }

    var supplementAdherence: [SupplementAdherence] {
        settings.supplements.map { def in
            var completed = 0
            var possible = 0
            for log in logs {
                possible += def.dosesPerDay
                for i in 0..<def.dosesPerDay {
                    if log.completedSupplements.contains(def.doseKey(i)) {
                        completed += 1
                    }
                }
            }
            return SupplementAdherence(name: def.name, completed: completed, possible: possible)
        }
        .sorted { $0.percent > $1.percent }
    }

    var overallSupplementAdherencePercent: Double {
        let items = supplementAdherence
        let possible = items.reduce(0) { $0 + $1.possible }
        guard possible > 0 else { return 0 }
        let completed = items.reduce(0) { $0 + $1.completed }
        return Double(completed) / Double(possible) * 100
    }

    // MARK: Average day / Snapshot

    var avgWaterOz: Double {
        guard !logs.isEmpty else { return 0 }
        return Double(logs.reduce(0) { $0 + $1.totalHydrationOz(settings: settings) }) / Double(logs.count)
    }

    var avgFeelingsPerDay: Double {
        guard !logs.isEmpty else { return 0 }
        return Double(totalFeelings) / Double(logs.count)
    }

    var avgVeggiesPerDay: Double {
        guard !logs.isEmpty else { return 0 }
        let total = veggiesPerDay.reduce(0.0) { $0 + $1.value }
        return total / Double(logs.count)
    }

    var avgWorkoutMinutesPerDay: Double {
        guard !logs.isEmpty else { return 0 }
        return Double(totalWorkoutMinutes) / Double(logs.count)
    }

    var avgProteinGoal: Double {
        guard !logs.isEmpty else { return Double(settings.defaultProteinGoal) }
        return Double(logs.reduce(0) { $0 + $1.proteinGoal }) / Double(logs.count)
    }

    var daysOnProteinGoal: Int {
        logs.filter { $0.totalProteinCalories > 0 && $0.totalProteinCalories <= $0.proteinGoal }.count
    }

    var planFollowRate: Double {
        guard !logs.isEmpty else { return 0 }
        let followed = logs.filter(\.followedPlan).count
        return Double(followed) / Double(logs.count) * 100
    }

    var ketosisRate: Double {
        guard !logs.isEmpty else { return 0 }
        let yes = logs.filter(\.ketosis).count
        return Double(yes) / Double(logs.count) * 100
    }

    var offPlanDays: Int {
        logs.filter { !$0.followedPlan }.count
    }

    /// How often each off-plan reason was tagged (a day can contribute to multiple reasons).
    var offPlanReasonCounts: [NamedCount] {
        var counts: [String: Int] = [:]
        for log in logs where !log.followedPlan {
            for reason in log.offPlanReasons {
                counts[reason, default: 0] += 1
            }
        }
        return counts
            .map { NamedCount(name: $0.key, count: $0.value) }
            .sorted {
                if $0.count == $1.count {
                    return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
                }
                return $0.count > $1.count
            }
    }

    var hydrationHitRate: Double {
        guard !logs.isEmpty else { return 0 }
        return Double(daysAtHydrationTarget) / Double(logs.count) * 100
    }

    // MARK: Heatmaps & streaks

    var availableHeatmapMetrics: [HeatmapMetric] {
        var metrics: [HeatmapMetric] = [.followedPlan, .waterHit, .proteinOnGoal]
        if settings.smokingMode.showsSection || smokeFreeDaysInRange > 0 || totalCigarettes > 0 {
            metrics.append(.smokeFree)
        }
        if settings.drinkingMode.showsSection || alcoholFreeDaysInRange > 0 || totalDrinks > 0 {
            metrics.append(.alcoholFree)
        }
        return metrics
    }

    func heatmapDays(for metric: HeatmapMetric) -> [HeatmapDay] {
        let calendar = Calendar.current
        let byDay = Dictionary(uniqueKeysWithValues: logs.map { (DateHelpers.startOfDay($0.date), $0) })
        var days: [HeatmapDay] = []
        var cursor = DateHelpers.startOfDay(start)
        let endDay = DateHelpers.startOfDay(end)
        while cursor <= endDay {
            let log = byDay[cursor]
            let hit: Bool?
            if let log {
                switch metric {
                case .followedPlan:
                    hit = log.followedPlan
                case .waterHit:
                    hit = log.totalHydrationOz(settings: settings) >= settings.hydrationTargetOz
                case .proteinOnGoal:
                    hit = log.totalProteinCalories > 0 && log.totalProteinCalories <= log.proteinGoal
                case .smokeFree:
                    hit = log.cigarettesSmoked == 0
                case .alcoholFree:
                    hit = log.drinksLogged == 0
                }
            } else {
                hit = nil
            }
            days.append(HeatmapDay(date: cursor, hit: hit))
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }
        return days
    }

    var currentPlanFollowStreak: Int {
        trailingStreak(from: end) { $0.followedPlan }
    }

    var currentSmokeFreeStreak: Int {
        SmokingSection.trailingSmokeFreeDays(
            from: end,
            logs: logs,
            quitDate: settings.quitDate
        )
    }

    var currentAlcoholFreeStreak: Int {
        DrinkingSection.trailingAlcoholFreeDays(
            from: end,
            logs: logs,
            quitDate: settings.alcoholQuitDate
        )
    }

    var logForEndDate: DailyLog? {
        let day = DateHelpers.startOfDay(end)
        return logs.first { DateHelpers.startOfDay($0.date) == day }
    }

    var weightForEndDate: WeightEntry? {
        let day = DateHelpers.startOfDay(end)
        return weights.first { DateHelpers.startOfDay($0.date) == day } ?? weights.last
    }

    private func trailingStreak(from day: Date, matches: (DailyLog) -> Bool) -> Int {
        let byDay = Dictionary(uniqueKeysWithValues: logs.map { (DateHelpers.startOfDay($0.date), $0) })
        var cursor = DateHelpers.startOfDay(day)
        var streak = 0
        while let log = byDay[cursor] {
            guard matches(log) else { break }
            streak += 1
            guard let previous = Calendar.current.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }
        return streak
    }

    // MARK: Weekly rollups

    struct WeekRollup: Identifiable {
        var id: Date { weekStart }
        let weekStart: Date
        let weekEnd: Date
        let loggedDays: Int
        let avgProtein: Double
        let avgWater: Double
        let totalFeelings: Int
        let totalWorkoutMinutes: Int
        let daysAtWaterTarget: Int
        let daysOnProteinGoal: Int
        let planFollowDays: Int
        let proteinSpark: [DailyMetricPoint]
        let waterSpark: [DailyMetricPoint]

        var title: String {
            let start = weekStart.formatted(.dateTime.month(.abbreviated).day())
            let end = weekEnd.formatted(.dateTime.month(.abbreviated).day())
            return "\(start) – \(end)"
        }

        var onTrackScore: Int {
            // Simple composite: protein-on-goal days + water-hit days (higher is better)
            daysOnProteinGoal + daysAtWaterTarget
        }
    }

    var weeklyRollups: [WeekRollup] {
        let calendar = Calendar.current
        guard !logs.isEmpty else { return [] }

        var buckets: [Date: [DailyLog]] = [:]
        for log in logs {
            let weekStart = calendar.dateInterval(of: .weekOfYear, for: log.date)?.start
                ?? calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: log.date))
                ?? log.date
            let key = DateHelpers.startOfDay(weekStart)
            buckets[key, default: []].append(log)
        }

        let target = settings.hydrationTargetOz
        return buckets.keys.sorted().map { weekStart -> WeekRollup in
            let weekLogs = (buckets[weekStart] ?? []).sorted { $0.date < $1.date }
            let weekEnd = calendar.date(byAdding: .day, value: 6, to: weekStart) ?? weekStart
            let avgProtein = weekLogs.isEmpty ? 0 :
                Double(weekLogs.reduce(0) { $0 + $1.totalProteinCalories }) / Double(weekLogs.count)
            let avgWater = weekLogs.isEmpty ? 0 :
                Double(weekLogs.reduce(0) { $0 + $1.totalHydrationOz(settings: settings) }) / Double(weekLogs.count)
            return WeekRollup(
                weekStart: weekStart,
                weekEnd: weekEnd,
                loggedDays: weekLogs.count,
                avgProtein: avgProtein,
                avgWater: avgWater,
                totalFeelings: weekLogs.reduce(0) { $0 + $1.feelingEntries.count },
                totalWorkoutMinutes: weekLogs.flatMap(\.workoutEntries).reduce(0) { $0 + $1.durationMinutes },
                daysAtWaterTarget: weekLogs.filter { $0.totalHydrationOz(settings: settings) >= target }.count,
                daysOnProteinGoal: weekLogs.filter {
                    $0.totalProteinCalories > 0 && $0.totalProteinCalories <= $0.proteinGoal
                }.count,
                planFollowDays: weekLogs.filter(\.followedPlan).count,
                proteinSpark: weekLogs.map {
                    DailyMetricPoint(date: $0.date, value: Double($0.totalProteinCalories))
                },
                waterSpark: weekLogs.map {
                    DailyMetricPoint(date: $0.date, value: Double($0.waterOz))
                }
            )
        }
    }

    var bestWeek: WeekRollup? {
        weeklyRollups.max { lhs, rhs in
            if lhs.onTrackScore == rhs.onTrackScore {
                return lhs.planFollowDays < rhs.planFollowDays
            }
            return lhs.onTrackScore < rhs.onTrackScore
        }
    }

    var toughestWeek: WeekRollup? {
        guard weeklyRollups.count > 1 else { return weeklyRollups.first }
        return weeklyRollups.max { lhs, rhs in
            if lhs.totalFeelings == rhs.totalFeelings {
                return lhs.onTrackScore > rhs.onTrackScore
            }
            return lhs.totalFeelings < rhs.totalFeelings
        }
    }

    // MARK: Helpers

    private func ranked(_ names: [String], limit: Int = 8) -> [NamedCount] {
        var counts: [String: Int] = [:]
        for name in names { counts[name, default: 0] += 1 }
        return counts
            .map { NamedCount(name: $0.key, count: $0.value) }
            .sorted {
                if $0.count == $1.count { return $0.name < $1.name }
                return $0.count > $1.count
            }
            .prefix(limit)
            .map { $0 }
    }

    private func checklistNames(from raws: [String], category: FoodCategory) -> [String] {
        raws.compactMap { raw in
            let name = ChecklistStorage.name(of: raw)
            switch category {
            case .vegetable:
                return FoodCatalog.vegetables.contains(where: { $0.name == name }) ? name : nil
            case .fat:
                return FoodCatalog.fats.contains(where: { $0.name == name }) ? name : nil
            case .fruit:
                return FoodCatalog.fruits.contains(where: { $0.name == name }) ? name : nil
            default:
                return name
            }
        }
    }
}

enum ReportAggregator {
    @MainActor
    static func snapshot(
        range: ReportRange,
        endDate: Date,
        customStart: Date?,
        in context: ModelContext
    ) -> ReportSnapshot {
        let settings = DataStore.settings(in: context)
        let end = DateHelpers.startOfDay(endDate)
        let start = range.startDate(endingAt: end, customStart: customStart)
        let logs = DataStore.logs(from: start, to: end, in: context)
        let weights = DataStore.recentWeights(limit: 200, in: context)
            .filter { $0.date >= start && $0.date <= end }
            .sorted { $0.date < $1.date }
        let bodyCompositions = DataStore.bodyCompositions(from: start, to: end, in: context)
        let measurements = DataStore.bodyMeasurements(from: start, to: end, in: context)
        return ReportSnapshot(
            start: start,
            end: end,
            logs: logs,
            weights: weights,
            bodyCompositions: bodyCompositions,
            measurements: measurements,
            settings: settings
        )
    }
}
