import Foundation
import SwiftData
import WidgetKit

@MainActor
enum BackupService {
    static let formatIdentifier = "dailyonplan.backup"
    static let currentVersion = 2
    static let fileExtension = "dopbackup"

    enum BackupError: LocalizedError {
        case invalidFormat
        case unsupportedVersion(Int)
        case missingSettings
        case encodeFailed
        case decodeFailed
        case saveFailed(Error)

        var errorDescription: String? {
            switch self {
            case .invalidFormat:
                return "This file is not a Daily On Plan backup."
            case .unsupportedVersion(let version):
                return "Backup version \(version) is not supported by this app build."
            case .missingSettings:
                return "Backup is missing settings data."
            case .encodeFailed:
                return "Could not create the backup file."
            case .decodeFailed:
                return "Could not read the backup file."
            case .saveFailed(let error):
                return "Could not save restored data: \(error.localizedDescription)"
            }
        }
    }

    // MARK: - Public API

    static func createBackup(from context: ModelContext) throws -> URL {
        let snapshot = try makeSnapshot(from: context)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(snapshot) else {
            throw BackupError.encodeFailed
        }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        let stamp = formatter.string(from: Date())
        let url = try ExportFileStore.uniqueURL(stem: "DailyOnPlan-Backup-\(stamp)", ext: fileExtension)
        // uniqueURL already stamps; prefer readable name without double stamp when possible
        let preferred = try ExportFileStore.exportsDirectory()
            .appendingPathComponent("DailyOnPlan-Backup-\(stamp).\(fileExtension)")
        let writeURL = FileManager.default.fileExists(atPath: preferred.path) ? url : preferred
        try data.write(to: writeURL, options: .atomic)
        return writeURL
    }

    static func loadSnapshot(from url: URL) throws -> BackupSnapshot {
        let accessed = url.startAccessingSecurityScopedResource()
        defer {
            if accessed { url.stopAccessingSecurityScopedResource() }
        }
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            throw BackupError.decodeFailed
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let snapshot: BackupSnapshot
        do {
            snapshot = try decoder.decode(BackupSnapshot.self, from: data)
        } catch {
            throw BackupError.decodeFailed
        }
        guard snapshot.format == formatIdentifier else {
            throw BackupError.invalidFormat
        }
        guard snapshot.version <= currentVersion else {
            throw BackupError.unsupportedVersion(snapshot.version)
        }
        guard snapshot.settings != nil else {
            throw BackupError.missingSettings
        }
        return snapshot
    }

    /// Deletes all local SwiftData records and inserts the backup. Caller should refresh UI bindings.
    @discardableResult
    static func replaceAll(with snapshot: BackupSnapshot, in context: ModelContext) throws -> AppSettings {
        guard let settingsDTO = snapshot.settings else {
            throw BackupError.missingSettings
        }

        try deleteAll(in: context)

        for logDTO in snapshot.dailyLogs {
            let log = logDTO.makeModel()
            context.insert(log)
            for protein in logDTO.proteinEntries {
                let entry = protein.makeModel()
                context.insert(entry)
                log.proteins.append(entry)
            }
            for workout in logDTO.workoutEntries {
                let entry = workout.makeModel()
                context.insert(entry)
                log.workouts.append(entry)
            }
            for feeling in logDTO.feelingEntries {
                let entry = feeling.makeModel()
                context.insert(entry)
                log.feelings.append(entry)
            }
        }

        for weight in snapshot.weights {
            context.insert(weight.makeModel())
        }
        for measurement in snapshot.bodyMeasurements {
            context.insert(measurement.makeModel())
        }
        for reading in snapshot.bodyCompositions {
            context.insert(reading.makeModel())
        }
        for preset in snapshot.customFoodPresets {
            context.insert(preset.makeModel())
        }
        for meal in snapshot.savedMeals {
            context.insert(meal.makeModel())
        }

        let settings = settingsDTO.makeModel()
        context.insert(settings)
        settings.migrateNotificationDefaultsIfNeeded()

        do {
            try context.save()
        } catch {
            throw BackupError.saveFailed(error)
        }

        applyPostRestoreSideEffects(settings: settings)
        return settings
    }

