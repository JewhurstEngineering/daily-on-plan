import Foundation
import SwiftData

struct SupplementDoseSnapshot: Codable, Hashable, Identifiable {
    var id: String
    var name: String
    var completed: Int
    var dosesPerDay: Int

    var isComplete: Bool { completed >= dosesPerDay }
}

struct DaySnapshot: Codable, Hashable {
    var proteinCalories: Int
    var proteinGoal: Int
    var proteinEntryCount: Int

    var waterOz: Int
    var waterTargetOz: Int
    var bottleOz: Double
    var electrolyteCount: Int

    var cigarettes: Int
    var cigaretteLimit: Int
    var smokingEnabled: Bool
    var smokingModeRaw: String

    var drinks: Int
    var drinkLimit: Int
    var drinkingEnabled: Bool
    var drinkingModeRaw: String

    var urineCount: Int
    var stoolCount: Int
    var bathroomEnabled: Bool

    var weightLbs: Double?
    var priorWeightLbs: Double?
    var heightInches: Double
    var goalWeightLbs: Double

    var workoutCount: Int
    var workoutMinutes: Int
    var lastWorkoutName: String?

    var feelingCount: Int
    var lastFeelingName: String?

    var vegCount: Int
    var fatCount: Int
    var fruitCount: Int
    var miscCount: Int
    var fatsAndVeggiesCount: Int

    var supplementsEnabled: Bool
    var supplementDosesCompleted: Int
    var supplementDosesTotal: Int
    var supplements: [SupplementDoseSnapshot]

    var followedPlan: Bool
    var ketosis: Bool
    var hasLog: Bool

    static let empty = DaySnapshot(
        proteinCalories: 0,
        proteinGoal: 500,
        proteinEntryCount: 0,
        waterOz: 0,
        waterTargetOz: AppLimits.hydrationTargetOz,
        bottleOz: AppLimits.defaultBottleOz,
        electrolyteCount: 0,
        cigarettes: 0,
        cigaretteLimit: AppLimits.defaultDailyCigaretteLimit,
        smokingEnabled: false,
        smokingModeRaw: SmokingMode.off.rawValue,
        drinks: 0,
        drinkLimit: AppLimits.defaultDailyDrinkLimit,
        drinkingEnabled: false,
        drinkingModeRaw: DrinkingMode.off.rawValue,
        urineCount: 0,
        stoolCount: 0,
        bathroomEnabled: true,
        weightLbs: nil,
        priorWeightLbs: nil,
        heightInches: 0,
        goalWeightLbs: 0,
        workoutCount: 0,
        workoutMinutes: 0,
        lastWorkoutName: nil,
        feelingCount: 0,
        lastFeelingName: nil,
        vegCount: 0,
        fatCount: 0,
        fruitCount: 0,
        miscCount: 0,
        fatsAndVeggiesCount: 0,
        supplementsEnabled: true,
        supplementDosesCompleted: 0,
        supplementDosesTotal: 0,
        supplements: [],
        followedPlan: true,
        ketosis: true,
        hasLog: false
    )

    var proteinFraction: Double {
        guard proteinGoal > 0 else { return 0 }
        return min(1, Double(proteinCalories) / Double(proteinGoal))
    }

    var waterFraction: Double {
        guard waterTargetOz > 0 else { return 0 }
        return min(1, Double(waterOz) / Double(waterTargetOz))
    }

    var supplementFraction: Double {
        guard supplementDosesTotal > 0 else { return 0 }
        return min(1, Double(supplementDosesCompleted) / Double(supplementDosesTotal))
    }

    var bathroomTotal: Int { urineCount + stoolCount }

    var weightDeltaLbs: Double? {
        guard let weightLbs, let priorWeightLbs else { return nil }
        return weightLbs - priorWeightLbs
    }

    var bmi: Double? {
        guard let weightLbs, heightInches > 0 else { return nil }
        return (weightLbs / (heightInches * heightInches)) * 703
    }

    var checklistTotal: Int { fatsAndVeggiesCount + fruitCount + miscCount }

    var bottleLabel: String {
        if bottleOz == bottleOz.rounded() { return "\(Int(bottleOz))" }
        return String(format: "%.1f", bottleOz)
    }
}

