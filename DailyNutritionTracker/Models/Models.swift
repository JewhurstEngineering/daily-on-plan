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
    /// Vegetables (and any leftover uncategorized items). Fats used to live here too.
    var checkedFatsAndVeggies: [String]
    /// Dedicated fats list. Empty on v1 stores until `ChecklistStorage.migrateFatsSplit` runs.
    var checkedFats: [String] = []
    var checkedMiscItems: [String]
    var checkedFruits: [String]
    var completedSupplements: [String]
    /// JSON array of off-plan reason tags (e.g. Pizza, Beer). Meaningful when followedPlan is false.
    var offPlanReasonsJSON: String?
    var cigarettesSmokedStored: Int?
    /// JSON array of `{id,timeLogged,count}` smoke events (preferred).
    var cigaretteEventsJSON: String?
    /// JSON array of `{id,timeLogged,note}` urge records (quit mode).
    var cigaretteUrgesJSON: String?
    /// JSON array of `{id,timeLogged,count}` drink events.
    var drinkEventsJSON: String?
    /// JSON array of `{id,timeLogged,note}` drinking urge records.
    var drinkUrgesJSON: String?
    /// JSON array of bathroom events `{id,kind,timeLogged,note}`.
    var bathroomEventsJSON: String?

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
        self.checkedFats = []
        self.checkedMiscItems = []
        self.checkedFruits = []
        self.completedSupplements = []
        self.offPlanReasonsJSON = "[]"
        self.cigarettesSmokedStored = 0
        self.cigaretteEventsJSON = "[]"
        self.cigaretteUrgesJSON = "[]"
        self.drinkEventsJSON = "[]"
        self.drinkUrgesJSON = "[]"
        self.bathroomEventsJSON = "[]"
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

    var waterSlots: [WaterSlotRecord?] {
        get {
            if let data = waterDrinksJSON?.data(using: .utf8) {
                if let decoded = try? JSONDecoder().decode([WaterSlotStored].self, from: data) {
                    return decoded.map(\.asRecord)
                }
                if let legacy = try? JSONDecoder().decode([Double].self, from: data) {
                    // Sentinel -1 = empty slot. Positive values = filled oz.
                    return legacy.map { $0 < 0 ? nil : WaterSlotRecord(oz: $0) }
                }
            }
            if waterOz > 0 { return [WaterSlotRecord(oz: Double(waterOz))] }
            return []
        }
        set {
            let encoded = newValue.map(WaterSlotStored.init(from:))
            if let data = try? JSONEncoder().encode(encoded),
               let string = String(data: data, encoding: .utf8) {
                waterDrinksJSON = string
            } else {
                waterDrinksJSON = "[]"
            }
            waterOz = Int(newValue.compactMap { $0?.oz }.reduce(0, +).rounded())
        }
    }

    /// Filled drinks only (for suggestions / totals helpers).
    var waterDrinks: [Double] {
        waterSlots.compactMap { $0?.oz }
    }

    var electrolyteDrinkCount: Int {
        waterSlots.compactMap { $0 }.filter(\.isElectrolyte).count
    }

    var hasElectrolyteDrink: Bool {
        electrolyteDrinkCount > 0
    }

    /// Slot ounces only (does not include protein shakes).
    var slotWaterOz: Int {
        Int(waterSlots.compactMap { $0?.oz }.reduce(0, +).rounded())
    }

    func proteinHydrationOz(settings: AppSettings) -> Int {
        guard settings.proteinDrinksCountTowardHydration else { return 0 }
        let total = proteinEntries.reduce(0.0) { $0 + $1.hydrationOz }
        return Int(total.rounded())
    }

    /// Slot water + optional protein-drink ounces.
    func totalHydrationOz(settings: AppSettings) -> Int {
        slotWaterOz + proteinHydrationOz(settings: settings)
    }

    var cigaretteEvents: [CigaretteEventRecord] {
        get {
            if let data = cigaretteEventsJSON?.data(using: .utf8),
               let decoded = try? JSONDecoder().decode([CigaretteEventRecord].self, from: data),
               !decoded.isEmpty {
                return decoded.sorted { $0.timeLogged < $1.timeLogged }
            }
            // Migrate legacy bare count into a single undated-today event once.
            let legacy = max(0, cigarettesSmokedStored ?? 0)
            if legacy > 0 {
                return [CigaretteEventRecord(timeLogged: date, count: legacy)]
            }
            return []
        }
        set {
            if let data = try? JSONEncoder().encode(newValue),
               let string = String(data: data, encoding: .utf8) {
                cigaretteEventsJSON = string
            } else {
                cigaretteEventsJSON = "[]"
            }
            let total = newValue.reduce(0) { $0 + max(0, $1.count) }
            cigarettesSmokedStored = total
        }
    }

    var cigarettesSmoked: Int {
        cigaretteEvents.reduce(0) { $0 + max(0, $1.count) }
    }

    var packsSmoked: Double {
        CigarettePackMath.packs(forCigarettes: cigarettesSmoked)
    }

    var cigaretteUrges: [CigaretteUrgeRecord] {
        get {
            guard let data = cigaretteUrgesJSON?.data(using: .utf8),
                  let decoded = try? JSONDecoder().decode([CigaretteUrgeRecord].self, from: data) else {
                return []
            }
            return decoded.sorted { $0.timeLogged < $1.timeLogged }
        }
        set {
            if let data = try? JSONEncoder().encode(newValue),
               let string = String(data: data, encoding: .utf8) {
                cigaretteUrgesJSON = string
            } else {
                cigaretteUrgesJSON = "[]"
            }
        }
    }

    func addCigarettes(_ count: Int = 1, timeLogged: Date = Date()) {
        guard count > 0 else { return }
        var list = cigaretteEvents
        list.append(CigaretteEventRecord(timeLogged: timeLogged, count: count))
        cigaretteEvents = list
    }

    func addCigarette() {
        addCigarettes(1)
    }

    func removeLastCigaretteEvent() {
        var list = cigaretteEvents
        guard !list.isEmpty else { return }
        list.removeLast()
        cigaretteEvents = list
    }

    func removeCigaretteEvent(id: UUID) {
        cigaretteEvents = cigaretteEvents.filter { $0.id != id }
    }

    func addUrge(note: String = "", timeLogged: Date = Date()) {
        var list = cigaretteUrges
        list.append(CigaretteUrgeRecord(timeLogged: timeLogged, note: note))
        cigaretteUrges = list
    }

    func removeUrge(id: UUID) {
        cigaretteUrges = cigaretteUrges.filter { $0.id != id }
    }

    var drinkEvents: [DrinkEventRecord] {
        get {
            guard let data = drinkEventsJSON?.data(using: .utf8),
                  let decoded = try? JSONDecoder().decode([DrinkEventRecord].self, from: data) else {
                return []
            }
            return decoded.sorted { $0.timeLogged < $1.timeLogged }
        }
        set {
            if let data = try? JSONEncoder().encode(newValue),
               let string = String(data: data, encoding: .utf8) {
                drinkEventsJSON = string
            } else {
                drinkEventsJSON = "[]"
            }
        }
    }

    var drinksLogged: Int {
        drinkEvents.reduce(0) { $0 + max(0, $1.count) }
    }

    var drinkUrges: [DrinkUrgeRecord] {
        get {
            guard let data = drinkUrgesJSON?.data(using: .utf8),
                  let decoded = try? JSONDecoder().decode([DrinkUrgeRecord].self, from: data) else {
                return []
            }
            return decoded.sorted { $0.timeLogged < $1.timeLogged }
        }
        set {
            if let data = try? JSONEncoder().encode(newValue),
               let string = String(data: data, encoding: .utf8) {
                drinkUrgesJSON = string
            } else {
                drinkUrgesJSON = "[]"
            }
        }
    }

    func addDrinks(_ count: Int = 1, timeLogged: Date = Date()) {
        guard count > 0 else { return }
        var list = drinkEvents
        list.append(DrinkEventRecord(timeLogged: timeLogged, count: count))
        drinkEvents = list
    }

    func removeLastDrinkEvent() {
        var list = drinkEvents
        guard !list.isEmpty else { return }
        list.removeLast()
        drinkEvents = list
    }

    func removeDrinkEvent(id: UUID) {
        drinkEvents = drinkEvents.filter { $0.id != id }
    }

    func addDrinkUrge(note: String = "", timeLogged: Date = Date()) {
        var list = drinkUrges
        list.append(DrinkUrgeRecord(timeLogged: timeLogged, note: note))
        drinkUrges = list
    }

    func removeDrinkUrge(id: UUID) {
        drinkUrges = drinkUrges.filter { $0.id != id }
    }

    var bathroomEvents: [BathroomEventRecord] {
        get {
            guard let data = bathroomEventsJSON?.data(using: .utf8),
                  let decoded = try? JSONDecoder().decode([BathroomEventRecord].self, from: data) else {
                return []
            }
            return decoded.sorted { $0.timeLogged < $1.timeLogged }
        }
        set {
            if let data = try? JSONEncoder().encode(newValue),
               let string = String(data: data, encoding: .utf8) {
                bathroomEventsJSON = string
            } else {
                bathroomEventsJSON = "[]"
            }
        }
    }

    var urineCount: Int {
        bathroomEvents.filter { $0.kind == .urine }.count
    }

    var stoolCount: Int {
        bathroomEvents.filter { $0.kind == .stool }.count
    }

    @discardableResult
    func addBathroomEvent(kind: BathroomKind, note: String = "", timeLogged: Date = Date()) -> BathroomEventRecord {
        let event = BathroomEventRecord(kind: kind, timeLogged: timeLogged, note: note)
        var list = bathroomEvents
        list.append(event)
        bathroomEvents = list
        return event
    }

    func updateBathroomEventNote(id: UUID, note: String) {
        var list = bathroomEvents
        guard let idx = list.firstIndex(where: { $0.id == id }) else { return }
        list[idx].note = note
        bathroomEvents = list
    }

    func removeBathroomEvent(id: UUID) {
        bathroomEvents = bathroomEvents.filter { $0.id != id }
    }

    func updateCigaretteEventTime(id: UUID, timeLogged: Date) {
        var list = cigaretteEvents
        guard let idx = list.firstIndex(where: { $0.id == id }) else { return }
        list[idx].timeLogged = timeLogged
        cigaretteEvents = list
    }

    func updateCigaretteUrgeTime(id: UUID, timeLogged: Date) {
        var list = cigaretteUrges
        guard let idx = list.firstIndex(where: { $0.id == id }) else { return }
        list[idx].timeLogged = timeLogged
        cigaretteUrges = list
    }

    func takeCigaretteEvent(id: UUID) -> CigaretteEventRecord? {
        var list = cigaretteEvents
        guard let idx = list.firstIndex(where: { $0.id == id }) else { return nil }
        let event = list.remove(at: idx)
        cigaretteEvents = list
        return event
    }

    func takeCigaretteUrge(id: UUID) -> CigaretteUrgeRecord? {
        var list = cigaretteUrges
        guard let idx = list.firstIndex(where: { $0.id == id }) else { return nil }
        let urge = list.remove(at: idx)
        cigaretteUrges = list
        return urge
    }

    func insertCigaretteEvent(_ event: CigaretteEventRecord) {
        var list = cigaretteEvents
        list.append(event)
        cigaretteEvents = list
    }

    func insertCigaretteUrge(_ urge: CigaretteUrgeRecord) {
        var list = cigaretteUrges
        list.append(urge)
        cigaretteUrges = list
    }

    func updateDrinkEventTime(id: UUID, timeLogged: Date) {
        var list = drinkEvents
        guard let idx = list.firstIndex(where: { $0.id == id }) else { return }
        list[idx].timeLogged = timeLogged
        drinkEvents = list
    }

    func updateDrinkUrgeTime(id: UUID, timeLogged: Date) {
        var list = drinkUrges
        guard let idx = list.firstIndex(where: { $0.id == id }) else { return }
        list[idx].timeLogged = timeLogged
        drinkUrges = list
    }

    func takeDrinkEvent(id: UUID) -> DrinkEventRecord? {
        var list = drinkEvents
        guard let idx = list.firstIndex(where: { $0.id == id }) else { return nil }
        let event = list.remove(at: idx)
        drinkEvents = list
        return event
    }

    func takeDrinkUrge(id: UUID) -> DrinkUrgeRecord? {
        var list = drinkUrges
        guard let idx = list.firstIndex(where: { $0.id == id }) else { return nil }
        let urge = list.remove(at: idx)
        drinkUrges = list
        return urge
    }

    func insertDrinkEvent(_ event: DrinkEventRecord) {
        var list = drinkEvents
        list.append(event)
        drinkEvents = list
    }

    func insertDrinkUrge(_ urge: DrinkUrgeRecord) {
        var list = drinkUrges
        list.append(urge)
        drinkUrges = list
    }

    func updateBathroomEventTime(id: UUID, timeLogged: Date) {
        var list = bathroomEvents
        guard let idx = list.firstIndex(where: { $0.id == id }) else { return }
        list[idx].timeLogged = timeLogged
        bathroomEvents = list
    }

    func takeBathroomEvent(id: UUID) -> BathroomEventRecord? {
        var list = bathroomEvents
        guard let idx = list.firstIndex(where: { $0.id == id }) else { return nil }
        let event = list.remove(at: idx)
        bathroomEvents = list
        return event
    }

    func insertBathroomEvent(_ event: BathroomEventRecord) {
        var list = bathroomEvents
        list.append(event)
        bathroomEvents = list
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

    func toggleWaterSlot(
        at index: Int,
        fillOz: Double,
        kind: HydrationDrinkKind = .water,
        otherSubtype: HydrationOtherSubtype? = nil,
        isElectrolyte: Bool = false
    ) {
        var slots = waterSlots
        while slots.count <= index { slots.append(nil) }
        if slots[index] != nil {
            slots[index] = nil
        } else {
            slots[index] = WaterSlotRecord(
                oz: fillOz,
                kind: isElectrolyte ? .electrolyte : kind,
                otherSubtype: otherSubtype,
                isElectrolyte: isElectrolyte
            )
        }
        waterSlots = slots
    }

    func setWaterSlot(
        at index: Int,
        oz: Double,
        kind: HydrationDrinkKind = .water,
        otherSubtype: HydrationOtherSubtype? = nil,
        isElectrolyte: Bool = false
    ) {
        var slots = waterSlots
        while slots.count <= index { slots.append(nil) }
        slots[index] = WaterSlotRecord(
            oz: oz,
            kind: isElectrolyte ? .electrolyte : kind,
            otherSubtype: otherSubtype,
            isElectrolyte: isElectrolyte
        )
        waterSlots = slots
    }

    func setWaterSlotKind(
        at index: Int,
        kind: HydrationDrinkKind,
        otherSubtype: HydrationOtherSubtype? = nil
    ) {
        var slots = waterSlots
        guard index < slots.count, var record = slots[index] else { return }
        record.kind = kind
        record.otherSubtype = kind == .other ? (otherSubtype ?? .other) : nil
        slots[index] = record
        waterSlots = slots
    }

    func setWaterSlotElectrolyte(at index: Int, isElectrolyte: Bool) {
        setWaterSlotKind(at: index, kind: isElectrolyte ? .electrolyte : .water)
    }

    func appendFilledWaterSlot(
        oz: Double,
        kind: HydrationDrinkKind = .water,
        otherSubtype: HydrationOtherSubtype? = nil,
        isElectrolyte: Bool = false
    ) {
        var slots = waterSlots
        slots.append(WaterSlotRecord(
            oz: oz,
            kind: isElectrolyte ? .electrolyte : kind,
            otherSubtype: otherSubtype,
            isElectrolyte: isElectrolyte
        ))
        waterSlots = slots
    }

    /// Fills the first empty slot, or appends if all filled.
    func fillNextWaterSlot(
        oz: Double,
        ensuringMinimumSlots minimum: Int = 1,
        kind: HydrationDrinkKind = .water,
        otherSubtype: HydrationOtherSubtype? = nil,
        isElectrolyte: Bool = false
    ) {
        var slots = waterSlots
        while slots.count < minimum { slots.append(nil) }
        let record = WaterSlotRecord(
            oz: oz,
            kind: isElectrolyte ? .electrolyte : kind,
            otherSubtype: otherSubtype,
            isElectrolyte: isElectrolyte
        )
        if let empty = slots.firstIndex(where: { $0 == nil }) {
            slots[empty] = record
        } else {
            slots.append(record)
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
    /// Fluid ounces counted toward hydration when the setting is on (shakes, RTDs, etc.).
    var hydrationOzStored: Double?

    init(
        name: String,
        time: Date = Date(),
        servingSize: String,
        calories: Int,
        hungerBefore: Int = 4,
        hungerAfter: Int = 6,
        proteinCategory: String = "other",
        servings: Double = 1,
        hydrationOz: Double? = nil
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
        self.hydrationOzStored = hydrationOz
    }

    var hydrationOz: Double {
        get { max(0, hydrationOzStored ?? 0) }
        set { hydrationOzStored = newValue > 0 ? newValue : nil }
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

/// Tape-measure session (neck, waist/stomach, arms, legs, etc.) tracked over time.
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

    init(
        date: Date = Date(),
        neckInches: Double? = nil,
        chestInches: Double? = nil,
        waistInches: Double? = nil,
        hipsInches: Double? = nil,
        leftArmInches: Double? = nil,
        rightArmInches: Double? = nil,
        leftThighInches: Double? = nil,
        rightThighInches: Double? = nil,
        notes: String = ""
    ) {
        self.id = UUID()
        self.date = Calendar.current.startOfDay(for: date)
        self.neckInchesStored = Self.normalized(neckInches)
        self.chestInchesStored = Self.normalized(chestInches)
        self.waistInchesStored = Self.normalized(waistInches)
        self.hipsInchesStored = Self.normalized(hipsInches)
        self.leftArmInchesStored = Self.normalized(leftArmInches)
        self.rightArmInchesStored = Self.normalized(rightArmInches)
        self.leftThighInchesStored = Self.normalized(leftThighInches)
        self.rightThighInchesStored = Self.normalized(rightThighInches)
        self.notes = notes
        self.createdAt = Date()
    }

    private static func normalized(_ value: Double?) -> Double? {
        guard let value, value > 0 else { return nil }
        return value
    }

    var neckInches: Double? {
        get { neckInchesStored }
        set { neckInchesStored = Self.normalized(newValue) }
    }
    var chestInches: Double? {
        get { chestInchesStored }
        set { chestInchesStored = Self.normalized(newValue) }
    }
    var waistInches: Double? {
        get { waistInchesStored }
        set { waistInchesStored = Self.normalized(newValue) }
    }
    var hipsInches: Double? {
        get { hipsInchesStored }
        set { hipsInchesStored = Self.normalized(newValue) }
    }
    var leftArmInches: Double? {
        get { leftArmInchesStored }
        set { leftArmInchesStored = Self.normalized(newValue) }
    }
    var rightArmInches: Double? {
        get { rightArmInchesStored }
        set { rightArmInchesStored = Self.normalized(newValue) }
    }
    var leftThighInches: Double? {
        get { leftThighInchesStored }
        set { leftThighInchesStored = Self.normalized(newValue) }
    }
    var rightThighInches: Double? {
        get { rightThighInchesStored }
        set { rightThighInchesStored = Self.normalized(newValue) }
    }

    var filledCount: Int {
        [
            neckInches, chestInches, waistInches, hipsInches,
            leftArmInches, rightArmInches, leftThighInches, rightThighInches
        ].compactMap { $0 }.count
    }

    func summaryLine(usesMetric: Bool) -> String {
        var parts: [String] = []
        let unit = usesMetric ? "cm" : "in"
        func fmt(_ inches: Double?) -> String? {
            guard let inches else { return nil }
            let value = usesMetric ? inches * 2.54 : inches
            return String(format: "%.1f %@", value, unit)
        }
        if let w = fmt(waistInches) { parts.append("Waist \(w)") }
        if let n = fmt(neckInches) { parts.append("Neck \(n)") }
        if let a = fmt(leftArmInches ?? rightArmInches) { parts.append("Arm \(a)") }
        if let t = fmt(leftThighInches ?? rightThighInches) { parts.append("Thigh \(t)") }
        if parts.isEmpty {
            return filledCount == 0 ? "No measurements" : "\(filledCount) measurements"
        }
        if parts.count <= 3 { return parts.joined(separator: " · ") }
        return parts.prefix(3).joined(separator: " · ") + " +\(parts.count - 3)"
    }
}

enum BodyCompositionBodyType: String, CaseIterable, Identifiable, Codable {
    case standard = "Standard"
    case athletic = "Athletic"

    var id: String { rawValue }
}

enum BodyCompositionGender: String, CaseIterable, Identifiable, Codable {
    case male = "Male"
    case female = "Female"

    var id: String { rawValue }
}

enum BodyCompReminderCadence: String, CaseIterable, Identifiable {
    case weekly = "Weekly"
    case monthly = "Monthly"

    var id: String { rawValue }
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

    init(
        date: Date = Date(),
        proteinGoalText: String = "",
        waterTargetText: String = "",
        bodyType: BodyCompositionBodyType = .standard,
        gender: BodyCompositionGender = .male,
        age: Int = 30,
        heightInches: Double = 0,
        weightLbs: Double = 0,
        bmi: Double = 0,
        bmrKcal: Int = 0,
        impedance: Double = 0,
        fatPercent: Double = 0,
        fatMassLbs: Double = 0,
        ffmLbs: Double = 0,
        tbwLbs: Double = 0,
        desirableFatPercentLow: Double = 0,
        desirableFatPercentHigh: Double = 0,
        desirableFatMassLow: Double = 0,
        desirableFatMassHigh: Double = 0,
        notes: String = ""
    ) {
        self.id = UUID()
        self.date = Calendar.current.startOfDay(for: date)
        self.proteinGoalText = proteinGoalText
        self.waterTargetText = waterTargetText
        self.bodyTypeRaw = bodyType.rawValue
        self.genderRaw = gender.rawValue
        self.age = age
        self.heightInches = heightInches
        self.weightLbs = weightLbs
        self.bmi = bmi
        self.bmrKcal = bmrKcal
        self.impedance = impedance
        self.fatPercent = fatPercent
        self.fatMassLbs = fatMassLbs
        self.ffmLbs = ffmLbs
        self.tbwLbs = tbwLbs
        self.desirableFatPercentLow = desirableFatPercentLow
        self.desirableFatPercentHigh = desirableFatPercentHigh
        self.desirableFatMassLow = desirableFatMassLow
        self.desirableFatMassHigh = desirableFatMassHigh
        self.notes = notes
        self.createdAt = Date()
    }

    var bodyType: BodyCompositionBodyType {
        get { BodyCompositionBodyType(rawValue: bodyTypeRaw) ?? .standard }
        set { bodyTypeRaw = newValue.rawValue }
    }

    var gender: BodyCompositionGender {
        get { BodyCompositionGender(rawValue: genderRaw) ?? .male }
        set { genderRaw = newValue.rawValue }
    }

    var summaryLine: String {
        let fat = String(format: "%.1f%% fat", fatPercent)
        let weight = String(format: "%.1f lb", weightLbs)
        return "\(weight) · \(fat) · BMI \(String(format: "%.1f", bmi))"
    }
}

enum HydrationDrinkKind: String, Codable, CaseIterable, Identifiable, Hashable {
    case water
    case electrolyte
    case other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .water: return "Water"
        case .electrolyte: return "Electrolyte"
        case .other: return "Other"
        }
    }
}

enum HydrationOtherSubtype: String, Codable, CaseIterable, Identifiable, Hashable {
    case soda
    case tea
    case coffee
    case juice
    case sparkling
    case milk
    case other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .soda: return "Soda"
        case .tea: return "Tea"
        case .coffee: return "Coffee"
        case .juice: return "Juice"
        case .sparkling: return "Sparkling"
        case .milk: return "Milk"
        case .other: return "Other"
        }
    }
}

