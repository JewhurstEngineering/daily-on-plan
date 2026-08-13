import Foundation
import OnPlanCore

enum ChromeSnapshotBuilder {
    @MainActor
    static func fromToday() -> ChromeSnapshot {
        from(DaySnapshotReader.today())
    }

    static func from(_ day: DaySnapshot) -> ChromeSnapshot {
        ChromeSnapshot(
            generatedAt: Date(),
            followedPlan: day.followedPlan,
            ketosis: day.ketosis,
            proteinCalories: day.proteinCalories,
            proteinGoal: day.proteinGoal,
            waterOz: day.waterOz,
            waterTargetOz: day.waterTargetOz,
            bottleOz: day.bottleOz,
            cigarettes: day.cigarettes,
            drinks: day.drinks,
            urineCount: day.urineCount,
            stoolCount: day.stoolCount,
            smokingEnabled: day.smokingEnabled,
            drinkingEnabled: day.drinkingEnabled,
            bathroomEnabled: day.bathroomEnabled
        )
    }
}
