import Foundation
import SwiftData
import OnPlanCore

enum DaySnapshotBuilder {
    @MainActor
    static func build(in context: ModelContext, date: Date = Date()) -> ChromeSnapshot {
        let settings = DataStore.settings(in: context)
        let log = DataStore.log(for: date, in: context, defaultGoal: settings.defaultProteinGoal)
        return ChromeSnapshot(
            generatedAt: Date(),
            followedPlan: log.followedPlan,
            ketosis: log.ketosis,
            proteinCalories: log.totalProteinCalories,
            proteinGoal: log.proteinGoal,
            waterOz: log.totalHydrationOz(settings: settings),
            waterTargetOz: settings.hydrationTargetOz,
            bottleOz: max(settings.defaultBottleOz, 1),
            cigarettes: log.cigarettesSmoked,
            drinks: log.drinksLogged,
            urineCount: log.urineCount,
            stoolCount: log.stoolCount,
            smokingEnabled: settings.smokingMode.showsSection,
            drinkingEnabled: settings.drinkingMode.showsSection,
            bathroomEnabled: settings.showBathroomSection
        )
    }
}
