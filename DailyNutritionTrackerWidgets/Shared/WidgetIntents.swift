import AppIntents
import Foundation

struct AddWaterBottleIntent: AppIntent {
    static var title: LocalizedStringResource = "Add Water Bottle"
    static var description = IntentDescription("Logs one default bottle toward today's hydration goal.")
    static var openAppWhenRun: Bool = false

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        switch QuickAddService.addWaterBottle() {
        case .success(let message):
            return .result(dialog: IntentDialog(stringLiteral: message))
        case .failure(let message):
            return .result(dialog: IntentDialog(stringLiteral: message))
        }
    }
}

struct AddCigaretteIntent: AppIntent {
    static var title: LocalizedStringResource = "Log Cigarette"
    static var description = IntentDescription("Adds one cigarette to today's smoking log.")
    static var openAppWhenRun: Bool = false

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        switch QuickAddService.addCigarette() {
        case .success(let message):
            return .result(dialog: IntentDialog(stringLiteral: message))
        case .failure(let message):
            return .result(dialog: IntentDialog(stringLiteral: message))
        }
    }
}

struct AddSmokeUrgeIntent: AppIntent {
    static var title: LocalizedStringResource = "Log Smoke Urge"
    static var openAppWhenRun: Bool = false

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        switch QuickAddService.addSmokeUrge() {
        case .success(let message):
            return .result(dialog: IntentDialog(stringLiteral: message))
        case .failure(let message):
            return .result(dialog: IntentDialog(stringLiteral: message))
        }
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
        switch QuickAddService.addDrinks(count) {
        case .success(let message):
            return .result(dialog: IntentDialog(stringLiteral: message))
        case .failure(let message):
            return .result(dialog: IntentDialog(stringLiteral: message))
        }
    }
}

struct AddDrinkIntent: AppIntent {
    static var title: LocalizedStringResource = "Log Drink"
    static var openAppWhenRun: Bool = false

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        switch QuickAddService.addDrinks(1) {
        case .success(let message):
            return .result(dialog: IntentDialog(stringLiteral: message))
        case .failure(let message):
            return .result(dialog: IntentDialog(stringLiteral: message))
        }
    }
}

struct AddDrinkUrgeIntent: AppIntent {
    static var title: LocalizedStringResource = "Log Drink Urge"
    static var openAppWhenRun: Bool = false

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        switch QuickAddService.addDrinkUrge() {
        case .success(let message):
            return .result(dialog: IntentDialog(stringLiteral: message))
        case .failure(let message):
            return .result(dialog: IntentDialog(stringLiteral: message))
        }
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
        switch QuickAddService.addBathroom(kind: kind.model) {
        case .success(let message):
            return .result(dialog: IntentDialog(stringLiteral: message))
        case .failure(let message):
            return .result(dialog: IntentDialog(stringLiteral: message))
        }
    }
}

struct MarkNextSupplementIntent: AppIntent {
    static var title: LocalizedStringResource = "Mark Next Supplement"
    static var openAppWhenRun: Bool = false

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        switch QuickAddService.markNextSupplement() {
        case .success(let message):
            return .result(dialog: IntentDialog(stringLiteral: message))
        case .failure(let message):
            return .result(dialog: IntentDialog(stringLiteral: message))
        }
    }
}

struct ToggleFollowedPlanIntent: AppIntent {
    static var title: LocalizedStringResource = "Toggle On Plan"
    static var openAppWhenRun: Bool = false

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        switch QuickAddService.toggleFollowedPlan() {
        case .success(let message):
            return .result(dialog: IntentDialog(stringLiteral: message))
        case .failure(let message):
            return .result(dialog: IntentDialog(stringLiteral: message))
        }
    }
}

struct ToggleKetosisIntent: AppIntent {
    static var title: LocalizedStringResource = "Toggle Ketosis"
    static var openAppWhenRun: Bool = false

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        switch QuickAddService.toggleKetosis() {
        case .success(let message):
            return .result(dialog: IntentDialog(stringLiteral: message))
        case .failure(let message):
            return .result(dialog: IntentDialog(stringLiteral: message))
        }
    }
}
