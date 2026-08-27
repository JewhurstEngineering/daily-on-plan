import XCTest
@testable import OnPlanCore

final class NutritionMathTests: XCTestCase {

    // MARK: - Energy

    func testComputedKcalUsesStandardFactors() {
        // 54 g protein, 0 carb, 7 g fat: 4(54) + 9(7) = 279
        let chicken = Macros(protein: 54, totalCarb: 0, fiber: 0, fat: 7)
        XCTAssertEqual(chicken.computedKcal, 279)
    }

    func testFiberIsChargedAtTwoNotFour() {
        // 20 g total carb of which 10 g fibre: 4(10 net) + 2(10 fibre) = 60, not 4(20) = 80.
        let beans = Macros(totalCarb: 20, fiber: 10)
        XCTAssertEqual(beans.computedKcal, 60)
    }

    func testSugarAlcoholsAreChargedAtTwoPointFour() {
        // A protein bar: 24 g carb, 3 g fibre, 15 g polyols.
        // net = 24 - 3 - 15 = 6 → 4(6) + 2(3) + 2.4(15) = 24 + 6 + 36 = 66
        let bar = Macros(totalCarb: 24, fiber: 3, sugarAlcohols: 15)
        XCTAssertEqual(bar.computedKcal, 66)
    }

    func testAlcoholIsChargedAtSeven() {
        let wine = Macros(totalCarb: 4, fiber: 0, alcohol: 14)
        XCTAssertEqual(wine.computedKcal, 16 + 98)
    }

    func testComputedKcalIsNilWhenNothingIsKnown() {
        // Sodium alone must not report a confident zero.
        XCTAssertNil(Macros(sodiumMg: 300).computedKcal)
    }

    func testComputedKcalIsZeroForAGenuineZero() {
        XCTAssertEqual(Macros(protein: 0, totalCarb: 0, fat: 0).computedKcal, 0)
    }

    func testLabelKcalWinsOverComputed() {
        // The manufacturer's figure is authoritative even when our arithmetic disagrees.
        let macros = Macros(protein: 54, totalCarb: 0, fat: 7, labelKcal: 290)
        XCTAssertEqual(macros.computedKcal, 279)
        XCTAssertEqual(macros.resolvedKcal, 290)
    }

    func testResolvedKcalFallsBackToComputed() {
        XCTAssertEqual(Macros(protein: 10, totalCarb: 0, fat: 0).resolvedKcal, 40)
    }

    // MARK: - Net carbs

    func testNetCarbSubtractsFibreOnATotalCarbLabel() {
        let macros = Macros(totalCarb: 15, fiber: 4, carbBasis: .total)
        XCTAssertEqual(macros.netCarb, 11)
    }

    func testNetCarbDoesNotSubtractFibreTwiceOnAnEULabel() {
        // The regression this whole basis flag exists to prevent.
        let macros = Macros(totalCarb: 15, fiber: 4, carbBasis: .available)
        XCTAssertEqual(macros.netCarb, 15)
    }

    func testNetCarbSubtractsPolyolsUnderBothConventions() {
        // EU carbohydrate excludes fibre but still includes polyols.
        XCTAssertEqual(Macros(totalCarb: 20, fiber: 5, sugarAlcohols: 8, carbBasis: .total).netCarb, 7)
        XCTAssertEqual(Macros(totalCarb: 20, fiber: 5, sugarAlcohols: 8, carbBasis: .available).netCarb, 12)
    }

    func testNetCarbClampsAtZero() {
        // Rounded label values can sum to more than the declared total.
        let macros = Macros(totalCarb: 5, fiber: 6, carbBasis: .total)
        XCTAssertEqual(macros.netCarb, 0)
    }

    func testNetCarbIsNilWhenCarbsWereNeverRecorded() {
        XCTAssertNil(Macros(protein: 20, fat: 5).netCarb)
    }

    func testMissingFibreIsTreatedAsNothingToSubtract() {
        XCTAssertEqual(Macros(totalCarb: 12, carbBasis: .total).netCarb, 12)
    }

    // MARK: - Real payloads captured from the live APIs

    func testUSLabelResolvesToTotalCarbs() {
        // Lay's Classic, barcode 038000138416, per 28 g serving as Open Food Facts returns it.
        let lays = Macros(
            protein: 0.98,
            totalCarb: 16,
            fiber: 1.12,
            sugars: 0.28,
            fat: 8.96,
            saturatedFat: 2.52,
            sodiumMg: 150,
            carbBasis: .total,
            source: .scan,
            labelKcal: 150
        )
        XCTAssertEqual(lays.netCarb ?? 0, 14.88, accuracy: 0.01)
        XCTAssertEqual(lays.resolvedKcal, 150)
        // Our reconstruction should land close enough to the declared figure not to warn.
        XCTAssertFalse(NutritionMath.kcalLooksInconsistent(lays))
    }

    func testEULabelWithNoFibreKeepsItsCarbsIntact() {
        // Nutella, barcode 3017624010701, per 100 g. An EU label: carbohydrate already excludes
        // fibre, and Open Food Facts carries no fibre value at all for this product.
        let nutella = Macros(
            protein: 6.3,
            totalCarb: 57.5,
            fiber: nil,
            sugars: 56.3,
            fat: 30.9,
            carbBasis: .available,
            source: .scan
        )
        XCTAssertEqual(nutella.netCarb, 57.5)
        // 4(6.3) + 4(57.5) + 9(30.9) = 25.2 + 230 + 278.1 = 533.3
        XCTAssertEqual(nutella.computedKcal, 533)
    }

