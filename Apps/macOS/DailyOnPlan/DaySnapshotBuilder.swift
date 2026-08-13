import Foundation
import SwiftData
import OnPlanCore

enum DaySnapshotBuilder {
    @MainActor
    static func build(in context: ModelContext, date: Date = Date()) -> ChromeSnapshot {
        let settings = DataStore.existingSettings(in: context)
        let log = DataStore.existingLog(for: date, in: context)
        let waterOz: Int
        if let log, let settings {
            waterOz = log.totalHydrationOz(settings: settings)
        } else {
            waterOz = log?.slotWaterOz ?? 0
        }
        return ChromeSnapshot(
            generatedAt: Date(),
            followedPlan: log?.followedPlan ?? true,
            ketosis: log?.ketosis ?? true,
            proteinCalories: log?.totalProteinCalories ?? 0,
            proteinGoal: log?.proteinGoal ?? settings?.defaultProteinGoal ?? 500,
            waterOz: waterOz,
            waterTargetOz: settings?.hydrationTargetOz ?? AppLimits.hydrationTargetOz,
            bottleOz: max(settings?.defaultBottleOz ?? AppLimits.defaultBottleOz, 1),
            cigarettes: log?.cigarettesSmoked ?? 0,
            drinks: log?.drinksLogged ?? 0,
            urineCount: log?.urineCount ?? 0,
            stoolCount: log?.stoolCount ?? 0,
            smokingEnabled: settings?.smokingMode.showsSection ?? false,
            drinkingEnabled: settings?.drinkingMode.showsSection ?? false,
            bathroomEnabled: settings?.showBathroomSection ?? true
        )
    }
}