    static func summary(for snapshot: BackupSnapshot) -> String {
        let days = snapshot.dailyLogs.count
        let weights = snapshot.weights.count
        let presets = snapshot.customFoodPresets.count
        let meals = snapshot.savedMeals.count
        return "\(days) days · \(weights) weights · \(presets) presets · \(meals) meals"
    }

    // MARK: - Snapshot build

    static func snapshot(from context: ModelContext) throws -> BackupSnapshot {
        try makeSnapshot(from: context)
    }

    private static func makeSnapshot(from context: ModelContext) throws -> BackupSnapshot {
        let logs = try context.fetch(FetchDescriptor<DailyLog>(sortBy: [SortDescriptor(\.date)]))
        let weights = try context.fetch(FetchDescriptor<WeightEntry>(sortBy: [SortDescriptor(\.date)]))
        let measurements = try context.fetch(FetchDescriptor<BodyMeasurementEntry>(sortBy: [SortDescriptor(\.date)]))
        let compositions = try context.fetch(FetchDescriptor<BodyCompositionReading>(sortBy: [SortDescriptor(\.date)]))
        let presets = try context.fetch(FetchDescriptor<CustomFoodPreset>(sortBy: [SortDescriptor(\.name)]))
        let meals = try context.fetch(FetchDescriptor<SavedMeal>(sortBy: [SortDescriptor(\.name)]))
        let settingsList = try context.fetch(FetchDescriptor<AppSettings>())
        let settings = settingsList.first ?? DataStore.settings(in: context)

        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? ""
        let short = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""

        return BackupSnapshot(
            format: formatIdentifier,
            version: currentVersion,
            exportedAt: Date(),
            appBuild: short.isEmpty ? build : "\(short) (\(build))",
            dailyLogs: logs.map(DailyLogDTO.init(from:)),
            weights: weights.map(WeightEntryDTO.init(from:)),
            bodyMeasurements: measurements.map(BodyMeasurementEntryDTO.init(from:)),
            bodyCompositions: compositions.map(BodyCompositionReadingDTO.init(from:)),
            customFoodPresets: presets.map(CustomFoodPresetDTO.init(from:)),
            savedMeals: meals.map(SavedMealDTO.init(from:)),
            settings: AppSettingsDTO(from: settings)
        )
    }

    private static func deleteAll(in context: ModelContext) throws {
        try deleteType(FeelingEntry.self, in: context)
        try deleteType(ProteinEntry.self, in: context)
        try deleteType(WorkoutEntry.self, in: context)
        try deleteType(DailyLog.self, in: context)
        try deleteType(WeightEntry.self, in: context)
        try deleteType(BodyMeasurementEntry.self, in: context)
        try deleteType(BodyCompositionReading.self, in: context)
        try deleteType(CustomFoodPreset.self, in: context)
        try deleteType(SavedMeal.self, in: context)
        try deleteType(AppSettings.self, in: context)
        try context.save()
    }

    private static func deleteType<T: PersistentModel>(_ type: T.Type, in context: ModelContext) throws {
        let items = try context.fetch(FetchDescriptor<T>())
        for item in items {
            context.delete(item)
        }
    }

    private static func applyPostRestoreSideEffects(settings: AppSettings) {
        WidgetCenter.shared.reloadAllTimelines()
        #if os(iOS)
        PhoneWatchBridge.shared.pushSnapshot()
        #endif
        Task {
            await NotificationService.shared.reschedule(using: settings)
        }
    }
}

// MARK: - Snapshot envelope

struct BackupSnapshot: Codable {
    var format: String
    var version: Int
    var exportedAt: Date
    var appBuild: String
    var dailyLogs: [DailyLogDTO]
    var weights: [WeightEntryDTO]
    var bodyMeasurements: [BodyMeasurementEntryDTO]
    var bodyCompositions: [BodyCompositionReadingDTO]
    var customFoodPresets: [CustomFoodPresetDTO]
    var savedMeals: [SavedMealDTO]
    var settings: AppSettingsDTO?
}

