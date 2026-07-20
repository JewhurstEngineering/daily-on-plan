import Foundation
import SwiftData

@Model
final class DailyLog {
    var id: UUID
    var date: Date
    var proteinGoal: Int
    var ketosis: Bool
    var followedPlan: Bool
    var notes: String
    var waterOz: Int
    /// JSON array of individual drink sizes in oz, e.g. `[16.9, 24.0]`.
    var waterDrinksJSON: String?
    @Relationship(deleteRule: .cascade) var proteinEntries: [ProteinEntry]
    @Relationship(deleteRule: .cascade) var workoutEntries: [WorkoutEntry]
    @Relationship(deleteRule: .cascade) var feelingEntries: [FeelingEntry]
    var checkedFatsAndVeggies: [String]
    var checkedMiscItems: [String]
    var checkedFruits: [String]
    var completedSupplements: [String]

    init(date: Date = Date(), proteinGoal: Int = 500) {
        self.id = UUID()
        self.date = Calendar.current.startOfDay(for: date)
        self.proteinGoal = proteinGoal
        self.ketosis = true
        self.followedPlan = true
        self.notes = ""
        self.waterOz = 0
        self.proteinEntries = []
        self.workoutEntries = []
        self.feelingEntries = []
        self.checkedFatsAndVeggies = []
        self.checkedMiscItems = []
        self.checkedFruits = []
        self.completedSupplements = []
    }

    var totalProteinCalories: Int {
        proteinEntries.reduce(0) { $0 + $1.calories }
    }

    var sortedFeelings: [FeelingEntry] {
        feelingEntries.sorted { $0.timeLogged < $1.timeLogged }
    }

    var sortedProteins: [ProteinEntry] {
        proteinEntries.sorted { $0.time < $1.time }
    }

    var sortedWorkouts: [WorkoutEntry] {
        workoutEntries.sorted { $0.timeLogged < $1.timeLogged }
    }

    var waterDrinks: [Double] {
        get {
            if let data = waterDrinksJSON?.data(using: .utf8),
               let decoded = try? JSONDecoder().decode([Double].self, from: data) {
                return decoded
            }
            // Legacy: only a total was stored — keep as a single drink so data isn't lost.
            if waterOz > 0 { return [Double(waterOz)] }
            return []
        }
        set {
            if let data = try? JSONEncoder().encode(newValue),
               let string = String(data: data, encoding: .utf8) {
                waterDrinksJSON = string
            } else {
                waterDrinksJSON = "[]"
            }
            waterOz = Int(newValue.reduce(0, +).rounded())
        }
    }

    func addWaterDrink(oz: Double) {
        var drinks = waterDrinks
        drinks.append(oz)
        waterDrinks = drinks
    }

    func removeWaterDrink(at index: Int) {
        var drinks = waterDrinks
        guard drinks.indices.contains(index) else { return }
        drinks.remove(at: index)
        waterDrinks = drinks
    }

    func clearWaterDrinks() {
        waterDrinks = []
    }
}

@Model
final class FeelingEntry {
    var id: UUID
    var type: String
    var timeLogged: Date
    var note: String

    init(type: String, note: String = "", timeLogged: Date = Date()) {
        self.id = UUID()
        self.type = type
        self.note = note
        self.timeLogged = timeLogged
    }
}

@Model
final class ProteinEntry {
    var id: UUID
    var name: String
    var time: Date
    var servingSize: String
    var calories: Int
    var hungerBefore: Int
    var hungerAfter: Int
    var proteinCategory: String
    var servings: Double

    init(
        name: String,
        time: Date = Date(),
        servingSize: String,
        calories: Int,
        hungerBefore: Int = 4,
        hungerAfter: Int = 6,
        proteinCategory: String = "other",
        servings: Double = 1
    ) {
        self.id = UUID()
        self.name = name
        self.time = time
        self.servingSize = servingSize
        self.calories = calories
        self.hungerBefore = hungerBefore
        self.hungerAfter = hungerAfter
        self.proteinCategory = proteinCategory
        self.servings = servings
    }
}

@Model
final class WorkoutEntry {
    var id: UUID
    var activityName: String
    var durationMinutes: Int
    var timeLogged: Date

