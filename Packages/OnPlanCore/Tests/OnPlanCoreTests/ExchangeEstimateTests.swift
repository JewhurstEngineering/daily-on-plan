import XCTest
@testable import OnPlanCore

final class ExchangeEstimateTests: XCTestCase {

    func testOneLeanExchangeIsSevenGramsProteinAndThreeFat() {
        let macros = ExchangeEstimate.macros(calories: 55, category: .lean)
        XCTAssertEqual(macros.protein, 7)
        XCTAssertEqual(macros.fat, 3)
    }

    func testOneVeryLeanExchange() {
        let macros = ExchangeEstimate.macros(calories: 35, category: .veryLean)
        XCTAssertEqual(macros.protein, 7)
        XCTAssertEqual(macros.fat ?? 0, 0.5, accuracy: 0.01)
    }

    func testOneMediumFatExchange() {
        let macros = ExchangeEstimate.macros(calories: 75, category: .mediumFat)
        XCTAssertEqual(macros.protein, 7)
        XCTAssertEqual(macros.fat, 5)
    }

    func testMultipleExchangesScaleLinearly() {
        // 110 kcal of lean protein is two exchanges.
        let macros = ExchangeEstimate.macros(calories: 110, category: .lean)
        XCTAssertEqual(macros.protein, 14)
        XCTAssertEqual(macros.fat, 6)
    }

    func testEstimateIsMarkedAsSuch() {
        XCTAssertEqual(ExchangeEstimate.macros(calories: 55, category: .lean).source, .estimated)
    }

    func testEstimateReproducesItsOwnCalories() {
        // The chart is self-consistent, so the estimate should round-trip through the factors.
        for category in ExchangeEstimate.Category.allCases {
            let calories = Int(category.kcalPerExchange * 3)
            let macros = ExchangeEstimate.macros(calories: calories, category: category)
            XCTAssertFalse(
                NutritionMath.kcalLooksInconsistent(macros),
                "\(category.rawValue) estimate should agree with its own kcal"
            )
        }
    }

    func testOnlyChartCategoriesMap() {
        XCTAssertEqual(ExchangeEstimate.category(forRawValue: "lean"), .lean)
        XCTAssertEqual(ExchangeEstimate.category(forRawValue: "veryLean"), .veryLean)
        XCTAssertEqual(ExchangeEstimate.category(forRawValue: "mediumFat"), .mediumFat)
        // Shakes, snacks and substitutions have no fixed composition to infer from.
        XCTAssertNil(ExchangeEstimate.category(forRawValue: "shake"))
        XCTAssertNil(ExchangeEstimate.category(forRawValue: "snack"))
        XCTAssertNil(ExchangeEstimate.category(forRawValue: "other"))
    }
}