// MARK: - DTOs

struct DailyLogDTO: Codable {
    var id: UUID
    var date: Date
    var proteinGoal: Int
    var ketosis: Bool
    var followedPlan: Bool
    var notes: String
    var waterOz: Int
    var waterDrinksJSON: String?
    var checkedFatsAndVeggies: [String]
    /// Present in backup v2+. Missing on v1 — fats still live in `checkedFatsAndVeggies`.
    var checkedFats: [String]?
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
    var ketoneMmolStored: Double?
    var eatingWindowStartStored: Date?
    var eatingWindowEndStored: Date?
    var offPlanExtraCarbGramsStored: Double?
    var offPlanExtraFatGramsStored: Double?
    var offPlanExtraKcalStored: Int?
    var proteinEntries: [ProteinEntryDTO]
    var workoutEntries: [WorkoutEntryDTO]
    var feelingEntries: [FeelingEntryDTO]

    init(from log: DailyLog) {
        id = log.id
        date = log.date
        proteinGoal = log.proteinGoal
        ketosis = log.ketosis
        followedPlan = log.followedPlan
        notes = log.notes
        waterOz = log.waterOz
        waterDrinksJSON = log.waterDrinksJSON
        checkedFatsAndVeggies = log.checkedFatsAndVeggies
        checkedFats = log.checkedFats
        checkedMiscItems = log.checkedMiscItems
        checkedFruits = log.checkedFruits
        completedSupplements = log.completedSupplements
        offPlanReasonsJSON = log.offPlanReasonsJSON
        cigarettesSmokedStored = log.cigarettesSmokedStored
        cigaretteEventsJSON = log.cigaretteEventsJSON
        cigaretteUrgesJSON = log.cigaretteUrgesJSON
        drinkEventsJSON = log.drinkEventsJSON
        drinkUrgesJSON = log.drinkUrgesJSON
        bathroomEventsJSON = log.bathroomEventsJSON
        ketoneMmolStored = log.ketoneMmolStored
        eatingWindowStartStored = log.eatingWindowStartStored
        eatingWindowEndStored = log.eatingWindowEndStored
        offPlanExtraCarbGramsStored = log.offPlanExtraCarbGramsStored
        offPlanExtraFatGramsStored = log.offPlanExtraFatGramsStored
        offPlanExtraKcalStored = log.offPlanExtraKcalStored
        proteinEntries = log.proteins.map(ProteinEntryDTO.init(from:))
        workoutEntries = log.workouts.map(WorkoutEntryDTO.init(from:))
        feelingEntries = log.feelings.map(FeelingEntryDTO.init(from:))
    }

    func makeModel() -> DailyLog {
        let log = DailyLog(date: date, proteinGoal: proteinGoal)
        log.id = id
        log.date = date
        log.proteinGoal = proteinGoal
        log.ketosis = ketosis
        log.followedPlan = followedPlan
        log.notes = notes
        log.waterOz = waterOz
        log.waterDrinksJSON = waterDrinksJSON
        log.checkedFatsAndVeggies = checkedFatsAndVeggies
        log.checkedFats = checkedFats ?? []
        ChecklistStorage.migrateFatsSplit(on: log)
        log.checkedMiscItems = checkedMiscItems
        log.checkedFruits = checkedFruits
        log.completedSupplements = completedSupplements
        log.offPlanReasonsJSON = offPlanReasonsJSON
        log.cigarettesSmokedStored = cigarettesSmokedStored
        log.cigaretteEventsJSON = cigaretteEventsJSON
        log.cigaretteUrgesJSON = cigaretteUrgesJSON
        log.drinkEventsJSON = drinkEventsJSON
        log.drinkUrgesJSON = drinkUrgesJSON
        log.bathroomEventsJSON = bathroomEventsJSON
        log.ketoneMmolStored = ketoneMmolStored
        log.eatingWindowStartStored = eatingWindowStartStored
        log.eatingWindowEndStored = eatingWindowEndStored
        log.offPlanExtraCarbGramsStored = offPlanExtraCarbGramsStored
        log.offPlanExtraFatGramsStored = offPlanExtraFatGramsStored
        log.offPlanExtraKcalStored = offPlanExtraKcalStored
        log.proteinEntries = []
        log.workoutEntries = []
        log.feelingEntries = []
        return log
    }
}

