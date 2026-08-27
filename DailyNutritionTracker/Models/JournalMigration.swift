import Foundation
import SwiftData

/// On-disk schema before CloudKit-safe defaults and JSON checklists.
enum JournalSchemaV1: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(1, 0, 0) }

    static var models: [any PersistentModel.Type] {
        [
            DailyLog.self,
            FeelingEntry.self,
            ProteinEntry.self,
            WorkoutEntry.self,
            WeightEntry.self,
            BodyMeasurementEntry.self,
            BodyCompositionReading.self,
            CustomFoodPreset.self,
            SavedMeal.self,
            AppSettings.self
        ]
    }

    @Model
    final class DailyLog {
        var id: UUID
        var date: Date
        var proteinGoal: Int
        var ketosis: Bool
        var followedPlan: Bool
        var notes: String
        var waterOz: Int
        var waterDrinksJSON: String?
        @Relationship(deleteRule: .cascade, inverse: \ProteinEntry.log)
        var proteinEntries: [ProteinEntry]? = []
        @Relationship(deleteRule: .cascade, inverse: \WorkoutEntry.log)
        var workoutEntries: [WorkoutEntry]? = []
        @Relationship(deleteRule: .cascade, inverse: \FeelingEntry.log)
        var feelingEntries: [FeelingEntry]? = []
        var checkedFatsAndVeggies: [String]
        var checkedFats: [String] = []
        var checkedMiscItems: [String]
        var checkedFruits: [String]
        var completedSupplements: [String]
        var offPlanReasonsJSON: String?
        var cigarettesSmokedStored: Int?
        var cigaretteEventsJSON: String?
        var cigaretteUrgesJSON: String?
        var drinkEventsJSON: String?
        var drinkUrgesJSON: String?
        var bathroomEventsJSON: String?

        init() {
            self.id = UUID()
            self.date = Date()
            self.proteinGoal = 500
            self.ketosis = true
            self.followedPlan = true
            self.notes = ""
            self.waterOz = 0
            self.checkedFatsAndVeggies = []
            self.checkedMiscItems = []
            self.checkedFruits = []
            self.completedSupplements = []
        }
    }

    @Model
    final class FeelingEntry {
        var id: UUID
        var type: String
        var timeLogged: Date
        var note: String
        var log: DailyLog?

        init() {
            self.id = UUID()
            self.type = ""
            self.timeLogged = Date()
            self.note = ""
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
        var hydrationOzStored: Double?
        var log: DailyLog?

        init() {
            self.id = UUID()
            self.name = ""
            self.time = Date()
            self.servingSize = ""
            self.calories = 0
            self.hungerBefore = 4
            self.hungerAfter = 6
            self.proteinCategory = "other"
            self.servings = 1
        }
    }

    @Model
    final class WorkoutEntry {
        var id: UUID
        var activityName: String
        var durationMinutes: Int
        var timeLogged: Date
        var log: DailyLog?

        init() {
            self.id = UUID()
            self.activityName = ""
            self.durationMinutes = 0
            self.timeLogged = Date()
        }
    }

    @Model
    final class WeightEntry {
        var id: UUID
        var date: Date
        var weightLbs: Double
        var timeLogged: Date

        init() {
            self.id = UUID()
            self.date = Date()
            self.weightLbs = 0
            self.timeLogged = Date()
        }
    }

    @Model
    final class BodyMeasurementEntry {
        var id: UUID
        var date: Date
        var neckInchesStored: Double?
        var chestInchesStored: Double?
        var waistInchesStored: Double?
        var hipsInchesStored: Double?
        var leftArmInchesStored: Double?
        var rightArmInchesStored: Double?
        var leftThighInchesStored: Double?
        var rightThighInchesStored: Double?
        var notes: String
        var createdAt: Date

        init() {
            self.id = UUID()
            self.date = Date()
            self.notes = ""
            self.createdAt = Date()
        }
    }

    @Model
    final class BodyCompositionReading {
        var id: UUID
        var date: Date
        var proteinGoalText: String
        var waterTargetText: String
        var bodyTypeRaw: String
        var genderRaw: String
        var age: Int
        var heightInches: Double
        var weightLbs: Double
        var bmi: Double
        var bmrKcal: Int
        var impedance: Double
        var fatPercent: Double
        var fatMassLbs: Double
        var ffmLbs: Double
        var tbwLbs: Double
        var desirableFatPercentLow: Double
        var desirableFatPercentHigh: Double
        var desirableFatMassLow: Double
        var desirableFatMassHigh: Double
        var notes: String
        var createdAt: Date

        init() {
            self.id = UUID()
            self.date = Date()
            self.proteinGoalText = ""
            self.waterTargetText = ""
            self.bodyTypeRaw = ""
            self.genderRaw = ""
            self.age = 30
            self.heightInches = 0
            self.weightLbs = 0
            self.bmi = 0
            self.bmrKcal = 0
            self.impedance = 0
            self.fatPercent = 0
            self.fatMassLbs = 0
            self.ffmLbs = 0
            self.tbwLbs = 0
            self.desirableFatPercentLow = 0
            self.desirableFatPercentHigh = 0
            self.desirableFatMassLow = 0
            self.desirableFatMassHigh = 0
            self.notes = ""
            self.createdAt = Date()
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

        init() {
            self.id = UUID()
            self.name = ""
            self.servingLabel = ""
            self.calories = 0
            self.category = "protein"
            self.proteinCategory = "other"
            self.servingsPerUnit = 1
        }
    }

    @Model
    final class SavedMeal {
        var id: UUID
        var name: String
        var createdAt: Date
        var componentsJSON: String

        init() {
            self.id = UUID()
            self.name = ""
            self.createdAt = Date()
            self.componentsJSON = "[]"
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
        var showBathroomSectionStored: Bool?
        var accentThemeRaw: String?
        var customAccentHexStored: String?
        var appearanceModeRaw: String?
        var weightSectionCollapsedStored: Bool?
        var collapsedSectionsJSON: String?
        var notificationsDefaultsVersionStored: Int?
        var notificationsPausedStored: Bool?
        var genericCheckInEnabledStored: Bool?
        var genericCheckInHourStored: Int?
        var genericCheckInMinuteStored: Int?
        var mealReminderEnabledStored: Bool?
        var mealReminderHourStored: Int?
        var mealReminderMinuteStored: Int?
        var weighReminderEnabledStored: Bool?
        var weighReminderHourStored: Int?
        var weighReminderMinuteStored: Int?
        var ketosisCheckInEnabledStored: Bool?
        var ketosisCheckInHourStored: Int?
        var ketosisCheckInMinuteStored: Int?
        var excludedFoodsJSON: String?
        var preferredFoodsJSON: String?
        var customOffPlanReasonsJSON: String?
        var goalWeightLbsStored: Double?
        var smokingModeRaw: String?
        var dailyCigaretteLimitStored: Int?
        var quitDateStored: Date?
        var cigarettesPerPackStored: Int?
        var cigarettePackPriceStored: Double?
        var drinkingModeRaw: String?
        var dailyDrinkLimitStored: Int?
        var alcoholQuitDateStored: Date?
        var smokingCheckInEnabledStored: Bool?
        var smokingCheckInHourStored: Int?
        var smokingCheckInMinuteStored: Int?
        var drinkingCheckInEnabledStored: Bool?
        var drinkingCheckInHourStored: Int?
        var drinkingCheckInMinuteStored: Int?
        var motivationReminderEnabledStored: Bool?
        var motivationReminderHourStored: Int?
        var motivationReminderMinuteStored: Int?
        var customMotivationQuotesJSON: String?
        var sectionOrderJSON: String?
        var proteinDrinksCountTowardHydrationStored: Bool?
        var defaultShakeHydrationOzStored: Double?
        var usdaAPIKeyStored: String?
        var bodyCompReminderEnabledStored: Bool?
        var bodyCompReminderCadenceRaw: String?
        var bodyCompReminderWeekdayStored: Int?
        var bodyCompReminderDayOfMonthStored: Int?
        var bodyCompReminderHourStored: Int?
        var bodyCompReminderMinuteStored: Int?
        var ageYearsStored: Int?

        init() {
            self.id = UUID()
            self.programPhase = "week1"
            self.heightInches = 0
            self.usesMetricWeight = false
            self.defaultProteinGoal = 500
            self.waterReminderEnabled = false
            self.waterReminderIntervalHours = 3
            self.eveningCheckInEnabled = true
            self.eveningCheckInHour = 20
            self.eveningCheckInMinute = 0
            self.supplementDefinitionsJSON = "[]"
        }
    }
}

enum JournalSchemaV2: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(2, 0, 0) }

    static var models: [any PersistentModel.Type] {
        [
            DailyLog.self,
            FeelingEntry.self,
            ProteinEntry.self,
            WorkoutEntry.self,
            WeightEntry.self,
            BodyMeasurementEntry.self,
            BodyCompositionReading.self,
            CustomFoodPreset.self,
            SavedMeal.self,
            AppSettings.self
        ]
    }

    @Model
    final class DailyLog {
        var id: UUID = UUID()
        var date: Date = Date()
        var proteinGoal: Int = 500
        var ketosis: Bool = true
        var followedPlan: Bool = true
        var notes: String = ""
        var waterOz: Int = 0
        var waterDrinksJSON: String?
        @Relationship(deleteRule: .cascade, inverse: \ProteinEntry.log)
        var proteinEntries: [ProteinEntry]? = []
        @Relationship(deleteRule: .cascade, inverse: \WorkoutEntry.log)
        var workoutEntries: [WorkoutEntry]? = []
        @Relationship(deleteRule: .cascade, inverse: \FeelingEntry.log)
        var feelingEntries: [FeelingEntry]? = []
        var checkedFatsAndVeggiesJSON: String? = "[]"
        var checkedFatsJSON: String? = "[]"
        var checkedMiscItemsJSON: String? = "[]"
        var checkedFruitsJSON: String? = "[]"
        var completedSupplementsJSON: String? = "[]"
        var offPlanReasonsJSON: String?
        var cigarettesSmokedStored: Int?
        var cigaretteEventsJSON: String?
        var cigaretteUrgesJSON: String?
        var drinkEventsJSON: String?
        var drinkUrgesJSON: String?
        var bathroomEventsJSON: String?

        init() {
            self.id = UUID()
            self.date = Date()
            self.proteinGoal = 500
            self.ketosis = true
            self.followedPlan = true
            self.notes = ""
            self.waterOz = 0
        }
    }

    @Model
    final class FeelingEntry {
        var id: UUID = UUID()
        var type: String = ""
        var timeLogged: Date = Date()
        var note: String = ""
        var log: DailyLog?

        init() {
            self.id = UUID()
            self.type = ""
            self.timeLogged = Date()
            self.note = ""
        }
    }

    @Model
    final class ProteinEntry {
        var id: UUID = UUID()
        var name: String = ""
        var time: Date = Date()
        var servingSize: String = ""
        var calories: Int = 0
        var hungerBefore: Int = 4
        var hungerAfter: Int = 6
        var proteinCategory: String = "other"
        var servings: Double = 1
        var hydrationOzStored: Double?
        var log: DailyLog?

        init() {
            self.id = UUID()
            self.name = ""
            self.time = Date()
            self.servingSize = ""
            self.calories = 0
            self.hungerBefore = 4
            self.hungerAfter = 6
            self.proteinCategory = "other"
            self.servings = 1
        }
    }

    @Model
    final class WorkoutEntry {
        var id: UUID = UUID()
        var activityName: String = ""
        var durationMinutes: Int = 0
        var timeLogged: Date = Date()
        var log: DailyLog?

        init() {
            self.id = UUID()
            self.activityName = ""
            self.durationMinutes = 0
            self.timeLogged = Date()
        }
    }

    @Model
    final class WeightEntry {
        var id: UUID = UUID()
        var date: Date = Date()
        var weightLbs: Double = 0
        var timeLogged: Date = Date()

        init() {
            self.id = UUID()
            self.date = Date()
            self.weightLbs = 0
            self.timeLogged = Date()
        }
    }

    @Model
    final class BodyMeasurementEntry {
        var id: UUID = UUID()
        var date: Date = Date()
        var neckInchesStored: Double?
        var chestInchesStored: Double?
        var waistInchesStored: Double?
        var hipsInchesStored: Double?
        var leftArmInchesStored: Double?
        var rightArmInchesStored: Double?
        var leftThighInchesStored: Double?
        var rightThighInchesStored: Double?
        var notes: String = ""
        var createdAt: Date = Date()

        init() {
            self.id = UUID()
            self.date = Date()
            self.notes = ""
            self.createdAt = Date()
        }
    }

    @Model
    final class BodyCompositionReading {
        var id: UUID = UUID()
        var date: Date = Date()
        var proteinGoalText: String = ""
        var waterTargetText: String = ""
        var bodyTypeRaw: String = ""
        var genderRaw: String = ""
        var age: Int = 30
        var heightInches: Double = 0
        var weightLbs: Double = 0
        var bmi: Double = 0
        var bmrKcal: Int = 0
        var impedance: Double = 0
        var fatPercent: Double = 0
        var fatMassLbs: Double = 0
        var ffmLbs: Double = 0
        var tbwLbs: Double = 0
        var desirableFatPercentLow: Double = 0
        var desirableFatPercentHigh: Double = 0
        var desirableFatMassLow: Double = 0
        var desirableFatMassHigh: Double = 0
        var notes: String = ""
        var createdAt: Date = Date()

        init() {
            self.id = UUID()
            self.date = Date()
            self.proteinGoalText = ""
            self.waterTargetText = ""
            self.bodyTypeRaw = ""
            self.genderRaw = ""
            self.age = 30
            self.heightInches = 0
            self.weightLbs = 0
            self.bmi = 0
            self.bmrKcal = 0
            self.impedance = 0
            self.fatPercent = 0
            self.fatMassLbs = 0
            self.ffmLbs = 0
            self.tbwLbs = 0
            self.desirableFatPercentLow = 0
            self.desirableFatPercentHigh = 0
            self.desirableFatMassLow = 0
            self.desirableFatMassHigh = 0
            self.notes = ""
            self.createdAt = Date()
        }
    }

    @Model
    final class CustomFoodPreset {
        var id: UUID = UUID()
        var name: String = ""
        var servingLabel: String = ""
        var calories: Int = 0
        var category: String = "protein"
        var proteinCategory: String = "other"
        var servingsPerUnit: Double = 1

        init() {
            self.id = UUID()
            self.name = ""
            self.servingLabel = ""
            self.calories = 0
            self.category = "protein"
            self.proteinCategory = "other"
            self.servingsPerUnit = 1
        }
    }

    @Model
    final class SavedMeal {
        var id: UUID = UUID()
        var name: String = ""
        var createdAt: Date = Date()
        var componentsJSON: String = "[]"

        init() {
            self.id = UUID()
            self.name = ""
            self.createdAt = Date()
            self.componentsJSON = "[]"
        }
    }

    @Model
    final class AppSettings {
        var id: UUID = UUID()
        var programPhase: String = "week1"
        var heightInches: Double = 0
        var usesMetricWeight: Bool = false
        var defaultProteinGoal: Int = 500
        var waterReminderEnabled: Bool = false
        var waterReminderIntervalHours: Int = 3
        var eveningCheckInEnabled: Bool = true
        var eveningCheckInHour: Int = 20
        var eveningCheckInMinute: Int = 0
        var supplementDefinitionsJSON: String = "[]"
        var defaultBottleOzStored: Double?
        var hydrationTargetOzStored: Int?
        var showSupplementsSectionStored: Bool?
        var showBathroomSectionStored: Bool?
        var accentThemeRaw: String?
        var customAccentHexStored: String?
        var appearanceModeRaw: String?
        var weightSectionCollapsedStored: Bool?
        var collapsedSectionsJSON: String?
        var notificationsDefaultsVersionStored: Int?
        var notificationsPausedStored: Bool?
        var genericCheckInEnabledStored: Bool?
        var genericCheckInHourStored: Int?
        var genericCheckInMinuteStored: Int?
        var mealReminderEnabledStored: Bool?
        var mealReminderHourStored: Int?
        var mealReminderMinuteStored: Int?
        var weighReminderEnabledStored: Bool?
        var weighReminderHourStored: Int?
        var weighReminderMinuteStored: Int?
        var ketosisCheckInEnabledStored: Bool?
        var ketosisCheckInHourStored: Int?
        var ketosisCheckInMinuteStored: Int?
        var excludedFoodsJSON: String?
        var preferredFoodsJSON: String?
        var customOffPlanReasonsJSON: String?
        var goalWeightLbsStored: Double?
        var smokingModeRaw: String?
        var dailyCigaretteLimitStored: Int?
        var quitDateStored: Date?
        var cigarettesPerPackStored: Int?
        var cigarettePackPriceStored: Double?
        var drinkingModeRaw: String?
        var dailyDrinkLimitStored: Int?
        var alcoholQuitDateStored: Date?
        var smokingCheckInEnabledStored: Bool?
        var smokingCheckInHourStored: Int?
        var smokingCheckInMinuteStored: Int?
        var drinkingCheckInEnabledStored: Bool?
        var drinkingCheckInHourStored: Int?
        var drinkingCheckInMinuteStored: Int?
        var motivationReminderEnabledStored: Bool?
        var motivationReminderHourStored: Int?
        var motivationReminderMinuteStored: Int?
        var customMotivationQuotesJSON: String?
        var sectionOrderJSON: String?
        var proteinDrinksCountTowardHydrationStored: Bool?
        var defaultShakeHydrationOzStored: Double?
        var usdaAPIKeyStored: String?
        var bodyCompReminderEnabledStored: Bool?
        var bodyCompReminderCadenceRaw: String?
        var bodyCompReminderWeekdayStored: Int?
        var bodyCompReminderDayOfMonthStored: Int?
        var bodyCompReminderHourStored: Int?
        var bodyCompReminderMinuteStored: Int?
        var ageYearsStored: Int?

        init() {
            self.id = UUID()
            self.programPhase = "week1"
            self.heightInches = 0
            self.usesMetricWeight = false
            self.defaultProteinGoal = 500
            self.waterReminderEnabled = false
            self.waterReminderIntervalHours = 3
            self.eveningCheckInEnabled = true
            self.eveningCheckInHour = 20
            self.eveningCheckInMinute = 0
            self.supplementDefinitionsJSON = "[]"
        }
    }
}