struct WaterSlotRecord: Codable, Equatable, Hashable {
    var oz: Double
    var kind: HydrationDrinkKind
    var otherSubtype: HydrationOtherSubtype?

    init(
        oz: Double,
        kind: HydrationDrinkKind = .water,
        otherSubtype: HydrationOtherSubtype? = nil,
        isElectrolyte: Bool = false
    ) {
        self.oz = oz
        if isElectrolyte {
            self.kind = .electrolyte
            self.otherSubtype = nil
        } else {
            self.kind = kind
            self.otherSubtype = kind == .other ? (otherSubtype ?? .other) : nil
        }
    }

    var isElectrolyte: Bool {
        get { kind == .electrolyte }
        set {
            if newValue {
                kind = .electrolyte
                otherSubtype = nil
            } else if kind == .electrolyte {
                kind = .water
                otherSubtype = nil
            }
        }
    }

    var displayLabel: String {
        switch kind {
        case .water: return HydrationDrinkKind.water.title
        case .electrolyte: return HydrationDrinkKind.electrolyte.title
        case .other: return (otherSubtype ?? .other).title
        }
    }

    var systemImage: String {
        switch kind {
        case .water:
            return "waterbottle.fill"
        case .electrolyte:
            return "waterbottle.fill"
        case .other:
            switch otherSubtype ?? .other {
            case .soda:
                // soda.can.fill arrived in SF Symbols 6 / iOS 18 — blank on earlier OS.
                if #available(iOS 18.0, *) { return "soda.can.fill" }
                return "takeoutbag.and.cup.and.straw.fill"
            case .tea:
                return "cup.and.saucer.fill"
            case .coffee:
                if #available(iOS 17.0, *) { return "mug.fill" }
                return "cup.and.saucer.fill"
            case .juice:
                return "wineglass.fill"
            case .sparkling:
                return "waterbottle.fill"
            case .milk:
                return "cup.and.saucer.fill"
            case .other:
                return "drop.fill"
            }
        }
    }

