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
        updatedAt: .distantPast
    )

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
}

enum WatchConnectivityKeys {
    static let snapshotData = "snapshotData"
    static let action = "action"
    static let bathroomKind = "bathroomKind"
    static let ok = "ok"
    static let error = "error"
    static let snapshotCacheKey = "watch.daySnapshot.v1"

    enum Action: String {
        case addWater
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
    }

    static func load() -> WatchDaySnapshot {
        guard let data = UserDefaults.standard.data(forKey: WatchConnectivityKeys.snapshotCacheKey),
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