    // MARK: - Disagreement check

    func testDisagreementFlagsATransposedMacro() {
        // 7 g protein and 54 g fat — the chicken entry with two fields swapped.
        let swapped = Macros(protein: 7, totalCarb: 0, fat: 54, labelKcal: 279)
        XCTAssertTrue(NutritionMath.kcalLooksInconsistent(swapped))
    }

    func testDisagreementToleratesLabelRounding() {
        let rounded = Macros(protein: 54, totalCarb: 0, fat: 7, labelKcal: 280)
        XCTAssertFalse(NutritionMath.kcalLooksInconsistent(rounded))
    }

    func testDisagreementIsNilWithoutALabelFigure() {
        XCTAssertNil(NutritionMath.kcalDisagreement(Macros(protein: 20)))
    }

    // MARK: - Scaling

    func testScalingMultipliesEveryQuantity() {
        let perServing = Macros(protein: 20, totalCarb: 10, fiber: 2, fat: 5, labelKcal: 165)
        let eaten = perServing.scaled(by: 1.5)
        XCTAssertEqual(eaten.protein, 30)
        XCTAssertEqual(eaten.totalCarb, 15)
        XCTAssertEqual(eaten.fiber, 3)
        XCTAssertEqual(eaten.fat, 7.5)
        XCTAssertEqual(eaten.labelKcal, 248)
    }

    func testScalingLeavesMissingFieldsMissing() {
        XCTAssertNil(Macros(protein: 20).scaled(by: 2).sugars)
    }

    func testScalingByOneIsIdentity() {
        let macros = Macros(protein: 20, totalCarb: 10)
        XCTAssertEqual(macros.scaled(by: 1), macros)
    }

    // MARK: - Summing a day

    func testNormalizingRestatesEUCarbsAsTotal() {
        let eu = Macros(totalCarb: 20, fiber: 5, carbBasis: .available)
        let normalized = eu.normalized()
        XCTAssertEqual(normalized.totalCarb, 25)
        XCTAssertEqual(normalized.carbBasis, .total)
        // Net carbs must be unchanged by the restatement.
        XCTAssertEqual(normalized.netCarb, eu.netCarb)
    }

    func testSumNormalizesMixedRegions() {
        let us = Macros(totalCarb: 15, fiber: 4, carbBasis: .total)
        let eu = Macros(totalCarb: 20, fiber: 5, carbBasis: .available)
        let sum = us + eu
        XCTAssertEqual(sum.totalCarb, 40)          // 15 + (20 + 5)
        XCTAssertEqual(sum.netCarb, 31)            // 11 + 20
        XCTAssertEqual(sum.carbBasis, .total)
    }

    func testSumCarriesFieldsPresentOnOnlyOneSide() {
        let a = Macros(protein: 20, sodiumMg: 300)
        let b = Macros(protein: 10, sugars: 4)
        let sum = a + b
        XCTAssertEqual(sum.protein, 30)
        XCTAssertEqual(sum.sodiumMg, 300)
        XCTAssertEqual(sum.sugars, 4)
        XCTAssertNil(sum.fiber)
    }

    func testDayTotalSumsDeclaredAndComputedEnergyTogether() {
        let scanned = Macros(protein: 10, totalCarb: 0, fat: 0, labelKcal: 100)
        let typed = Macros(protein: 25, totalCarb: 0, fat: 0)
        XCTAssertEqual([scanned, typed].total()?.resolvedKcal, 200)
    }

    func testTotalOfEmptySequenceIsNil() {
        XCTAssertNil([Macros]().total())
    }

    // MARK: - Storage

    func testJSONRoundTrip() {
        let macros = Macros(
            protein: 24, totalCarb: 8, fiber: 3, sugars: 1, sugarAlcohols: 2,
            fat: 6, sodiumMg: 220, carbBasis: .available, source: .scan, labelKcal: 180
        )
        let json = macros.encodedJSON
        XCTAssertNotNil(json)
        XCTAssertEqual(Macros.decode(json: json), macros)
    }

    func testEmptyMacrosEncodeToNilSoTheColumnStaysEmpty() {
        XCTAssertNil(Macros.empty.encodedJSON)
    }

    func testDecodingToleratesNilEmptyAndGarbage() {
        XCTAssertNil(Macros.decode(json: nil))
        XCTAssertNil(Macros.decode(json: ""))
        XCTAssertNil(Macros.decode(json: "not json"))
        XCTAssertNil(Macros.decode(json: "{}"))
    }

    func testDecodingAPayloadMissingTheEnumsUsesDefaults() {
        // A blob written before carbBasis/source existed must still read.
        let decoded = Macros.decode(json: #"{"protein":20,"totalCarb":5}"#)
        XCTAssertEqual(decoded?.protein, 20)
        XCTAssertEqual(decoded?.carbBasis, .total)
        XCTAssertEqual(decoded?.source, .manual)
    }

    func testHasCoreFive() {
        XCTAssertTrue(Macros(protein: 1, totalCarb: 1, fiber: 1, sugars: 1, fat: 1).hasCoreFive)
        XCTAssertFalse(Macros(protein: 1, totalCarb: 1, fat: 1).hasCoreFive)
    }
}
