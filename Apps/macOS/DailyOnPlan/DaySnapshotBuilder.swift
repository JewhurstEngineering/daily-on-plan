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
        let rangeStart = Calendar.current.date(byAdding: .day, value: -60, to: date) ?? date
        let logs = DataStore.logs(from: rangeStart, to: date, in: context)
        let previous = DataStore.existingLog(
            for: Calendar.current.date(byAdding: .day, value: -1, to: date) ?? date,
            in: context
        )
        let bits: (enabled: Bool, start: Date?, end: Date?, hours: Double, streak: Int, line: String)
        if let settings {
            bits = FastingMath.snapshotBits(today: log, previous: previous, logs: logs, settings: settings)
        } else {
            bits = (false, log?.eatingWindowStart, log?.eatingWindowEnd, 16, 0, "")
        }
        return ChromeSnapshot(
            generatedAt: Date(),
            followedPlan: log?.followedPlan ?? false,
            ketosis: log?.ketosis ?? false,
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
            bathroomEnabled: settings?.showBathroomSection ?? true,
            fastingEnabled: bits.enabled,
            eatingWindowStart: bits.start,
            eatingWindowEnd: bits.end,
            fastingTargetHours: bits.hours,
            fastingStreak: bits.streak,
            fastingStatusLine: bits.line
        )
    }
}
