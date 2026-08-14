import Foundation

/// Compact payload synced phone ↔ Watch via WatchConnectivity.
struct WatchDaySnapshot: Codable, Hashable, Sendable {
    var proteinCalories: Int
    var proteinGoal: Int
    var waterOz: Int
    var waterTargetOz: Int
    var bottleOz: Double
    var cigarettes: Int
    var drinks: Int
    var urineCount: Int
    var stoolCount: Int
    var smokingEnabled: Bool
    var drinkingEnabled: Bool
    var bathroomEnabled: Bool
    var followedPlan: Bool
    var ketosis: Bool
    var updatedAt: Date
    /// Raw `WatchQuickAdd.Action` values from iPhone settings. Empty means use defaults.
    var quickAddSlots: [String]
    var hydrationSizesOz: [Double]
    var fastingEnabled: Bool
    var eatingWindowStart: Date?
    var eatingWindowEnd: Date?
    var fastingTargetHours: Double
    var fastingStatusLine: String

    static let empty = WatchDaySnapshot(
        proteinCalories: 0,
        proteinGoal: 500,
        waterOz: 0,
        waterTargetOz: 64,
        bottleOz: 16.9,
        cigarettes: 0,
        drinks: 0,
        urineCount: 0,
        stoolCount: 0,
        smokingEnabled: false,
        drinkingEnabled: false,
        bathroomEnabled: true,
        followedPlan: false,
        ketosis: false,
        updatedAt: .distantPast,
        quickAddSlots: ["water", "electrolyte", "smoking"],
        hydrationSizesOz: [8, 12, 16.9, 24],
        fastingEnabled: false,
        eatingWindowStart: nil,
        eatingWindowEnd: nil,
        fastingTargetHours: 16,
        fastingStatusLine: ""
    )

    init(
        proteinCalories: Int,
        proteinGoal: Int,
        waterOz: Int,
        waterTargetOz: Int,
        bottleOz: Double,
        cigarettes: Int,
        drinks: Int,
        urineCount: Int,
        stoolCount: Int,
        smokingEnabled: Bool,
        drinkingEnabled: Bool,
        bathroomEnabled: Bool,
        followedPlan: Bool,
        ketosis: Bool,
        updatedAt: Date,
        quickAddSlots: [String] = ["water", "electrolyte", "smoking"],
        hydrationSizesOz: [Double] = [8, 12, 16.9, 24],
        fastingEnabled: Bool = false,
        eatingWindowStart: Date? = nil,
        eatingWindowEnd: Date? = nil,
        fastingTargetHours: Double = 16,
        fastingStatusLine: String = ""
    ) {
        self.proteinCalories = proteinCalories
        self.proteinGoal = proteinGoal
        self.waterOz = waterOz
        self.waterTargetOz = waterTargetOz
        self.bottleOz = bottleOz
        self.cigarettes = cigarettes
        self.drinks = drinks
        self.urineCount = urineCount
        self.stoolCount = stoolCount
        self.smokingEnabled = smokingEnabled
        self.drinkingEnabled = drinkingEnabled
        self.bathroomEnabled = bathroomEnabled
        self.followedPlan = followedPlan
        self.ketosis = ketosis
        self.updatedAt = updatedAt
        self.quickAddSlots = quickAddSlots
        self.hydrationSizesOz = hydrationSizesOz
        self.fastingEnabled = fastingEnabled
        self.eatingWindowStart = eatingWindowStart
        self.eatingWindowEnd = eatingWindowEnd
        self.fastingTargetHours = fastingTargetHours
        self.fastingStatusLine = fastingStatusLine
    }