    var showsElectrolyteBadge: Bool { kind == .electrolyte }
}

private struct WaterSlotStored: Codable {
    var oz: Double
    var e: Bool?
    var k: String?
    var s: String?

    init(oz: Double, e: Bool? = nil, k: String? = nil, s: String? = nil) {
        self.oz = oz
        self.e = e
        self.k = k
        self.s = s
    }

    init(from record: WaterSlotRecord?) {
        if let record {
            self.oz = record.oz
            self.e = record.kind == .electrolyte ? true : nil
            self.k = record.kind.rawValue
            self.s = record.kind == .other ? (record.otherSubtype ?? .other).rawValue : nil
        } else {
            self.oz = -1
            self.e = nil
            self.k = nil
            self.s = nil
        }
    }

    var asRecord: WaterSlotRecord? {
        guard oz >= 0 else { return nil }
        if let k, let kind = HydrationDrinkKind(rawValue: k) {
            let subtype = s.flatMap(HydrationOtherSubtype.init(rawValue:))
            return WaterSlotRecord(oz: oz, kind: kind, otherSubtype: subtype)
        }
        return WaterSlotRecord(oz: oz, isElectrolyte: e == true)
    }
}

struct CigaretteUrgeRecord: Codable, Identifiable, Hashable {
    var id: UUID
    var timeLogged: Date
    var note: String