struct FeelingEntryDTO: Codable {
    var id: UUID
    var type: String
    var timeLogged: Date
    var note: String

    init(from entry: FeelingEntry) {
        id = entry.id
        type = entry.type
        timeLogged = entry.timeLogged
        note = entry.note
    }

    func makeModel() -> FeelingEntry {
        let entry = FeelingEntry(type: type, note: note, timeLogged: timeLogged)
        entry.id = id
        return entry
    }
}

struct ProteinEntryDTO: Codable {
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

    init(from entry: ProteinEntry) {
        id = entry.id
        name = entry.name
        time = entry.time
        servingSize = entry.servingSize
        calories = entry.calories
        hungerBefore = entry.hungerBefore
        hungerAfter = entry.hungerAfter
        proteinCategory = entry.proteinCategory
        servings = entry.servings
        hydrationOzStored = entry.hydrationOzStored
    }

    func makeModel() -> ProteinEntry {
        let entry = ProteinEntry(
            name: name,
            time: time,
            servingSize: servingSize,
            calories: calories,
            hungerBefore: hungerBefore,
            hungerAfter: hungerAfter,
            proteinCategory: proteinCategory,
            servings: servings,
            hydrationOz: hydrationOzStored
        )
        entry.id = id
        entry.hydrationOzStored = hydrationOzStored
        return entry
    }
}

struct WorkoutEntryDTO: Codable {
    var id: UUID
    var activityName: String
    var durationMinutes: Int
    var timeLogged: Date

    init(from entry: WorkoutEntry) {
        id = entry.id
        activityName = entry.activityName
        durationMinutes = entry.durationMinutes
        timeLogged = entry.timeLogged
    }

    func makeModel() -> WorkoutEntry {
        let entry = WorkoutEntry(activityName: activityName, durationMinutes: durationMinutes, timeLogged: timeLogged)
        entry.id = id
        return entry
    }
}

struct WeightEntryDTO: Codable {
    var id: UUID
    var date: Date
    var weightLbs: Double
    var timeLogged: Date

    init(from entry: WeightEntry) {
        id = entry.id
        date = entry.date
        weightLbs = entry.weightLbs
        timeLogged = entry.timeLogged
    }

    func makeModel() -> WeightEntry {
        let entry = WeightEntry(date: date, weightLbs: weightLbs, timeLogged: timeLogged)
        entry.id = id
        entry.date = date
        return entry
    }
}

struct BodyMeasurementEntryDTO: Codable {
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

    init(from entry: BodyMeasurementEntry) {
        id = entry.id
        date = entry.date
        neckInchesStored = entry.neckInchesStored
        chestInchesStored = entry.chestInchesStored
        waistInchesStored = entry.waistInchesStored
        hipsInchesStored = entry.hipsInchesStored
        leftArmInchesStored = entry.leftArmInchesStored
        rightArmInchesStored = entry.rightArmInchesStored
        leftThighInchesStored = entry.leftThighInchesStored
        rightThighInchesStored = entry.rightThighInchesStored
        notes = entry.notes
        createdAt = entry.createdAt
    }