    init(activityName: String, durationMinutes: Int, timeLogged: Date = Date()) {
        self.id = UUID()
        self.activityName = activityName
        self.durationMinutes = durationMinutes
        self.timeLogged = timeLogged
    }
}

@Model
final class WeightEntry {
    var id: UUID
    var date: Date
    var weightLbs: Double
    var timeLogged: Date

    init(date: Date = Date(), weightLbs: Double, timeLogged: Date = Date()) {
        self.id = UUID()
        self.date = Calendar.current.startOfDay(for: date)
        self.weightLbs = weightLbs
        self.timeLogged = timeLogged
    }
}

@Model
final class CustomFoodPreset {
    var id: UUID
    var name: String
    var servingLabel: String
    var calories: Int
    var category: String
    var proteinCategory: String
    var servingsPerUnit: Double

    init(
        name: String,
        servingLabel: String,
        calories: Int,
        category: String = "protein",
        proteinCategory: String = "other",
        servingsPerUnit: Double = 1
    ) {
        self.id = UUID()
        self.name = name
        self.servingLabel = servingLabel
        self.calories = calories
        self.category = category
        self.proteinCategory = proteinCategory
        self.servingsPerUnit = servingsPerUnit
    }
}

@Model
final class AppSettings {
    var id: UUID
    var programPhase: String
    var heightInches: Double
    var usesMetricWeight: Bool
    var defaultProteinGoal: Int
    var waterReminderEnabled: Bool
    var waterReminderIntervalHours: Int
    var eveningCheckInEnabled: Bool
    var eveningCheckInHour: Int
    var eveningCheckInMinute: Int
    var supplementDefinitionsJSON: String
    var defaultBottleOzStored: Double?
    var hydrationTargetOzStored: Int?
    var showSupplementsSectionStored: Bool?

    init() {
        self.id = UUID()
        self.programPhase = ProgramPhase.week1.rawValue
        self.heightInches = 0
        self.usesMetricWeight = false
        self.defaultProteinGoal = 500
        self.waterReminderEnabled = true
        self.waterReminderIntervalHours = 2
        self.eveningCheckInEnabled = true
        self.eveningCheckInHour = 20
        self.eveningCheckInMinute = 0
        self.supplementDefinitionsJSON = SupplementDefinition.defaultJSON
        self.defaultBottleOzStored = AppLimits.defaultBottleOz
        self.hydrationTargetOzStored = AppLimits.hydrationTargetOz
        self.showSupplementsSectionStored = true
    }

    var phase: ProgramPhase {
        get { ProgramPhase(rawValue: programPhase) ?? .week1 }
        set { programPhase = newValue.rawValue }
    }

    var supplements: [SupplementDefinition] {
        get {
            guard let data = supplementDefinitionsJSON.data(using: .utf8),
                  let decoded = try? JSONDecoder().decode([SupplementDefinition].self, from: data) else {
                return SupplementDefinition.defaults
            }
            return decoded
        }
        set {
            if let data = try? JSONEncoder().encode(newValue),
               let string = String(data: data, encoding: .utf8) {
                supplementDefinitionsJSON = string
            }
        }
    }

    var visibleSupplements: [SupplementDefinition] {
        supplements.filter(\.isEnabled)
    }

    var heightMeters: Double? {
        guard heightInches > 0 else { return nil }
        return heightInches * 0.0254
    }

    var hasHeight: Bool { heightInches > 0 }

    var heightDisplay: String {
        guard hasHeight else { return "Not set" }
        let feet = Int(heightInches) / 12
        let inches = Int(heightInches) % 12
        return "\(feet)'\(inches)\""
    }

    var defaultBottleOz: Double {
        get { defaultBottleOzStored ?? AppLimits.defaultBottleOz }
        set { defaultBottleOzStored = newValue }
    }

    var hydrationTargetOz: Int {
        get { hydrationTargetOzStored ?? AppLimits.hydrationTargetOz }
        set { hydrationTargetOzStored = newValue }
    }

    var showSupplementsSection: Bool {
        get { showSupplementsSectionStored ?? true }
        set { showSupplementsSectionStored = newValue }
    }
}
