import Foundation

enum AppLimits {
    static let proteinGoalMin = 100
    static let proteinGoalMax = 3000
    static let proteinGoalStep = 1
    /// Protein floor in grams — a target to reach, unlike the kcal ceiling above.
    static let proteinGramsGoalMin = 20
    static let proteinGramsGoalMax = 400
    static let proteinGramsGoalStep = 5
    static let customFeelingMaxChars = 18
    static let miscDailyLimit = 4
    static let defaultBottleOz = 16.9
    static let hydrationTargetOz = 64
    static let defaultDailyCigaretteLimit = 20 // 1 pack
    static let defaultCigarettesPerPack = 20
    static let cigaretteLimitMax = 60
    static let defaultDailyDrinkLimit = 2
    static let drinkLimitMax = 20
}