    func makeModel() -> BodyMeasurementEntry {
        let entry = BodyMeasurementEntry(
            date: date,
            neckInches: neckInchesStored,
            chestInches: chestInchesStored,
            waistInches: waistInchesStored,
            hipsInches: hipsInchesStored,
            leftArmInches: leftArmInchesStored,
            rightArmInches: rightArmInchesStored,
            leftThighInches: leftThighInchesStored,
            rightThighInches: rightThighInchesStored,
            notes: notes
        )
        entry.id = id
        entry.date = date
        entry.createdAt = createdAt
        return entry
    }
}

struct BodyCompositionReadingDTO: Codable {
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

    init(from reading: BodyCompositionReading) {
        id = reading.id
        date = reading.date
        proteinGoalText = reading.proteinGoalText
        waterTargetText = reading.waterTargetText
        bodyTypeRaw = reading.bodyTypeRaw
        genderRaw = reading.genderRaw
        age = reading.age
        heightInches = reading.heightInches
        weightLbs = reading.weightLbs
        bmi = reading.bmi
        bmrKcal = reading.bmrKcal
        impedance = reading.impedance
        fatPercent = reading.fatPercent
        fatMassLbs = reading.fatMassLbs
        ffmLbs = reading.ffmLbs
        tbwLbs = reading.tbwLbs
        desirableFatPercentLow = reading.desirableFatPercentLow
        desirableFatPercentHigh = reading.desirableFatPercentHigh
        desirableFatMassLow = reading.desirableFatMassLow
        desirableFatMassHigh = reading.desirableFatMassHigh
        notes = reading.notes
        createdAt = reading.createdAt
    }

    func makeModel() -> BodyCompositionReading {
        let reading = BodyCompositionReading(
            date: date,
            proteinGoalText: proteinGoalText,
            waterTargetText: waterTargetText,
            bodyType: BodyCompositionBodyType(rawValue: bodyTypeRaw) ?? .standard,
            gender: BodyCompositionGender(rawValue: genderRaw) ?? .male,
            age: age,
            heightInches: heightInches,
            weightLbs: weightLbs,
            bmi: bmi,
            bmrKcal: bmrKcal,
            impedance: impedance,
            fatPercent: fatPercent,
            fatMassLbs: fatMassLbs,
            ffmLbs: ffmLbs,
            tbwLbs: tbwLbs,
            desirableFatPercentLow: desirableFatPercentLow,
            desirableFatPercentHigh: desirableFatPercentHigh,
            desirableFatMassLow: desirableFatMassLow,
            desirableFatMassHigh: desirableFatMassHigh,
            notes: notes
        )
        reading.id = id
        reading.date = date
        reading.bodyTypeRaw = bodyTypeRaw
        reading.genderRaw = genderRaw
        reading.createdAt = createdAt
        return reading
    }
}

struct CustomFoodPresetDTO: Codable {
    var id: UUID
    var name: String
    var servingLabel: String
    var calories: Int
    var category: String
    var proteinCategory: String
    var servingsPerUnit: Double

    init(from preset: CustomFoodPreset) {
        id = preset.id
        name = preset.name
        servingLabel = preset.servingLabel
        calories = preset.calories
        category = preset.category
        proteinCategory = preset.proteinCategory
        servingsPerUnit = preset.servingsPerUnit
    }

    func makeModel() -> CustomFoodPreset {
        let preset = CustomFoodPreset(
            name: name,
            servingLabel: servingLabel,
            calories: calories,
            category: category,
            proteinCategory: proteinCategory,
            servingsPerUnit: servingsPerUnit
        )
        preset.id = id
        return preset
    }
}

struct SavedMealDTO: Codable {
    var id: UUID
    var name: String
    var createdAt: Date
    var componentsJSON: String

    init(from meal: SavedMeal) {
        id = meal.id
        name = meal.name
        createdAt = meal.createdAt
        componentsJSON = meal.componentsJSON
    }

    func makeModel() -> SavedMeal {
        let meal = SavedMeal(name: name, components: [], createdAt: createdAt)
        meal.id = id
        meal.componentsJSON = componentsJSON
        return meal
    }
}

