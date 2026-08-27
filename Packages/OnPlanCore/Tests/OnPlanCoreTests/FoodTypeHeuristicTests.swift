import XCTest
@testable import OnPlanCore

final class FoodTypeHeuristicTests: XCTestCase {

    func testCommonProteins() {
        XCTAssertEqual(FoodTypeHeuristic.classify("Grilled chicken breast"), .poultry)
        XCTAssertEqual(FoodTypeHeuristic.classify("Ribeye steak"), .redMeat)
        XCTAssertEqual(FoodTypeHeuristic.classify("Baked salmon"), .seafood)
        XCTAssertEqual(FoodTypeHeuristic.classify("Scrambled eggs"), .egg)
        XCTAssertEqual(FoodTypeHeuristic.classify("Greek yogurt"), .dairy)
        XCTAssertEqual(FoodTypeHeuristic.classify("Tofu stir fry"), .plant)
    }

    func testTurkeyBaconIsPoultryNotRedMeat() {
        // The qualifier is what makes it poultry — "bacon" alone would say red meat.
        XCTAssertEqual(FoodTypeHeuristic.classify("Turkey bacon"), .poultry)
        XCTAssertEqual(FoodTypeHeuristic.classify("Chicken sausage"), .poultry)
    }

    func testShakesAndBarsAreDistinguished() {
        XCTAssertEqual(FoodTypeHeuristic.classify("Premier Protein shake"), .shake)
        XCTAssertEqual(FoodTypeHeuristic.classify("Quest protein bar"), .bar)
        XCTAssertEqual(FoodTypeHeuristic.classify("Whey isolate"), .shake)
    }

    func testTreats() {
        XCTAssertEqual(FoodTypeHeuristic.classify("Chocolate chip cookie"), .treat)
        XCTAssertEqual(FoodTypeHeuristic.classify("Pepperoni pizza"), .redMeat, "meat wins over pizza")
        XCTAssertEqual(FoodTypeHeuristic.classify("Cheese pizza"), .dairy)
    }

    func testCaseAndPunctuationAreIgnored() {
        XCTAssertEqual(FoodTypeHeuristic.classify("CHICKEN THIGH"), .poultry)
        XCTAssertEqual(FoodTypeHeuristic.classify("  Salmon, wild  "), .seafood)
    }

    func testUnknownNamesAreNotGuessed() {
        XCTAssertEqual(FoodTypeHeuristic.classify("Leftovers"), .unclassified)
        XCTAssertEqual(FoodTypeHeuristic.classify(""), .unclassified)
        XCTAssertEqual(FoodTypeHeuristic.classify("   "), .unclassified)
    }

    func testBreakdownRanksByCountAndKeepsUnclassified() {
        let names = [
            "Chicken breast", "Chicken thigh", "Grilled chicken",
            "Ribeye steak", "Ground beef",
            "Mystery dish"
        ]
        let breakdown = FoodTypeHeuristic.breakdown(of: names)
        XCTAssertEqual(breakdown.first?.type, .poultry)
        XCTAssertEqual(breakdown.first?.count, 3)
        XCTAssertEqual(breakdown[1].type, .redMeat)
        XCTAssertEqual(breakdown[1].count, 2)
        XCTAssertTrue(breakdown.contains { $0.type == .unclassified && $0.count == 1 })
    }

    func testBreakdownDropsEmptyBuckets() {
        let breakdown = FoodTypeHeuristic.breakdown(of: ["Chicken"])
        XCTAssertEqual(breakdown.count, 1)
    }

    func testBreakdownOfNothingIsEmpty() {
        XCTAssertTrue(FoodTypeHeuristic.breakdown(of: []).isEmpty)
    }
}
