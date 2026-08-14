import Foundation

/// Sanitized today snapshot for menu bar, widgets, and Watch. Never includes USDA keys or notes.
public struct ChromeSnapshot: Codable, Sendable, Equatable {
    public var generatedAt: Date
    public var followedPlan: Bool
    public var ketosis: Bool
    public var proteinCalories: Int
    public var proteinGoal: Int
    public var waterOz: Int
    public var waterTargetOz: Int
    public var bottleOz: Double
    public var cigarettes: Int
    public var drinks: Int
    public var urineCount: Int
    public var stoolCount: Int
    public var smokingEnabled: Bool
    public var drinkingEnabled: Bool
    public var bathroomEnabled: Bool

    public static let empty = ChromeSnapshot(
        generatedAt: .distantPast,
        followedPlan: true,
        ketosis: true,
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
        bathroomEnabled: true
    )

    /// Fills Settings previews when today’s journal hasn’t landed yet.
    public static let previewSample = ChromeSnapshot(
        generatedAt: Date(),
        followedPlan: true,
        ketosis: true,
        proteinCalories: 240,
        proteinGoal: 500,
        waterOz: 32,
        waterTargetOz: 64,
        bottleOz: 16.9,
        cigarettes: 2,
        drinks: 1,
        urineCount: 3,
        stoolCount: 1,
        smokingEnabled: true,
        drinkingEnabled: true,
        bathroomEnabled: true
    )

    public init(
        generatedAt: Date,
        followedPlan: Bool,
        ketosis: Bool,
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
        bathroomEnabled: Bool
    ) {
        self.generatedAt = generatedAt
        self.followedPlan = followedPlan
        self.ketosis = ketosis
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
    }

    public var proteinFraction: Double {
        guard proteinGoal > 0 else { return 0 }
        return min(1, Double(proteinCalories) / Double(proteinGoal))
    }

    public var waterFraction: Double {
        guard waterTargetOz > 0 else { return 0 }
        return min(1, Double(waterOz) / Double(waterTargetOz))
    }

    public var proteinPercent: Double { proteinFraction * 100 }
    public var waterPercent: Double { waterFraction * 100 }

    public var isStale: Bool {
        Date().timeIntervalSince(generatedAt) > 60 * 60 * 6
    }

    public var forSettingsPreview: ChromeSnapshot {
        generatedAt == .distantPast ? .previewSample : self
    }
}