struct AppSettingsDTO: Codable {
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
    var bodyCompReminderEnabledStored: Bool?
    var bodyCompReminderCadenceRaw: String?
    var bodyCompReminderWeekdayStored: Int?
    var bodyCompReminderDayOfMonthStored: Int?
    var bodyCompReminderHourStored: Int?
    var bodyCompReminderMinuteStored: Int?
    var ageYearsStored: Int?
    var fastingEnabledStored: Bool?
    var fastingPresetRaw: String?
    var fastingCustomFastHoursStored: Double?
    var fastingEatStartHourStored: Int?
    var fastingEatStartMinuteStored: Int?
    var fastingNotifyOpenEnabledStored: Bool?
    var fastingNotifyOpenMinutesStored: Int?
    var fastingNotifyCloseEnabledStored: Bool?
    var fastingNotifyCloseMinutesStored: Int?
    var fastingNotifyOvertimeEnabledStored: Bool?

    init(from settings: AppSettings) {
        id = settings.id
        programPhase = settings.programPhase
        heightInches = settings.heightInches
        usesMetricWeight = settings.usesMetricWeight
        defaultProteinGoal = settings.defaultProteinGoal
        waterReminderEnabled = settings.waterReminderEnabled
        waterReminderIntervalHours = settings.waterReminderIntervalHours
        eveningCheckInEnabled = settings.eveningCheckInEnabled
        eveningCheckInHour = settings.eveningCheckInHour
        eveningCheckInMinute = settings.eveningCheckInMinute
        supplementDefinitionsJSON = settings.supplementDefinitionsJSON
        defaultBottleOzStored = settings.defaultBottleOzStored
        hydrationTargetOzStored = settings.hydrationTargetOzStored
        showSupplementsSectionStored = settings.showSupplementsSectionStored
        showBathroomSectionStored = settings.showBathroomSectionStored
        accentThemeRaw = settings.accentThemeRaw
        customAccentHexStored = settings.customAccentHexStored
        appearanceModeRaw = settings.appearanceModeRaw
        weightSectionCollapsedStored = settings.weightSectionCollapsedStored
        collapsedSectionsJSON = settings.collapsedSectionsJSON
        notificationsDefaultsVersionStored = settings.notificationsDefaultsVersionStored
        notificationsPausedStored = settings.notificationsPausedStored
        genericCheckInEnabledStored = settings.genericCheckInEnabledStored
        genericCheckInHourStored = settings.genericCheckInHourStored
        genericCheckInMinuteStored = settings.genericCheckInMinuteStored
        mealReminderEnabledStored = settings.mealReminderEnabledStored
        mealReminderHourStored = settings.mealReminderHourStored
        mealReminderMinuteStored = settings.mealReminderMinuteStored
        weighReminderEnabledStored = settings.weighReminderEnabledStored
        weighReminderHourStored = settings.weighReminderHourStored
        weighReminderMinuteStored = settings.weighReminderMinuteStored
        ketosisCheckInEnabledStored = settings.ketosisCheckInEnabledStored
        ketosisCheckInHourStored = settings.ketosisCheckInHourStored
        ketosisCheckInMinuteStored = settings.ketosisCheckInMinuteStored
        excludedFoodsJSON = settings.excludedFoodsJSON
        preferredFoodsJSON = settings.preferredFoodsJSON
        customOffPlanReasonsJSON = settings.customOffPlanReasonsJSON
        goalWeightLbsStored = settings.goalWeightLbsStored
        smokingModeRaw = settings.smokingModeRaw
        dailyCigaretteLimitStored = settings.dailyCigaretteLimitStored
        quitDateStored = settings.quitDateStored
        cigarettesPerPackStored = settings.cigarettesPerPackStored
        cigarettePackPriceStored = settings.cigarettePackPriceStored
        drinkingModeRaw = settings.drinkingModeRaw
        dailyDrinkLimitStored = settings.dailyDrinkLimitStored
        alcoholQuitDateStored = settings.alcoholQuitDateStored
        smokingCheckInEnabledStored = settings.smokingCheckInEnabledStored
        smokingCheckInHourStored = settings.smokingCheckInHourStored
        smokingCheckInMinuteStored = settings.smokingCheckInMinuteStored
        drinkingCheckInEnabledStored = settings.drinkingCheckInEnabledStored
        drinkingCheckInHourStored = settings.drinkingCheckInHourStored
        drinkingCheckInMinuteStored = settings.drinkingCheckInMinuteStored
        motivationReminderEnabledStored = settings.motivationReminderEnabledStored
        motivationReminderHourStored = settings.motivationReminderHourStored
        motivationReminderMinuteStored = settings.motivationReminderMinuteStored
        customMotivationQuotesJSON = settings.customMotivationQuotesJSON
        sectionOrderJSON = settings.sectionOrderJSON
        proteinDrinksCountTowardHydrationStored = settings.proteinDrinksCountTowardHydrationStored
        defaultShakeHydrationOzStored = settings.defaultShakeHydrationOzStored
        bodyCompReminderEnabledStored = settings.bodyCompReminderEnabledStored
        bodyCompReminderCadenceRaw = settings.bodyCompReminderCadenceRaw
        bodyCompReminderWeekdayStored = settings.bodyCompReminderWeekdayStored
        bodyCompReminderDayOfMonthStored = settings.bodyCompReminderDayOfMonthStored
        bodyCompReminderHourStored = settings.bodyCompReminderHourStored
        bodyCompReminderMinuteStored = settings.bodyCompReminderMinuteStored
        ageYearsStored = settings.ageYearsStored
        fastingEnabledStored = settings.fastingEnabledStored
        fastingPresetRaw = settings.fastingPresetRaw
        fastingCustomFastHoursStored = settings.fastingCustomFastHoursStored
        fastingEatStartHourStored = settings.fastingEatStartHourStored
        fastingEatStartMinuteStored = settings.fastingEatStartMinuteStored
        fastingNotifyOpenEnabledStored = settings.fastingNotifyOpenEnabledStored
        fastingNotifyOpenMinutesStored = settings.fastingNotifyOpenMinutesStored
        fastingNotifyCloseEnabledStored = settings.fastingNotifyCloseEnabledStored
        fastingNotifyCloseMinutesStored = settings.fastingNotifyCloseMinutesStored
        fastingNotifyOvertimeEnabledStored = settings.fastingNotifyOvertimeEnabledStored
    }