    private enum CodingKeys: String, CodingKey {
        case proteinCalories, proteinGoal, waterOz, waterTargetOz, bottleOz
        case cigarettes, drinks, urineCount, stoolCount
        case smokingEnabled, drinkingEnabled, bathroomEnabled
        case followedPlan, ketosis, updatedAt
        case quickAddSlots, hydrationSizesOz
        case fastingEnabled, eatingWindowStart, eatingWindowEnd, fastingTargetHours, fastingStatusLine
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        proteinCalories = try c.decode(Int.self, forKey: .proteinCalories)
        proteinGoal = try c.decode(Int.self, forKey: .proteinGoal)
        waterOz = try c.decode(Int.self, forKey: .waterOz)
        waterTargetOz = try c.decode(Int.self, forKey: .waterTargetOz)
        bottleOz = try c.decode(Double.self, forKey: .bottleOz)
        cigarettes = try c.decode(Int.self, forKey: .cigarettes)
        drinks = try c.decode(Int.self, forKey: .drinks)
        urineCount = try c.decodeIfPresent(Int.self, forKey: .urineCount) ?? 0
        stoolCount = try c.decodeIfPresent(Int.self, forKey: .stoolCount) ?? 0
        smokingEnabled = try c.decode(Bool.self, forKey: .smokingEnabled)
        drinkingEnabled = try c.decode(Bool.self, forKey: .drinkingEnabled)
        bathroomEnabled = try c.decodeIfPresent(Bool.self, forKey: .bathroomEnabled) ?? true
        followedPlan = try c.decode(Bool.self, forKey: .followedPlan)
        ketosis = try c.decode(Bool.self, forKey: .ketosis)
        updatedAt = try c.decode(Date.self, forKey: .updatedAt)
        quickAddSlots = try c.decodeIfPresent([String].self, forKey: .quickAddSlots)
            ?? ["water", "electrolyte", "smoking"]
        hydrationSizesOz = try c.decodeIfPresent([Double].self, forKey: .hydrationSizesOz)
            ?? [8, 12, 16.9, 24]
        fastingEnabled = try c.decodeIfPresent(Bool.self, forKey: .fastingEnabled) ?? false
        eatingWindowStart = try c.decodeIfPresent(Date.self, forKey: .eatingWindowStart)
        eatingWindowEnd = try c.decodeIfPresent(Date.self, forKey: .eatingWindowEnd)
        fastingTargetHours = try c.decodeIfPresent(Double.self, forKey: .fastingTargetHours) ?? 16
        fastingStatusLine = try c.decodeIfPresent(String.self, forKey: .fastingStatusLine) ?? ""
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(proteinCalories, forKey: .proteinCalories)
        try c.encode(proteinGoal, forKey: .proteinGoal)
        try c.encode(waterOz, forKey: .waterOz)
        try c.encode(waterTargetOz, forKey: .waterTargetOz)
        try c.encode(bottleOz, forKey: .bottleOz)
        try c.encode(cigarettes, forKey: .cigarettes)
        try c.encode(drinks, forKey: .drinks)
        try c.encode(urineCount, forKey: .urineCount)
        try c.encode(stoolCount, forKey: .stoolCount)
        try c.encode(smokingEnabled, forKey: .smokingEnabled)
        try c.encode(drinkingEnabled, forKey: .drinkingEnabled)
        try c.encode(bathroomEnabled, forKey: .bathroomEnabled)
        try c.encode(followedPlan, forKey: .followedPlan)
        try c.encode(ketosis, forKey: .ketosis)
        try c.encode(updatedAt, forKey: .updatedAt)
        try c.encode(quickAddSlots, forKey: .quickAddSlots)
        try c.encode(hydrationSizesOz, forKey: .hydrationSizesOz)
        try c.encode(fastingEnabled, forKey: .fastingEnabled)
        try c.encodeIfPresent(eatingWindowStart, forKey: .eatingWindowStart)
        try c.encodeIfPresent(eatingWindowEnd, forKey: .eatingWindowEnd)
        try c.encode(fastingTargetHours, forKey: .fastingTargetHours)
        try c.encode(fastingStatusLine, forKey: .fastingStatusLine)
    }

    var proteinFraction: Double {
        guard proteinGoal > 0 else { return 0 }
        return min(1, Double(proteinCalories) / Double(proteinGoal))
    }

    var waterFraction: Double {
        guard waterTargetOz > 0 else { return 0 }
        return min(1, Double(waterOz) / Double(waterTargetOz))
    }

    var proteinLeft: Int { max(0, proteinGoal - proteinCalories) }
    var waterLeft: Int { max(0, waterTargetOz - waterOz) }

    var bottleLabel: String {
        if bottleOz == bottleOz.rounded() { return "\(Int(bottleOz))" }
        return String(format: "%.1f", bottleOz)
    }

