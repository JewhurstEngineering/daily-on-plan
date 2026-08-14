import Foundation
import SwiftData

/// Frozen schema matching live types at Wave 3 (ketone / eating window / extras on DailyLog).
enum JournalSchemaV3: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(3, 0, 0) }

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
        var ketosis: Bool = false
        var followedPlan: Bool = false
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
        var ketoneMmolStored: Double?
        var eatingWindowStartStored: Date?
        var eatingWindowEndStored: Date?
        var offPlanExtraCarbGramsStored: Double?
        var offPlanExtraFatGramsStored: Double?
        var offPlanExtraKcalStored: Int?

        init() {
            self.id = UUID()
            self.date = Date()
            self.proteinGoal = 500
            self.ketosis = false
            self.followedPlan = false
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

