import AppIntents
import Foundation
import SwiftData
import WidgetKit

enum WidgetIntentStore {
    @MainActor
    static func context() throws -> (ModelContext, AppSettings, DailyLog) {
        let container = try SharedModelContainer.shared()
        let context = ModelContext(container)
        let settings = DataStore.settings(in: context)
        let log = DataStore.log(for: Date(), in: context, defaultGoal: settings.defaultProteinGoal)
        return (context, settings, log)
    }
}

struct AddWaterBottleIntent: AppIntent {
    static var title: LocalizedStringResource = "Add Water Bottle"
    static var description = IntentDescription("Logs one default bottle toward today's hydration goal.")
    static var openAppWhenRun: Bool = false

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let (context, settings, log) = try WidgetIntentStore.context()
        let bottle = max(settings.defaultBottleOz, 1)
        let minimumSlots = max(1, Int(ceil(Double(settings.hydrationTargetOz) / bottle)))
        log.fillNextWaterSlot(oz: bottle, ensuringMinimumSlots: minimumSlots)
        try context.save()
        WidgetReloader.reloadAll()
        let label = bottle == bottle.rounded() ? "\(Int(bottle))" : String(format: "%.1f", bottle)
        return .result(dialog: IntentDialog("Logged \(label) oz of water."))
    }
}

struct AddCigaretteIntent: AppIntent {
    static var title: LocalizedStringResource = "Log Cigarette"
    static var description = IntentDescription("Adds one cigarette to today's smoking log.")
    static var openAppWhenRun: Bool = false

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let (context, settings, log) = try WidgetIntentStore.context()
        guard settings.smokingMode.showsSection else {
            return .result(dialog: IntentDialog("Smoking tracking is turned off."))
        }
        log.addCigarette()
        try context.save()
        WidgetReloader.reloadAll()
        return .result(dialog: IntentDialog("Logged 1 cigarette."))
    }
}

struct AddSmokeUrgeIntent: AppIntent {
    static var title: LocalizedStringResource = "Log Smoke Urge"
    static var openAppWhenRun: Bool = false

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let (context, settings, log) = try WidgetIntentStore.context()
        guard settings.smokingMode.showsSection else {
            return .result(dialog: IntentDialog("Smoking tracking is turned off."))
        }
        log.addUrge()
        try context.save()
        WidgetReloader.reloadAll()
        return .result(dialog: IntentDialog("Logged a smoking urge."))
    }
}

struct AddDrinksIntent: AppIntent {
    static var title: LocalizedStringResource = "Log Drinks"
    static var description = IntentDescription("Adds alcoholic drinks to today's log.")
    static var openAppWhenRun: Bool = false

    @Parameter(title: "Count", default: 1)
    var count: Int

    init() { count = 1 }
    init(count: Int) { self.count = max(1, count) }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let (context, settings, log) = try WidgetIntentStore.context()
        guard settings.drinkingMode.showsSection else {
            return .result(dialog: IntentDialog("Drinking tracking is turned off."))
        }
        let n = max(1, min(count, 10))
        log.addDrinks(n)
        try context.save()
        WidgetReloader.reloadAll()
        return .result(dialog: IntentDialog(n == 1 ? "Logged 1 drink." : "Logged \(n) drinks."))
    }
}

struct AddDrinkIntent: AppIntent {
    static var title: LocalizedStringResource = "Log Drink"
    static var openAppWhenRun: Bool = false

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let (context, settings, log) = try WidgetIntentStore.context()
        guard settings.drinkingMode.showsSection else {
            return .result(dialog: IntentDialog("Drinking tracking is turned off."))
        }
        log.addDrinks(1)
        try context.save()
        WidgetReloader.reloadAll()
        return .result(dialog: IntentDialog("Logged 1 drink."))
    }
}

struct AddDrinkUrgeIntent: AppIntent {
    static var title: LocalizedStringResource = "Log Drink Urge"
    static var openAppWhenRun: Bool = false

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let (context, settings, log) = try WidgetIntentStore.context()
        guard settings.drinkingMode.showsSection else {
            return .result(dialog: IntentDialog("Drinking tracking is turned off."))
        }
        log.addDrinkUrge()
        try context.save()
        WidgetReloader.reloadAll()
        return .result(dialog: IntentDialog("Logged a drink urge."))
    }
}

enum BathroomKindAppEnum: String, AppEnum {
    case urine
    case stool

    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Bathroom type")
    static var caseDisplayRepresentations: [BathroomKindAppEnum: DisplayRepresentation] = [
        .urine: "Urination",
        .stool: "Bowel movement"
    ]

    var model: BathroomKind {
        switch self {
        case .urine: return .urine
        case .stool: return .stool
        }
    }
}

struct AddBathroomIntent: AppIntent {
    static var title: LocalizedStringResource = "Log Bathroom"
    static var openAppWhenRun: Bool = false

    @Parameter(title: "Type")
    var kind: BathroomKindAppEnum

    init() { kind = .urine }
    init(kind: BathroomKindAppEnum) { self.kind = kind }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let (context, _, log) = try WidgetIntentStore.context()
        _ = log.addBathroomEvent(kind: kind.model)
        try context.save()
        WidgetReloader.reloadAll()
        return .result(dialog: IntentDialog("Logged \(kind.model.shortTitle.lowercased())."))
    }
}

struct MarkNextSupplementIntent: AppIntent {
    static var title: LocalizedStringResource = "Mark Next Supplement"
    static var openAppWhenRun: Bool = false

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let (context, settings, log) = try WidgetIntentStore.context()
        guard settings.showSupplementsSection else {
            return .result(dialog: IntentDialog("Supplements are hidden."))
        }
        for def in settings.visibleSupplements {
            for index in 0..<def.dosesPerDay {
                let key = def.doseKey(index)
                if !log.completedSupplements.contains(key) {
                    log.completedSupplements.append(key)
                    try context.save()
                    WidgetReloader.reloadAll()
                    return .result(dialog: IntentDialog("Marked \(def.name) dose \(index + 1)."))
                }
            }
        }
        return .result(dialog: IntentDialog("All supplement doses are done today."))
    }
}

struct ToggleFollowedPlanIntent: AppIntent {
    static var title: LocalizedStringResource = "Toggle On Plan"
    static var openAppWhenRun: Bool = false

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let (context, _, log) = try WidgetIntentStore.context()
        log.followedPlan.toggle()
        try context.save()
        WidgetReloader.reloadAll()
        return .result(dialog: IntentDialog(log.followedPlan ? "Marked on plan." : "Marked off plan."))
    }
}

struct ToggleKetosisIntent: AppIntent {
    static var title: LocalizedStringResource = "Toggle Ketosis"
    static var openAppWhenRun: Bool = false

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let (context, _, log) = try WidgetIntentStore.context()
        log.ketosis.toggle()
        try context.save()
        WidgetReloader.reloadAll()
        return .result(dialog: IntentDialog(log.ketosis ? "Marked in ketosis." : "Marked not in ketosis."))
    }
}