    var isStale: Bool {
        Date().timeIntervalSince(updatedAt) > 60 * 60 * 6
    }

    var resolvedQuickAddSlots: [String] {
        let slots = quickAddSlots.filter { !$0.isEmpty }
        if slots.isEmpty { return ["water", "electrolyte", "smoking"] }
        return Array(slots.prefix(3))
    }

    var resolvedHydrationSizes: [Double] {
        let sizes = hydrationSizesOz.filter { $0 > 0 }
        return sizes.isEmpty ? [8, 12, 16.9, 24] : sizes
    }
}

enum WatchConnectivityKeys {
    static let snapshotData = "snapshotData"
    static let action = "action"
    static let bathroomKind = "bathroomKind"
    static let ounces = "ounces"
    static let electrolyte = "electrolyte"
    static let ok = "ok"
    static let error = "error"
    static let snapshotCacheKey = "watch.daySnapshot.v1"

    enum Action: String {
        case addWater
        case addHydration
        case addCigarette
        case addDrink
        case addBathroomUrine
        case addBathroomStool
        case startEating
        case endEating
        case requestSnapshot
    }
}

enum WatchSnapshotCache {
    static func save(_ snapshot: WatchDaySnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        UserDefaults.standard.set(data, forKey: WatchConnectivityKeys.snapshotCacheKey)
        UserDefaults(suiteName: "group.com.dailyonplan.tracker.watch")?
            .set(data, forKey: WatchConnectivityKeys.snapshotCacheKey)
    }

    static func load() -> WatchDaySnapshot {
        let suite = UserDefaults(suiteName: "group.com.dailyonplan.tracker.watch")
        let data = suite?.data(forKey: WatchConnectivityKeys.snapshotCacheKey)
            ?? UserDefaults.standard.data(forKey: WatchConnectivityKeys.snapshotCacheKey)
        guard let data,
              let snapshot = try? JSONDecoder().decode(WatchDaySnapshot.self, from: data) else {
            return .empty
        }
        return snapshot
    }

    static func dictionary(from snapshot: WatchDaySnapshot) -> [String: Any] {
        guard let data = try? JSONEncoder().encode(snapshot) else { return [:] }
        return [WatchConnectivityKeys.snapshotData: data]
    }

    static func snapshot(from dictionary: [String: Any]) -> WatchDaySnapshot? {
        guard let data = dictionary[WatchConnectivityKeys.snapshotData] as? Data,
              let snapshot = try? JSONDecoder().decode(WatchDaySnapshot.self, from: data) else {
            return nil
        }
        return snapshot
    }
}

struct WatchQueuedAction: Codable, Equatable {
    var action: String
    var ounces: Double?
    var electrolyte: Bool?
    var queuedAt: Date
}

enum WatchActionQueue {
    private static let key = "watch.pendingActions.v1"

    static func enqueue(action: WatchConnectivityKeys.Action, extras: [String: Any] = [:]) {
        guard action != .requestSnapshot else { return }
        var items = load()
        items.append(
            WatchQueuedAction(
                action: action.rawValue,
                ounces: extras[WatchConnectivityKeys.ounces] as? Double,
                electrolyte: extras[WatchConnectivityKeys.electrolyte] as? Bool,
                queuedAt: Date()
            )
        )
        save(items)
    }

    static func drain() -> [WatchQueuedAction] {
        let items = load()
        save([])
        return items
    }

    static var pendingCount: Int { load().count }

    private static func load() -> [WatchQueuedAction] {
        let suite = UserDefaults(suiteName: "group.com.dailyonplan.tracker.watch")
        let data = suite?.data(forKey: key) ?? UserDefaults.standard.data(forKey: key)
        guard let data,
              let items = try? JSONDecoder().decode([WatchQueuedAction].self, from: data) else {
            return []
        }
        return items
    }

    private static func save(_ items: [WatchQueuedAction]) {
        guard let data = try? JSONEncoder().encode(items) else { return }
        UserDefaults.standard.set(data, forKey: key)
        UserDefaults(suiteName: "group.com.dailyonplan.tracker.watch")?.set(data, forKey: key)
    }
}
