import Foundation
import SwiftData
import OnPlanCore

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
        addHydration(oz: nil, electrolyte: false)
    }

    static func addHydration(oz: Double?, electrolyte: Bool) -> Result {
        do {
            let (context, settings, log) = try context()
            let bottle = max(oz ?? settings.defaultBottleOz, 1)
            let minimumSlots = max(1, Int(ceil(Double(settings.hydrationTargetOz) / max(settings.defaultBottleOz, 1))))
            log.fillNextWaterSlot(
                oz: bottle,
                ensuringMinimumSlots: minimumSlots,
                kind: electrolyte ? .electrolyte : .water,
                isElectrolyte: electrolyte
            )
            try context.save()
            notifySideEffects()
            let label = bottle == bottle.rounded() ? "\(Int(bottle))" : String(format: "%.1f", bottle)
            let kind = electrolyte ? "electrolytes" : "water"
            return .success(message: "Logged \(label) oz of \(kind).")
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

    static func addProteinCalories(_ calories: Int, name: String = "Protein") -> Result {
        do {
            let (context, _, log) = try context()
            let kcal = max(1, min(calories, 2000))
            let entry = ProteinEntry(
                name: name,
                servingSize: "quick add",
                calories: kcal,
                proteinCategory: "other",
                servings: 1
            )
            entry.log = log
            context.insert(entry)
            try context.save()
            notifySideEffects()
            return .success(message: "Logged \(kcal) kcal protein.")
        } catch {
            return .failure(message: error.localizedDescription)
        }
    }

    static func setFollowedPlan(_ onPlan: Bool) -> Result {
        do {
            let (context, _, log) = try context()
            log.followedPlan = onPlan
            if onPlan { log.offPlanReasons = [] }
            try context.save()
            notifySideEffects()
            return .success(message: onPlan ? "Marked on plan." : "Marked off plan.")
        } catch {
            return .failure(message: error.localizedDescription)
        }
    }

    static func setKetosis(_ inKetosis: Bool) -> Result {
        do {
            let (context, _, log) = try context()
            log.ketosis = inKetosis
            try context.save()
            notifySideEffects()
            return .success(message: inKetosis ? "Marked in ketosis." : "Marked not in ketosis.")
        } catch {
            return .failure(message: error.localizedDescription)
        }
    }

    static func startEatingWindow(useTypical: Bool = false) -> Result {
        do {
            let (context, settings, log) = try context()
            if useTypical {
                FastingMath.applyTypicalWindow(to: log, settings: settings)
            } else {
                log.eatingWindowStart = Date()
                log.eatingWindowEnd = nil
            }
            try context.save()
            notifySideEffects()
            return .success(message: "Eating window started.")
        } catch {
            return .failure(message: error.localizedDescription)
        }
    }

    static func endEatingWindow() -> Result {
        do {
            let (context, _, log) = try context()
            guard log.eatingWindowStart != nil else {
                return .failure(message: "Start the eating window first.")
            }
            log.eatingWindowEnd = Date()
            try context.save()
            notifySideEffects()
            return .success(message: "Eating window closed.")
        } catch {
            return .failure(message: error.localizedDescription)
        }
    }

    static func clearEatingWindow() -> Result {
        do {
            let (context, _, log) = try context()
            log.eatingWindowStart = nil
            log.eatingWindowEnd = nil
            try context.save()
            notifySideEffects()
            return .success(message: "Cleared today’s eating window.")
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

    #if os(iOS)
    static func makeWatchSnapshot() -> WatchDaySnapshot {
        let day = DaySnapshotReader.today()
        let quick = DisplayPreferenceStore.load().watchQuickAdd
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
            updatedAt: Date(),
            quickAddSlots: quick.resolvedSlots.map(\.rawValue),
            hydrationSizesOz: quick.hydrationSizesOz,
            fastingEnabled: day.fastingEnabled,
            eatingWindowStart: day.eatingWindowStart,
            eatingWindowEnd: day.eatingWindowEnd,
            fastingTargetHours: day.fastingTargetHours,
            fastingStatusLine: day.fastingStatusLine
        )
    }
    #endif

    private static func notifySideEffects() {
        WidgetReloader.reloadAll()
        #if os(iOS) && !WIDGET_EXTENSION
        PhoneWatchBridge.shared.pushSnapshot()
        #endif
    }
}