    init(id: UUID = UUID(), timeLogged: Date = Date(), note: String = "") {
        self.id = id
        self.timeLogged = timeLogged
        self.note = note
    }
}

struct CigaretteEventRecord: Codable, Identifiable, Hashable {
    var id: UUID
    var timeLogged: Date
    /// Cigarettes in this log action (1 for a single cig; 10 for ½ pack, etc.).
    var count: Int

    init(id: UUID = UUID(), timeLogged: Date = Date(), count: Int = 1) {
        self.id = id
        self.timeLogged = timeLogged
        self.count = max(1, count)
    }

    var label: String {
        if count == 1 { return "1 cig" }
        if count == CigarettePackMath.perPack { return "1 pack" }
        if count * 2 == CigarettePackMath.perPack { return "½ pack" }
        if count % CigarettePackMath.perPack == 0 {
            let packs = count / CigarettePackMath.perPack
            return packs == 1 ? "1 pack" : "\(packs) packs"
        }
        if CigarettePackMath.perPack % 2 == 0, count % (CigarettePackMath.perPack / 2) == 0 {
            return CigarettePackMath.packsLabel(cigarettes: count)
        }
        return "\(count) cigs"
    }
}

struct DrinkEventRecord: Codable, Identifiable, Hashable {
    var id: UUID
    var timeLogged: Date
    var count: Int