/// Live types: per-entry macros (`macrosJSON`) plus the protein-grams floor.
enum JournalSchemaV5: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(5, 0, 0) }

    static var models: [any PersistentModel.Type] {
        [
            DailyLog.self,
            FeelingEntry.self,
            ProteinEntry.self,
            WorkoutEntry.self,
            WeightEntry.self,
            BodyMeasurementEntry.self,
            BodyCompositionReading.self,
            CustomFoodPreset.self,
            SavedMeal.self,
            AppSettings.self
        ]
    }
}

enum JournalMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [
            JournalSchemaV1.self,
            JournalSchemaV2.self,
            JournalSchemaV3.self,
            JournalSchemaV4.self,
            JournalSchemaV5.self
        ]
    }

    static var stages: [MigrationStage] {
        [migrateV1toV2, migrateV2toV3, migrateV3toV4, migrateV4toV5]
    }

    private static let payloadURL: URL = {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        try? FileManager.default.createDirectory(at: support, withIntermediateDirectories: true)
        return support.appendingPathComponent("OnPlanChecklistMigration.json")
    }()

    static let migrateV1toV2 = MigrationStage.custom(
        fromVersion: JournalSchemaV1.self,
        toVersion: JournalSchemaV2.self,
        willMigrate: { context in
            let logs = try context.fetch(FetchDescriptor<JournalSchemaV1.DailyLog>())
            let payload = logs.map { log in
                ChecklistMigrationPayload(
                    id: log.id,
                    veg: log.checkedFatsAndVeggies,
                    fats: log.checkedFats,
                    misc: log.checkedMiscItems,
                    fruits: log.checkedFruits,
                    supplements: log.completedSupplements
                )
            }
            let data = try JSONEncoder().encode(payload)
            try data.write(to: payloadURL, options: .atomic)
        },
        didMigrate: { context in
            guard let data = try? Data(contentsOf: payloadURL),
                  let payload = try? JSONDecoder().decode([ChecklistMigrationPayload].self, from: data)
            else { return }
            let byID = Dictionary(uniqueKeysWithValues: payload.map { ($0.id, $0) })
            let logs = try context.fetch(FetchDescriptor<JournalSchemaV2.DailyLog>())
            for log in logs {
                guard let row = byID[log.id] else { continue }
                log.checkedFatsAndVeggiesJSON = JSONStringList.encode(row.veg)
                log.checkedFatsJSON = JSONStringList.encode(row.fats)
                log.checkedMiscItemsJSON = JSONStringList.encode(row.misc)
                log.checkedFruitsJSON = JSONStringList.encode(row.fruits)
                log.completedSupplementsJSON = JSONStringList.encode(row.supplements)
            }
            try context.save()
            try? FileManager.default.removeItem(at: payloadURL)
        }
    )

    static let migrateV2toV3 = MigrationStage.lightweight(
        fromVersion: JournalSchemaV2.self,
        toVersion: JournalSchemaV3.self
    )

    static let migrateV3toV4 = MigrationStage.lightweight(
        fromVersion: JournalSchemaV3.self,
        toVersion: JournalSchemaV4.self
    )

    /// Every field added in V5 is optional, so existing rows migrate untouched: entries logged
    /// before macros existed simply read back with `macros == nil`, and their kcal is unchanged.
    static let migrateV4toV5 = MigrationStage.lightweight(
        fromVersion: JournalSchemaV4.self,
        toVersion: JournalSchemaV5.self
    )
}

private struct ChecklistMigrationPayload: Codable {
    var id: UUID
    var veg: [String]
    var fats: [String]
    var misc: [String]
    var fruits: [String]
    var supplements: [String]
}
