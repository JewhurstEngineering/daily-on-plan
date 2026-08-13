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
        followedPlan: true,
        ketosis: true,
        updatedAt: .distantPast,
        quickAddSlots: ["water", "electrolyte", "smoking"],
        hydrationSizesOz: [8, 12, 16.9, 24]
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
        hydrationSizesOz: [Double] = [8, 12, 16.9, 24]
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
    }

    private enum CodingKeys: String, CodingKey {
        case proteinCalories, proteinGoal, waterOz, waterTargetOz, bottleOz
        case cigarettes, drinks, urineCount, stoolCount
        case smokingEnabled, drinkingEnabled, bathroomEnabled
        case followedPlan, ketosis, updatedAt
        case quickAddSlots, hydrationSizesOz
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
