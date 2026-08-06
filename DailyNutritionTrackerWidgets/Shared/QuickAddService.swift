import Foundation
import SwiftData

/// Shared quick-add writes used by widgets and the Watch phone bridge.
@MainActor
enum QuickAddService {
    enum Result {
        case success(message: String)
        case failure(message: String)
    }

    static func context() throws -> (ModelContext, AppSettings, DailyLog) {
        let container = try SharedModelContainer.shared()
        let context = ModelContext(container)
        let settings = DataStore.settings(in: context)
        let log = DataStore.log(for: Date(), in: context, defaultGoal: settings.defaultProteinGoal)
        return (context, settings, log)
    }

    static func addWaterBottle() -> Result {
        do {
            let (context, settings, log) = try context()
            let bottle = max(settings.defaultBottleOz, 1)
            let minimumSlots = max(1, Int(ceil(Double(settings.hydrationTargetOz) / bottle)))
            log.fillNextWaterSlot(oz: bottle, ensuringMinimumSlots: minimumSlots)
            try context.save()
            notifySideEffects()
            let label = bottle == bottle.rounded() ? "\(Int(bottle))" : String(format: "%.1f", bottle)
            return .success(message: "Logged \(label) oz of water.")
        } catch {
            return .failure(message: error.localizedDescription)
        }
    }

    static func addCigarette() -> Result {
        do {
            let (context, settings, log) = try context()
            guard settings.smokingMode.showsSection else {
                return .failure(message: "Smoking tracking is turned off.")
            }
            log.addCigarette()
            try context.save()
            notifySideEffects()
            return .success(message: "Logged 1 cigarette.")
        } catch {
            return .failure(message: error.localizedDescription)
        }
    }

    static func addDrinks(_ count: Int = 1) -> Result {
        do {
            let (context, settings, log) = try context()
            guard settings.drinkingMode.showsSection else {
                return .failure(message: "Drinking tracking is turned off.")
            }
            let n = max(1, min(count, 10))
            log.addDrinks(n)
            try context.save()
            notifySideEffects()
            return .success(message: n == 1 ? "Logged 1 drink." : "Logged \(n) drinks.")
        } catch {
            return .failure(message: error.localizedDescription)
        }
    }

    static func addBathroom(kind: BathroomKind) -> Result {
        do {
            let (context, _, log) = try context()
            _ = log.addBathroomEvent(kind: kind)
            try context.save()
            notifySideEffects()
            return .success(message: "Logged \(kind.shortTitle.lowercased()).")
        } catch {
            return .failure(message: error.localizedDescription)
        }
    }

    static func addSmokeUrge() -> Result {
        do {
            let (context, settings, log) = try context()
            guard settings.smokingMode.showsSection else {
                return .failure(message: "Smoking tracking is turned off.")
            }
            log.addUrge()
            try context.save()
            notifySideEffects()
            return .success(message: "Logged a smoking urge.")
        } catch {
            return .failure(message: error.localizedDescription)
        }
    }

    static func addDrinkUrge() -> Result {
        do {
            let (context, settings, log) = try context()
            guard settings.drinkingMode.showsSection else {
                return .failure(message: "Drinking tracking is turned off.")
            }
            log.addDrinkUrge()
            try context.save()
            notifySideEffects()
            return .success(message: "Logged a drink urge.")
        } catch {
            return .failure(message: error.localizedDescription)
        }
    }

    static func markNextSupplement() -> Result {
        do {
            let (context, settings, log) = try context()
            guard settings.showSupplementsSection else {
                return .failure(message: "Supplements are hidden.")
            }
            for def in settings.visibleSupplements {
                for index in 0..<def.dosesPerDay {
                    let key = def.doseKey(index)
                    if !log.completedSupplements.contains(key) {
                        log.completedSupplements.append(key)
                        try context.save()
                        notifySideEffects()
                        return .success(message: "Marked \(def.name) dose \(index + 1).")
                    }
                }
            }
            return .success(message: "All supplement doses are done today.")
        } catch {
            return .failure(message: error.localizedDescription)
        }
    }

    static func toggleFollowedPlan() -> Result {
        do {
            let (context, _, log) = try context()
            log.followedPlan.toggle()
            try context.save()
            notifySideEffects()
            return .success(message: log.followedPlan ? "Marked on plan." : "Marked off plan.")
        } catch {
            return .failure(message: error.localizedDescription)
        }
    }

    static func toggleKetosis() -> Result {
        do {
            let (context, _, log) = try context()
            log.ketosis.toggle()
            try context.save()
            notifySideEffects()
            return .success(message: log.ketosis ? "Marked in ketosis." : "Marked not in ketosis.")
        } catch {
            return .failure(message: error.localizedDescription)
        }
    }

    static func makeWatchSnapshot() -> WatchDaySnapshot {
        let day = DaySnapshotReader.today()
        return WatchDaySnapshot(
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
            bathroomEnabled: day.bathroomEnabled,
            followedPlan: day.followedPlan,
            ketosis: day.ketosis,
            updatedAt: Date()
        )
    }

    private static func notifySideEffects() {
        WidgetReloader.reloadAll()
        #if os(iOS) && !WIDGET_EXTENSION
        PhoneWatchBridge.shared.pushSnapshot()
        #endif
    }
}
