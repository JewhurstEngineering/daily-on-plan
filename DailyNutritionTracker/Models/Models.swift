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
    /// JSON array of slot values; `null`/omitted means empty. Example: `[16.9, 24.0, null]`.
    var waterDrinksJSON: String?
    @Relationship(deleteRule: .cascade) var proteinEntries: [ProteinEntry]
    @Relationship(deleteRule: .cascade) var workoutEntries: [WorkoutEntry]
    @Relationship(deleteRule: .cascade) var feelingEntries: [FeelingEntry]
    var checkedFatsAndVeggies: [String]
    var checkedMiscItems: [String]
    var checkedFruits: [String]
    var completedSupplements: [String]
    /// JSON array of off-plan reason tags (e.g. Pizza, Beer). Meaningful when followedPlan is false.
    var offPlanReasonsJSON: String?

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
        self.offPlanReasonsJSON = "[]"
    }

    var offPlanReasons: [String] {
        get {
            guard let data = offPlanReasonsJSON?.data(using: .utf8),
                  let decoded = try? JSONDecoder().decode([String].self, from: data) else {
                return []
            }
            return decoded
        }
        set {
            if let data = try? JSONEncoder().encode(newValue),
               let string = String(data: data, encoding: .utf8) {
                offPlanReasonsJSON = string
            } else {
                offPlanReasonsJSON = "[]"
            }
        }
    }

    func toggleOffPlanReason(_ reason: String) {
        var list = offPlanReasons
        if let idx = list.firstIndex(where: { $0.caseInsensitiveCompare(reason) == .orderedSame }) {
            list.remove(at: idx)
        } else {
            list.append(reason)
        }
        offPlanReasons = list
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

    var waterSlots: [Double?] {
        get {
            if let data = waterDrinksJSON?.data(using: .utf8),
               let decoded = try? JSONDecoder().decode([Double].self, from: data) {
                // Sentinel -1 = empty slot. Positive values = filled oz.
                // Legacy filled-only arrays never used -1, so they map 1:1 as filled.
                return decoded.map { $0 < 0 ? nil : Optional($0) }
            }
            if waterOz > 0 { return [Double(waterOz)] }
            return []
        }
        set {
            let encoded = newValue.map { $0 ?? -1 }
            if let data = try? JSONEncoder().encode(encoded),
               let string = String(data: data, encoding: .utf8) {
                waterDrinksJSON = string
            } else {
                waterDrinksJSON = "[]"
            }
            waterOz = Int(newValue.compactMap { $0 }.reduce(0, +).rounded())
        }
    }

    /// Filled drinks only (for suggestions / totals helpers).
    var waterDrinks: [Double] {
        waterSlots.compactMap { $0 }
    }

    func ensureWaterSlotCount(_ count: Int) {
        var slots = waterSlots
        while slots.count < count { slots.append(nil) }
        if slots.count > count {
            // Keep filled extras; only trim trailing empties beyond count if all trailing empty
            while slots.count > count, slots.last == nil {
                slots.removeLast()
            }
        }
        waterSlots = slots
    }

    func toggleWaterSlot(at index: Int, fillOz: Double) {
        var slots = waterSlots
        while slots.count <= index { slots.append(nil) }
        if slots[index] != nil {
            slots[index] = nil
        } else {
            slots[index] = fillOz
        }
        waterSlots = slots
    }

    func appendFilledWaterSlot(oz: Double) {
        var slots = waterSlots
        slots.append(oz)
        waterSlots = slots
    }

    /// Fills the first empty slot, or appends if all filled.
    func fillNextWaterSlot(oz: Double, ensuringMinimumSlots minimum: Int = 1) {
        var slots = waterSlots
        while slots.count < minimum { slots.append(nil) }
        if let empty = slots.firstIndex(where: { $0 == nil }) {
            slots[empty] = oz
        } else {
            slots.append(oz)
        }
        waterSlots = slots
    }

    func clearWaterDrinks() {
        waterSlots = []
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
final class SavedMeal {
    var id: UUID
    var name: String
    var createdAt: Date
    var componentsJSON: String

    init(name: String, components: [MealComponent] = [], createdAt: Date = Date()) {
        self.id = UUID()
        self.name = name
        self.createdAt = createdAt
        if let data = try? JSONEncoder().encode(components),
           let string = String(data: data, encoding: .utf8) {
            self.componentsJSON = string
        } else {
            self.componentsJSON = "[]"
        }
    }

    var components: [MealComponent] {
        get {
            guard let data = componentsJSON.data(using: .utf8),
                  let decoded = try? JSONDecoder().decode([MealComponent].self, from: data) else {
                return []
            }
            return decoded
        }
        set {
            if let data = try? JSONEncoder().encode(newValue),
               let string = String(data: data, encoding: .utf8) {
                componentsJSON = string
            } else {
                componentsJSON = "[]"
            }
        }
    }

    var proteinCalories: Int {
        components
            .filter { $0.category == .protein }
            .reduce(0) { $0 + $1.totalCalories }
    }

    var summary: String {
        let names = components.map(\.name)
        if names.isEmpty { return "Empty meal" }
        if names.count <= 3 { return names.joined(separator: " · ") }
        return names.prefix(3).joined(separator: " · ") + " +\(names.count - 3)"
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
    var accentThemeRaw: String?
    var weightSectionCollapsedStored: Bool?
    var collapsedSectionsJSON: String?

    // Notifications (v2) — optionals for SwiftData-friendly migration
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

    init() {
        self.id = UUID()
        self.programPhase = ProgramPhase.week1.rawValue
        self.heightInches = 0
        self.usesMetricWeight = false
        self.defaultProteinGoal = 500
        self.waterReminderEnabled = false
        self.waterReminderIntervalHours = 3
        self.eveningCheckInEnabled = true
        self.eveningCheckInHour = 20
        self.eveningCheckInMinute = 0
        self.supplementDefinitionsJSON = SupplementDefinition.defaultJSON
        self.defaultBottleOzStored = AppLimits.defaultBottleOz
        self.hydrationTargetOzStored = AppLimits.hydrationTargetOz
        self.showSupplementsSectionStored = true
        self.accentThemeRaw = AccentTheme.onPlan.rawValue
        self.weightSectionCollapsedStored = false
        self.collapsedSectionsJSON = "{}"
        self.notificationsDefaultsVersionStored = 3
        self.notificationsPausedStored = false
        self.genericCheckInEnabledStored = true
        self.genericCheckInHourStored = 19
        self.genericCheckInMinuteStored = 30
        self.mealReminderEnabledStored = false
        self.mealReminderHourStored = 12
        self.mealReminderMinuteStored = 0
        self.weighReminderEnabledStored = false
        self.weighReminderHourStored = 7
        self.weighReminderMinuteStored = 0
        self.ketosisCheckInEnabledStored = true
        self.ketosisCheckInHourStored = 20
        self.ketosisCheckInMinuteStored = 5
        self.excludedFoodsJSON = "[]"
        self.preferredFoodsJSON = "[]"
        self.customOffPlanReasonsJSON = "[]"
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

    var accentTheme: AccentTheme {
        get {
            if let theme = AccentTheme(rawValue: accentThemeRaw ?? "") {
                return theme
            }
            // Legacy accents from before OnPlan role-based themes.
            switch accentThemeRaw {
            case "teal", "blue", "indigo", "purple", "pink", "orange", "red", "brown":
                return .onPlan
            default:
                return .onPlan
            }
        }
        set { accentThemeRaw = newValue.rawValue }
    }

    var weightSectionCollapsed: Bool {
        get { isSectionCollapsed(.weight) }
        set { setSectionCollapsed(.weight, newValue) }
    }

    var ketosisCheckInEnabled: Bool {
        get { ketosisCheckInEnabledStored ?? true }
        set { ketosisCheckInEnabledStored = newValue }
    }

    var ketosisCheckInHour: Int {
        get { ketosisCheckInHourStored ?? 20 }
        set { ketosisCheckInHourStored = newValue }
    }

    var ketosisCheckInMinute: Int {
        get { ketosisCheckInMinuteStored ?? 5 }
        set { ketosisCheckInMinuteStored = newValue }
    }

    func isSectionCollapsed(_ section: DaySectionID) -> Bool {
        let map = collapsedSectionsMap
        if let value = map[section.rawValue] { return value }
        // Legacy single-flag migration for weight privacy collapse.
        if section == .weight {
            return weightSectionCollapsedStored ?? false
        }
        return false
    }

    func setSectionCollapsed(_ section: DaySectionID, _ collapsed: Bool) {
        var map = collapsedSectionsMap
        map[section.rawValue] = collapsed
        if section == .weight {
            weightSectionCollapsedStored = collapsed
        }
        collapsedSectionsMap = map
    }

    private var collapsedSectionsMap: [String: Bool] {
        get {
            guard let data = collapsedSectionsJSON?.data(using: .utf8),
                  let decoded = try? JSONDecoder().decode([String: Bool].self, from: data) else {
                return [:]
            }
            return decoded
        }
        set {
            if let data = try? JSONEncoder().encode(newValue),
               let string = String(data: data, encoding: .utf8) {
                collapsedSectionsJSON = string
            } else {
                collapsedSectionsJSON = "{}"
            }
        }
    }

    var notificationsPaused: Bool {
        get { notificationsPausedStored ?? false }
        set { notificationsPausedStored = newValue }
    }

    var genericCheckInEnabled: Bool {
        get { genericCheckInEnabledStored ?? true }
        set { genericCheckInEnabledStored = newValue }
    }

    var genericCheckInHour: Int {
        get { genericCheckInHourStored ?? 19 }
        set { genericCheckInHourStored = newValue }
    }

    var genericCheckInMinute: Int {
        get { genericCheckInMinuteStored ?? 30 }
        set { genericCheckInMinuteStored = newValue }
    }

    var mealReminderEnabled: Bool {
        get { mealReminderEnabledStored ?? false }
        set { mealReminderEnabledStored = newValue }
    }

    var mealReminderHour: Int {
        get { mealReminderHourStored ?? 12 }
        set { mealReminderHourStored = newValue }
    }

    var mealReminderMinute: Int {
        get { mealReminderMinuteStored ?? 0 }
        set { mealReminderMinuteStored = newValue }
    }

    var weighReminderEnabled: Bool {
        get { weighReminderEnabledStored ?? false }
        set { weighReminderEnabledStored = newValue }
    }

    var weighReminderHour: Int {
        get { weighReminderHourStored ?? 7 }
        set { weighReminderHourStored = newValue }
    }

    var weighReminderMinute: Int {
        get { weighReminderMinuteStored ?? 0 }
        set { weighReminderMinuteStored = newValue }
    }

    var excludedFoodNames: [String] {
        get { Self.decodeStringList(excludedFoodsJSON) }
        set { excludedFoodsJSON = Self.encodeStringList(newValue) }
    }

    var preferredFoodNames: [String] {
        get { Self.decodeStringList(preferredFoodsJSON) }
        set { preferredFoodsJSON = Self.encodeStringList(newValue) }
    }

    var customOffPlanReasons: [String] {
        get { Self.decodeStringList(customOffPlanReasonsJSON) }
        set { customOffPlanReasonsJSON = Self.encodeStringList(newValue) }
    }

    /// Presets + user customs, presets first, no duplicates.
    var allOffPlanReasonOptions: [String] {
        var seen = Set<String>()
        var result: [String] = []
        for name in OffPlanReasonCatalog.presets + customOffPlanReasons {
            let key = name.lowercased()
            guard !seen.contains(key) else { continue }
            seen.insert(key)
            result.append(name)
        }
        return result
    }

    func addCustomOffPlanReason(_ raw: String) -> String? {
        let trimmed = String(raw.trimmingCharacters(in: .whitespacesAndNewlines).prefix(OffPlanReasonCatalog.maxCustomLength))
        guard !trimmed.isEmpty else { return nil }
        if OffPlanReasonCatalog.presets.contains(where: { $0.caseInsensitiveCompare(trimmed) == .orderedSame }) {
            return OffPlanReasonCatalog.presets.first { $0.caseInsensitiveCompare(trimmed) == .orderedSame }
        }
        var customs = customOffPlanReasons
        if let existing = customs.first(where: { $0.caseInsensitiveCompare(trimmed) == .orderedSame }) {
            return existing
        }
        customs.append(trimmed)
        customOffPlanReasons = customs
        return trimmed
    }

    func isExcluded(_ name: String) -> Bool {
        excludedFoodNames.contains { $0.caseInsensitiveCompare(name) == .orderedSame }
    }

    func isPreferred(_ name: String) -> Bool {
        preferredFoodNames.contains { $0.caseInsensitiveCompare(name) == .orderedSame }
    }

    /// One-time migration: turn water off; keep evening on; enable generic check-in.
    func migrateNotificationDefaultsIfNeeded() {
        let version = notificationsDefaultsVersionStored ?? 0
        if version < 1 {
            waterReminderEnabled = false
            if waterReminderIntervalHours < 2 { waterReminderIntervalHours = 3 }
            eveningCheckInEnabled = true
            genericCheckInEnabled = true
            mealReminderEnabled = false
            weighReminderEnabled = false
            notificationsPaused = false
            notificationsDefaultsVersionStored = 1
        }
        if (notificationsDefaultsVersionStored ?? 0) < 2 {
            ketosisCheckInEnabled = true
            if ketosisCheckInHourStored == nil {
                ketosisCheckInHour = eveningCheckInHour
                ketosisCheckInMinute = min(eveningCheckInMinute + 5, 59)
            }
            notificationsDefaultsVersionStored = 2
        }
        if (notificationsDefaultsVersionStored ?? 0) < 3 {
            // Force OnPlan Default theme (role-based brand accents).
            accentTheme = .onPlan
            notificationsDefaultsVersionStored = 3
        }
    }

    private static func decodeStringList(_ json: String?) -> [String] {
        guard let data = json?.data(using: .utf8),
              let decoded = try? JSONDecoder().decode([String].self, from: data) else {
            return []
        }
        return decoded
    }

    private static func encodeStringList(_ list: [String]) -> String {
        guard let data = try? JSONEncoder().encode(list),
              let string = String(data: data, encoding: .utf8) else {
            return "[]"
        }
        return string
    }
}
