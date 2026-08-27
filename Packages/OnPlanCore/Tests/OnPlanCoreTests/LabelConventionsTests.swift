import XCTest
@testable import OnPlanCore

/// Cases drawn from real Open Food Facts payloads, so the two regional conventions stay
/// distinguishable as the import code changes.
final class LabelConventionsTests: XCTestCase {

    // MARK: - Carb basis

    func testExplicitTotalCarbFieldIsTakenAtItsWord() {
        // Lay's Classic (038000138416) returns carbohydrates-total alongside carbohydrates.
        let result = LabelConventions.carbBasis(
            hasExplicitTotalCarb: true,
            countryTags: ["en:united-states", "en:france"]
        )
        XCTAssertEqual(result.basis, .total)
        XCTAssertFalse(result.wasGuessed, "an explicit total-carb field is a statement, not a guess")
    }

    func testUSMarketWithoutTheExplicitFieldIsGuessedAsTotal() {
        let result = LabelConventions.carbBasis(
            hasExplicitTotalCarb: false,
            countryTags: ["en:united-states"]
        )
        XCTAssertEqual(result.basis, .total)
        XCTAssertTrue(result.wasGuessed)
    }

    func testCanadaCountsAsATotalCarbMarket() {
        XCTAssertEqual(
            LabelConventions.carbBasis(hasExplicitTotalCarb: false, countryTags: ["en:canada"]).basis,
            .total
        )
    }

    func testEuropeanProductIsAvailableCarb() {
        // Nutella (3017624010701): French/UK, no carbohydrates-total, no fibre figure.
        let result = LabelConventions.carbBasis(
            hasExplicitTotalCarb: false,
            countryTags: ["en:france", "en:united-kingdom"]
        )
        XCTAssertEqual(result.basis, .available)
        XCTAssertTrue(result.wasGuessed)
    }

    func testNoCountryTagsFallsBackToTotal() {
        // Nothing to go on: assume the US label in front of the user, and flag it as a guess.
        let result = LabelConventions.carbBasis(hasExplicitTotalCarb: false, countryTags: [])
        XCTAssertEqual(result.basis, .total)
        XCTAssertTrue(result.wasGuessed)
    }

    func testMixedMarketsPreferTotalWhenTheUSIsAmongThem() {
        let result = LabelConventions.carbBasis(
            hasExplicitTotalCarb: false,
            countryTags: ["en:germany", "en:united-states"]
        )
        XCTAssertEqual(result.basis, .total)
    }

    // MARK: - Per serving

    func testPublishedServingValueIsUsedAsIs() {
        XCTAssertEqual(
            LabelConventions.perServing(servingValue: 16, per100Value: 57, servingQuantity: 28),
            16
        )
    }

    func testPer100IsScaledByServingSize() {
        // Lay's: 57 g carb per 100 g, 28 g serving → 15.96 g.
        let value = LabelConventions.perServing(
            servingValue: nil, per100Value: 57, servingQuantity: 28
        )
        XCTAssertEqual(value ?? 0, 15.96, accuracy: 0.001)
    }

    func testPer100IsReturnedWhenThereIsNoServingSize() {
        XCTAssertEqual(
            LabelConventions.perServing(servingValue: nil, per100Value: 57.5, servingQuantity: nil),
            57.5
        )
    }

    func testZeroServingQuantityDoesNotZeroTheValue() {
        XCTAssertEqual(
            LabelConventions.perServing(servingValue: nil, per100Value: 30, servingQuantity: 0),
            30
        )
    }

    func testMissingOnBothSidesIsNil() {
        XCTAssertNil(
            LabelConventions.perServing(servingValue: nil, per100Value: nil, servingQuantity: 28)
        )
    }

    // MARK: - End to end on the captured payloads

    func testLaysServingMacrosProduceTheDeclaredCalories() {
        // Per 28 g serving, from the live API response.
        let basis = LabelConventions.carbBasis(
            hasExplicitTotalCarb: true,
            countryTags: ["en:united-states"]
        )
        let macros = Macros(
            protein: 0.98,
            totalCarb: 16,
            fiber: 1.12,
            sugars: 0.28,
            fat: 8.96,
            saturatedFat: 2.52,
            sodiumMg: 0.15 * 1000,
            carbBasis: basis.basis,
            source: .scan,
            labelKcal: 150
        )
        XCTAssertEqual(macros.sodiumMg, 150, "OFF publishes sodium in grams; the app stores mg")
        XCTAssertEqual(macros.netCarb ?? 0, 14.88, accuracy: 0.01)
        XCTAssertFalse(NutritionMath.kcalLooksInconsistent(macros))
    }

    func testNutellaMacrosAreNotFibreCorrected() {
        let basis = LabelConventions.carbBasis(
            hasExplicitTotalCarb: false,
            countryTags: ["en:france", "en:united-kingdom"]
        )
        let macros = Macros(
            protein: 6.3,
            totalCarb: 57.5,
            sugars: 56.3,
            fat: 30.9,
            carbBasis: basis.basis,
            source: .scan
        )
        XCTAssertEqual(macros.netCarb, 57.5)
    }
}