    func makeModel() -> AppSettings {
        let settings = AppSettings()
        settings.id = id
        settings.programPhase = programPhase
        settings.heightInches = heightInches
        settings.usesMetricWeight = usesMetricWeight
        settings.defaultProteinGoal = defaultProteinGoal
        settings.waterReminderEnabled = waterReminderEnabled
        settings.waterReminderIntervalHours = waterReminderIntervalHours
        settings.eveningCheckInEnabled = eveningCheckInEnabled
        settings.eveningCheckInHour = eveningCheckInHour
        settings.eveningCheckInMinute = eveningCheckInMinute
        settings.supplementDefinitionsJSON = supplementDefinitionsJSON
        settings.defaultBottleOzStored = defaultBottleOzStored
        settings.hydrationTargetOzStored = hydrationTargetOzStored
        settings.showSupplementsSectionStored = showSupplementsSectionStored
        settings.showBathroomSectionStored = showBathroomSectionStored
        settings.accentThemeRaw = accentThemeRaw
        settings.customAccentHexStored = customAccentHexStored
        settings.appearanceModeRaw = appearanceModeRaw
        settings.weightSectionCollapsedStored = weightSectionCollapsedStored
        settings.collapsedSectionsJSON = collapsedSectionsJSON
        settings.notificationsDefaultsVersionStored = notificationsDefaultsVersionStored
        settings.notificationsPausedStored = notificationsPausedStored
        settings.genericCheckInEnabledStored = genericCheckInEnabledStored
        settings.genericCheckInHourStored = genericCheckInHourStored
        settings.genericCheckInMinuteStored = genericCheckInMinuteStored
        settings.mealReminderEnabledStored = mealReminderEnabledStored
        settings.mealReminderHourStored = mealReminderHourStored
        settings.mealReminderMinuteStored = mealReminderMinuteStored
        settings.weighReminderEnabledStored = weighReminderEnabledStored
        settings.weighReminderHourStored = weighReminderHourStored
        settings.weighReminderMinuteStored = weighReminderMinuteStored
        settings.ketosisCheckInEnabledStored = ketosisCheckInEnabledStored
        settings.ketosisCheckInHourStored = ketosisCheckInHourStored
        settings.ketosisCheckInMinuteStored = ketosisCheckInMinuteStored
        settings.excludedFoodsJSON = excludedFoodsJSON
        settings.preferredFoodsJSON = preferredFoodsJSON
        settings.customOffPlanReasonsJSON = customOffPlanReasonsJSON
        settings.goalWeightLbsStored = goalWeightLbsStored
        settings.smokingModeRaw = smokingModeRaw
        settings.dailyCigaretteLimitStored = dailyCigaretteLimitStored
        settings.quitDateStored = quitDateStored
        settings.cigarettesPerPackStored = cigarettesPerPackStored
        settings.cigarettePackPriceStored = cigarettePackPriceStored
        settings.drinkingModeRaw = drinkingModeRaw
        settings.dailyDrinkLimitStored = dailyDrinkLimitStored
        settings.alcoholQuitDateStored = alcoholQuitDateStored
        settings.smokingCheckInEnabledStored = smokingCheckInEnabledStored
        settings.smokingCheckInHourStored = smokingCheckInHourStored
        settings.smokingCheckInMinuteStored = smokingCheckInMinuteStored
        settings.drinkingCheckInEnabledStored = drinkingCheckInEnabledStored
        settings.drinkingCheckInHourStored = drinkingCheckInHourStored
        settings.drinkingCheckInMinuteStored = drinkingCheckInMinuteStored
        settings.motivationReminderEnabledStored = motivationReminderEnabledStored
        settings.motivationReminderHourStored = motivationReminderHourStored
        settings.motivationReminderMinuteStored = motivationReminderMinuteStored
        settings.customMotivationQuotesJSON = customMotivationQuotesJSON
        settings.sectionOrderJSON = sectionOrderJSON
        settings.proteinDrinksCountTowardHydrationStored = proteinDrinksCountTowardHydrationStored
        settings.defaultShakeHydrationOzStored = defaultShakeHydrationOzStored
        settings.bodyCompReminderEnabledStored = bodyCompReminderEnabledStored
        settings.bodyCompReminderCadenceRaw = bodyCompReminderCadenceRaw
        settings.bodyCompReminderWeekdayStored = bodyCompReminderWeekdayStored
        settings.bodyCompReminderDayOfMonthStored = bodyCompReminderDayOfMonthStored
        settings.bodyCompReminderHourStored = bodyCompReminderHourStored
        settings.bodyCompReminderMinuteStored = bodyCompReminderMinuteStored
        settings.ageYearsStored = ageYearsStored
        settings.fastingEnabledStored = fastingEnabledStored
        settings.fastingPresetRaw = fastingPresetRaw
        settings.fastingCustomFastHoursStored = fastingCustomFastHoursStored
        settings.fastingEatStartHourStored = fastingEatStartHourStored
        settings.fastingEatStartMinuteStored = fastingEatStartMinuteStored
        settings.fastingNotifyOpenEnabledStored = fastingNotifyOpenEnabledStored
        settings.fastingNotifyOpenMinutesStored = fastingNotifyOpenMinutesStored
        settings.fastingNotifyCloseEnabledStored = fastingNotifyCloseEnabledStored
        settings.fastingNotifyCloseMinutesStored = fastingNotifyCloseMinutesStored
        settings.fastingNotifyOvertimeEnabledStored = fastingNotifyOvertimeEnabledStored
        return settings
    }
}