enum DaySnapshotReader {
    @MainActor
    static func today() -> DaySnapshot {
        do {
            let container = try SharedModelContainer.shared()
            let context = ModelContext(container)
            let settings = DataStore.settings(in: context)
            let log = DataStore.existingLog(for: Date(), in: context)
            let todayWeight = DataStore.weight(for: Date(), in: context)
            let recent = DataStore.recentWeights(limit: 8, in: context)
            let prior = recent.first(where: {
                !Calendar.current.isDate($0.date, inSameDayAs: Date())
            })

            let visible = settings.visibleSupplements
            var supplementSnapshots: [SupplementDoseSnapshot] = []
            var done = 0
            var total = 0
            if let log {
                for def in visible {
                    let completed = (0..<def.dosesPerDay)
                        .filter { log.completedSupplements.contains(def.doseKey($0)) }
                        .count
                    done += completed
                    total += def.dosesPerDay
                    supplementSnapshots.append(
                        SupplementDoseSnapshot(
                            id: def.id,
                            name: def.name,
                            completed: completed,
                            dosesPerDay: def.dosesPerDay
                        )
                    )
                }
            } else {
                for def in visible {
                    total += def.dosesPerDay
                    supplementSnapshots.append(
                        SupplementDoseSnapshot(
                            id: def.id,
                            name: def.name,
                            completed: 0,
                            dosesPerDay: def.dosesPerDay
                        )
                    )
                }
            }

            let workouts = log?.sortedWorkouts ?? []
            let feelings = log?.sortedFeelings ?? []

            return DaySnapshot(
                proteinCalories: log?.totalProteinCalories ?? 0,
                proteinGoal: log?.proteinGoal ?? settings.defaultProteinGoal,
                proteinEntryCount: log?.proteinEntries.count ?? 0,
                waterOz: log?.totalHydrationOz(settings: settings) ?? 0,
                waterTargetOz: settings.hydrationTargetOz,
                bottleOz: max(settings.defaultBottleOz, 1),
                electrolyteCount: log?.electrolyteDrinkCount ?? 0,
                cigarettes: log?.cigarettesSmoked ?? 0,
                cigaretteLimit: settings.dailyCigaretteLimit,
                smokingEnabled: settings.smokingMode.showsSection,
                smokingModeRaw: settings.smokingMode.rawValue,
                drinks: log?.drinksLogged ?? 0,
                drinkLimit: settings.dailyDrinkLimit,
                drinkingEnabled: settings.drinkingMode.showsSection,
                drinkingModeRaw: settings.drinkingMode.rawValue,
                urineCount: log?.urineCount ?? 0,
                stoolCount: log?.stoolCount ?? 0,
                bathroomEnabled: settings.showBathroomSection,
                weightLbs: todayWeight?.weightLbs,
                priorWeightLbs: prior?.weightLbs,
                heightInches: settings.heightInches,
                goalWeightLbs: settings.goalWeightLbs ?? 0,
                workoutCount: workouts.count,
                workoutMinutes: workouts.reduce(0) { $0 + $1.durationMinutes },
                lastWorkoutName: workouts.last?.activityName,
                feelingCount: feelings.count,
                lastFeelingName: feelings.last?.type,
                vegCount: 0,
                fatCount: 0,
                fruitCount: log?.checkedFruits.count ?? 0,
                miscCount: log?.checkedMiscItems.count ?? 0,
                fatsAndVeggiesCount: (log?.checkedFatsAndVeggies.count ?? 0) + (log?.checkedFats.count ?? 0),
                supplementsEnabled: settings.showSupplementsSection,
                supplementDosesCompleted: done,
                supplementDosesTotal: total,
                supplements: supplementSnapshots,
                followedPlan: log?.followedPlan ?? true,
                ketosis: log?.ketosis ?? true,
                hasLog: log != nil
            )
        } catch {
            return .empty
        }
    }
}

enum WidgetSnapshotAccess {
    static func read() -> DaySnapshot {
        if Thread.isMainThread {
            return MainActor.assumeIsolated { DaySnapshotReader.today() }
        }
        return DispatchQueue.main.sync {
            MainActor.assumeIsolated { DaySnapshotReader.today() }
        }
    }
}