    init(id: UUID = UUID(), timeLogged: Date = Date(), count: Int = 1) {
        self.id = id
        self.timeLogged = timeLogged
        self.count = max(1, count)
    }

    var label: String {
        count == 1 ? "1 drink" : "\(count) drinks"
    }
}

struct DrinkUrgeRecord: Codable, Identifiable, Hashable {
    var id: UUID
    var timeLogged: Date
    var note: String

    init(id: UUID = UUID(), timeLogged: Date = Date(), note: String = "") {
        self.id = id
        self.timeLogged = timeLogged
        self.note = note
    }
}

enum BathroomKind: String, Codable, CaseIterable, Identifiable {
    case urine
    case stool

    var id: String { rawValue }

    var title: String {
        switch self {
        case .urine: return "Urination"
        case .stool: return "Bowel movement"
        }
    }

    var shortTitle: String {
        switch self {
        case .urine: return "Urination"
        case .stool: return "Bowel"
        }
    }
}

struct BathroomEventRecord: Codable, Identifiable, Hashable {
    var id: UUID
    var kind: BathroomKind
    var timeLogged: Date
    var note: String

    init(id: UUID = UUID(), kind: BathroomKind, timeLogged: Date = Date(), note: String = "") {
        self.id = id
        self.kind = kind
        self.timeLogged = timeLogged
        self.note = note
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
    var showBathroomSectionStored: Bool?
    var accentThemeRaw: String?
    var customAccentHexStored: String?
    var appearanceModeRaw: String?
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

    // Goal weight + smoking (optional for migration)
    var goalWeightLbsStored: Double?
    var smokingModeRaw: String?
    var dailyCigaretteLimitStored: Int?
    var quitDateStored: Date?
    var cigarettesPerPackStored: Int? // unused; packs are always 20
    var cigarettePackPriceStored: Double?

    var drinkingModeRaw: String?
    var dailyDrinkLimitStored: Int?
    var alcoholQuitDateStored: Date?

    // Notifications v4 + quotes + section order
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

    // Protein drinks → hydration
    var proteinDrinksCountTowardHydrationStored: Bool?
    var defaultShakeHydrationOzStored: Double?

    // Food lookup (USDA FoodData Central)
    var usdaAPIKeyStored: String?

    // Body composition reminders
    var bodyCompReminderEnabledStored: Bool?
    var bodyCompReminderCadenceRaw: String?
    var bodyCompReminderWeekdayStored: Int?
    var bodyCompReminderDayOfMonthStored: Int?
    var bodyCompReminderHourStored: Int?
    var bodyCompReminderMinuteStored: Int?

    /// Profile age for body composition receipts (years).
    var ageYearsStored: Int?

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
        self.appearanceModeRaw = AppearanceMode.system.rawValue
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

    var ageYears: Int {
        get { ageYearsStored ?? 0 }
        set { ageYearsStored = newValue > 0 ? newValue : nil }
    }

    var hasAge: Bool { ageYears > 0 }

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

    var showBathroomSection: Bool {
        get { showBathroomSectionStored ?? true }
        set { showBathroomSectionStored = newValue }
    }

    /// When on, protein shakes / RTDs with hydration oz add to the day’s water total.
    var proteinDrinksCountTowardHydration: Bool {
        get { proteinDrinksCountTowardHydrationStored ?? true }
        set { proteinDrinksCountTowardHydrationStored = newValue }
    }

    var defaultShakeHydrationOz: Double {
        get { defaultShakeHydrationOzStored ?? 8 }
        set { defaultShakeHydrationOzStored = max(1, min(newValue, 64)) }
    }

    var usdaAPIKey: String {
        get { usdaAPIKeyStored ?? "" }
        set { usdaAPIKeyStored = newValue.trimmingCharacters(in: .whitespacesAndNewlines) }
    }

    var bodyCompReminderEnabled: Bool {
        get { bodyCompReminderEnabledStored ?? false }
        set { bodyCompReminderEnabledStored = newValue }
    }

    var bodyCompReminderCadence: BodyCompReminderCadence {
        get { BodyCompReminderCadence(rawValue: bodyCompReminderCadenceRaw ?? "") ?? .monthly }
        set { bodyCompReminderCadenceRaw = newValue.rawValue }
    }

    /// Calendar weekday: 1 = Sunday … 7 = Saturday (matches `Calendar.Component.weekday`).
    var bodyCompReminderWeekday: Int {
        get { bodyCompReminderWeekdayStored ?? 2 }
        set { bodyCompReminderWeekdayStored = min(max(newValue, 1), 7) }
    }

    var bodyCompReminderDayOfMonth: Int {
        get { bodyCompReminderDayOfMonthStored ?? 1 }
        set { bodyCompReminderDayOfMonthStored = min(max(newValue, 1), 31) }
    }

    var bodyCompReminderHour: Int {
        get { bodyCompReminderHourStored ?? 9 }
        set { bodyCompReminderHourStored = newValue }
    }

    var bodyCompReminderMinute: Int {
        get { bodyCompReminderMinuteStored ?? 0 }
        set { bodyCompReminderMinuteStored = newValue }
    }

    /// Suggested fluid oz when logging a protein shake / RTD (nil if setting off or not a shake).
    func suggestedHydrationOz(forProteinCategory raw: String, servings: Double) -> Double? {
        guard proteinDrinksCountTowardHydration else { return nil }
        guard ProteinCategory(rawValue: raw) == .shake else { return nil }
        return defaultShakeHydrationOz * max(servings, 0.5)
    }

    var accentTheme: AccentTheme {
        get {
            if let theme = AccentTheme(rawValue: accentThemeRaw ?? "") {
                return theme
            }
            // Legacy accents from before expanded presets.
            switch accentThemeRaw {
            case "blue", "pink", "red", "brown":
                return .onPlan
            default:
                return .onPlan
            }
        }
        set { accentThemeRaw = newValue.rawValue }
    }

    /// `#RRGGBB` used when `accentTheme == .custom`.
    var customAccentHex: String? {
        get { customAccentHexStored }
        set { customAccentHexStored = newValue }
    }

    var appearanceMode: AppearanceMode {
        get { AppearanceMode(rawValue: appearanceModeRaw ?? "") ?? .system }
        set { appearanceModeRaw = newValue.rawValue }
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
        // Bathroom defaults collapsed for privacy until the user expands it once.
        if section == .bathroom {
            return true
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

    var goalWeightLbs: Double? {
        get {
            guard let value = goalWeightLbsStored, value > 0 else { return nil }
            return value
        }
        set {
            if let newValue, newValue > 0 {
                goalWeightLbsStored = newValue
            } else {
                goalWeightLbsStored = nil
            }
        }
    }

    var hasGoalWeight: Bool { goalWeightLbs != nil }

    var smokingMode: SmokingMode {
        get { SmokingMode(rawValue: smokingModeRaw ?? "") ?? .off }
        set { smokingModeRaw = newValue.rawValue }
    }

    var dailyCigaretteLimit: Int {
        get { max(0, dailyCigaretteLimitStored ?? AppLimits.defaultDailyCigaretteLimit) }
        set { dailyCigaretteLimitStored = max(0, newValue) }
    }

    /// Reduce max in pack increments (½ pack steps); stored as cigarettes.
    var dailyCigaretteLimitPacks: Double {
        get { CigarettePackMath.packs(forCigarettes: dailyCigaretteLimit) }
        set { dailyCigaretteLimit = CigarettePackMath.cigarettes(forPacks: max(0, newValue)) }
    }

    /// Effective daily max for UI: reduce uses limit; quit targets 0; count/off have none.
    var effectiveDailyCigaretteLimit: Int? {
        switch smokingMode {
        case .off, .count: return nil
        case .reduce: return dailyCigaretteLimit
        case .quit: return 0
        }
    }

    var quitDate: Date? {
        get { quitDateStored.map { DateHelpers.startOfDay($0) } }
        set { quitDateStored = newValue.map { DateHelpers.startOfDay($0) } }
    }

    /// Always 20 — packs are a fixed size.
    var cigarettesPerPack: Int { CigarettePackMath.perPack }

    var cigarettePackPrice: Double? {
        get {
            guard let value = cigarettePackPriceStored, value > 0 else { return nil }
            return value
        }
        set {
            if let newValue, newValue > 0 {
                cigarettePackPriceStored = newValue
            } else {
                cigarettePackPriceStored = nil
            }
        }
    }

    /// Money saved estimate for quit mode when pack price is set.
    func estimatedMoneySaved(cigarettesAvoided: Int) -> Double? {
        guard let price = cigarettePackPrice, cigarettesAvoided > 0 else { return nil }
        return Double(cigarettesAvoided) / Double(CigarettePackMath.perPack) * price
    }

    var drinkingMode: DrinkingMode {
        get { DrinkingMode(rawValue: drinkingModeRaw ?? "") ?? .off }
        set { drinkingModeRaw = newValue.rawValue }
    }

    var dailyDrinkLimit: Int {
        get { max(0, dailyDrinkLimitStored ?? AppLimits.defaultDailyDrinkLimit) }
        set { dailyDrinkLimitStored = max(0, newValue) }
    }

    var effectiveDailyDrinkLimit: Int? {
        switch drinkingMode {
        case .off, .count: return nil
        case .reduce: return dailyDrinkLimit
        case .quit: return 0
        }
    }

    var alcoholQuitDate: Date? {
        get { alcoholQuitDateStored.map { DateHelpers.startOfDay($0) } }
        set { alcoholQuitDateStored = newValue.map { DateHelpers.startOfDay($0) } }
    }

    var smokingCheckInEnabled: Bool {
        get { smokingCheckInEnabledStored ?? false }
        set { smokingCheckInEnabledStored = newValue }
    }

    var smokingCheckInHour: Int {
        get { smokingCheckInHourStored ?? 16 }
        set { smokingCheckInHourStored = newValue }
    }

    var smokingCheckInMinute: Int {
        get { smokingCheckInMinuteStored ?? 0 }
        set { smokingCheckInMinuteStored = newValue }
    }

    var drinkingCheckInEnabled: Bool {
        get { drinkingCheckInEnabledStored ?? false }
        set { drinkingCheckInEnabledStored = newValue }
    }

    var drinkingCheckInHour: Int {
        get { drinkingCheckInHourStored ?? 17 }
        set { drinkingCheckInHourStored = newValue }
    }

    var drinkingCheckInMinute: Int {
        get { drinkingCheckInMinuteStored ?? 0 }
        set { drinkingCheckInMinuteStored = newValue }
    }

    var motivationReminderEnabled: Bool {
        get { motivationReminderEnabledStored ?? false }
        set { motivationReminderEnabledStored = newValue }
    }

    var motivationReminderHour: Int {
        get { motivationReminderHourStored ?? 8 }
        set { motivationReminderHourStored = newValue }
    }

    var motivationReminderMinute: Int {
        get { motivationReminderMinuteStored ?? 0 }
        set { motivationReminderMinuteStored = newValue }
    }

    var customMotivationQuotes: [String] {
        get { Self.decodeStringList(customMotivationQuotesJSON) }
        set { customMotivationQuotesJSON = Self.encodeStringList(newValue) }
    }

    /// Reorderable day sections (header is always first and not stored here).
    var sectionOrder: [DaySectionID] {
        get {
            let defaults = DaySectionID.defaultReorderableOrder
            guard let data = sectionOrderJSON?.data(using: .utf8),
                  let raw = try? JSONDecoder().decode([String].self, from: data) else {
                return defaults
            }
            var parsed = raw.compactMap(DaySectionID.init(rawValue:)).filter { $0 != .dailyStatus }
            // Append any new sections missing from saved order.
            for id in defaults where !parsed.contains(id) {
                parsed.append(id)
            }
            // Drop unknown / duplicates
            var seen = Set<DaySectionID>()
            parsed = parsed.filter { seen.insert($0).inserted }
            return parsed.isEmpty ? defaults : parsed
        }
        set {
            let cleaned = newValue.filter { $0 != .dailyStatus }
            if let data = try? JSONEncoder().encode(cleaned.map(\.rawValue)),
               let string = String(data: data, encoding: .utf8) {
                sectionOrderJSON = string
            }
        }
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
        if (notificationsDefaultsVersionStored ?? 0) < 4 {
            smokingCheckInEnabled = false
            drinkingCheckInEnabled = false
            motivationReminderEnabled = false
            notificationsDefaultsVersionStored = 4
        }
        if (notificationsDefaultsVersionStored ?? 0) < 5 {
            bodyCompReminderEnabled = false
            bodyCompReminderCadence = .monthly
            bodyCompReminderDayOfMonth = 1
            bodyCompReminderWeekday = 2
            bodyCompReminderHour = 9
            bodyCompReminderMinute = 0
            notificationsDefaultsVersionStored = 5
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
