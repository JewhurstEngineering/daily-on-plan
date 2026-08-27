import Foundation

/// Energy conversion factors and the derived numbers built on them.
///
/// Factors are the EU Reg. 1169/2011 Annex XIV table, which is the most complete published set —
/// it gives fibre and polyols their own values instead of lumping them into carbohydrate. US
/// 21 CFR 101.9(c)(1)(i) permits either plain 4/4/9 on *total* carbohydrate or 4/4/9 with fibre
/// removed plus 2 kcal/g for soluble non-digestible carbohydrate, so two US labels for the same
/// food can legally disagree.
///
/// That is why `resolvedKcal` prefers the number printed on the package: our arithmetic is a
/// sensible reconstruction, not a more correct answer than the manufacturer's.
public enum NutritionMath {

    // MARK: - Factors (kcal per gram)

    public static let kcalPerGramProtein: Double = 4
    public static let kcalPerGramFat: Double = 9
    public static let kcalPerGramCarb: Double = 4
    public static let kcalPerGramFiber: Double = 2
    public static let kcalPerGramAlcohol: Double = 7

    /// Polyols are 2.4 kcal/g in the EU table. Erythritol is separately listed at 0, but labels
    /// almost never break it out of the polyol total, so everything here is charged at 2.4 —
    /// an overestimate for erythritol-sweetened products.
    public static let kcalPerGramSugarAlcohol: Double = 2.4

    // MARK: - Net carbs

    /// Carbohydrate that actually counts: fibre and sugar alcohols removed.
    ///
    /// Not a regulated term. What it subtracts depends on `carbBasis`, because an EU label has
    /// already removed fibre before printing the number — subtracting it a second time is the
    /// single easiest way to get this wrong.
    ///
    /// A missing fibre or polyol value is treated as zero (nothing to subtract), but a missing
    /// `totalCarb` yields nil, since "no carbs recorded" is not the same as "zero carbs".
    public static func netCarb(_ macros: Macros) -> Double? {
        guard let totalCarb = macros.totalCarb else { return nil }
        let polyols = macros.sugarAlcohols ?? 0
        switch macros.carbBasis {
        case .total:
            // US: fibre and polyols are both inside the declared total.
            return max(0, totalCarb - (macros.fiber ?? 0) - polyols)
        case .available:
            // EU: fibre is already out, but polyols are still in — the regulation defines
            // carbohydrate as "any carbohydrate metabolised by humans, and includes polyols".
            return max(0, totalCarb - polyols)
        }
    }

    // MARK: - Energy

    /// Energy reconstructed from the macros.
    ///
    /// Returns nil when there is nothing to work from — a set with no protein, fat or carbohydrate
    /// would otherwise report a confident zero.
    public static func computedKcal(_ macros: Macros) -> Int? {
        guard macros.protein != nil || macros.fat != nil || macros.totalCarb != nil
            || macros.alcohol != nil
        else { return nil }

        var kcal = 0.0
        kcal += (macros.protein ?? 0) * kcalPerGramProtein
        kcal += (macros.fat ?? 0) * kcalPerGramFat
        kcal += (macros.alcohol ?? 0) * kcalPerGramAlcohol
        kcal += (netCarb(macros) ?? 0) * kcalPerGramCarb
        kcal += (macros.fiber ?? 0) * kcalPerGramFiber
        kcal += (macros.sugarAlcohols ?? 0) * kcalPerGramSugarAlcohol
        return max(0, Int(kcal.rounded()))
    }

    /// The kcal to actually use: what the package declared, falling back to our arithmetic.
    public static func resolvedKcal(_ macros: Macros) -> Int? {
        macros.labelKcal ?? computedKcal(macros)
    }

    /// How far the declared and computed figures diverge, as a fraction of the declared value.
    ///
    /// Nil when either is unavailable or the declared value is zero. Intended as a typo check —
    /// legitimate rounding and the competing US calculation methods produce small differences, so
    /// only a large gap is worth surfacing.
    public static func kcalDisagreement(_ macros: Macros) -> Double? {
        guard let label = macros.labelKcal, label > 0, let computed = computedKcal(macros) else {
            return nil
        }
        return abs(Double(computed) - Double(label)) / Double(label)
    }

    /// Gap beyond which the entry sheet warns that the numbers don't line up.
    public static let kcalDisagreementThreshold: Double = 0.15

    public static func kcalLooksInconsistent(_ macros: Macros) -> Bool {
        guard let gap = kcalDisagreement(macros) else { return false }
        return gap > kcalDisagreementThreshold
    }
}

// MARK: - Scaling and summing

public extension Macros {

    /// Net carbohydrate for this set, honouring `carbBasis`.
    var netCarb: Double? { NutritionMath.netCarb(self) }

    /// Energy to display: declared if the package gave one, otherwise reconstructed.
    var resolvedKcal: Int? { NutritionMath.resolvedKcal(self) }

    var computedKcal: Int? { NutritionMath.computedKcal(self) }

    /// Restates the set so `totalCarb` always means *total* carbohydrate, fibre included.
    ///
    /// Needed before comparing or adding sets that came from different regions.
    func normalized() -> Macros {
        guard carbBasis == .available else { return self }
        var copy = self
        if let carb = totalCarb {
            copy.totalCarb = carb + (fiber ?? 0)
        }
        copy.carbBasis = .total
        return copy
    }

    /// Multiplies every quantity — used to turn a per-serving set into the amount actually eaten.
    func scaled(by factor: Double) -> Macros {
        guard factor != 1 else { return self }
        func scale(_ value: Double?) -> Double? {
            guard let value else { return nil }
            return value * factor
        }
        var copy = self
        copy.protein = scale(protein)
        copy.totalCarb = scale(totalCarb)
        copy.fiber = scale(fiber)
        copy.sugars = scale(sugars)
        copy.addedSugars = scale(addedSugars)
        copy.sugarAlcohols = scale(sugarAlcohols)
        copy.fat = scale(fat)
        copy.saturatedFat = scale(saturatedFat)
        copy.transFat = scale(transFat)
        copy.cholesterolMg = scale(cholesterolMg)
        copy.sodiumMg = scale(sodiumMg)
        copy.alcohol = scale(alcohol)
        if let labelKcal {
            copy.labelKcal = max(0, Int((Double(labelKcal) * factor).rounded()))
        }
        return copy
    }

    /// Adds two sets, normalising both to total-carbohydrate first.
    ///
    /// A field present on one side and missing on the other is carried through rather than
    /// discarded, so a day total reflects everything actually known. `source` is not meaningful
    /// on a sum and is left as the left-hand side's.
    static func + (lhs: Macros, rhs: Macros) -> Macros {
        let a = lhs.normalized()
        let b = rhs.normalized()
        func add(_ x: Double?, _ y: Double?) -> Double? {
            guard x != nil || y != nil else { return nil }
            return (x ?? 0) + (y ?? 0)
        }
        var sum = Macros(carbBasis: .total, source: lhs.source)
        sum.protein = add(a.protein, b.protein)
        sum.totalCarb = add(a.totalCarb, b.totalCarb)
        sum.fiber = add(a.fiber, b.fiber)
        sum.sugars = add(a.sugars, b.sugars)
        sum.addedSugars = add(a.addedSugars, b.addedSugars)
        sum.sugarAlcohols = add(a.sugarAlcohols, b.sugarAlcohols)
        sum.fat = add(a.fat, b.fat)
        sum.saturatedFat = add(a.saturatedFat, b.saturatedFat)
        sum.transFat = add(a.transFat, b.transFat)
        sum.cholesterolMg = add(a.cholesterolMg, b.cholesterolMg)
        sum.sodiumMg = add(a.sodiumMg, b.sodiumMg)
        sum.alcohol = add(a.alcohol, b.alcohol)
        // Energy sums the *resolved* figure from each side, so an entry with a declared kcal and
        // one with only macros both contribute. Otherwise a day total would drop everything that
        // never carried a package figure.
        let energy = [a.resolvedKcal, b.resolvedKcal].compactMap { $0 }
        if !energy.isEmpty {
            sum.labelKcal = energy.reduce(0, +)
        }
        return sum
    }
}

public extension Sequence where Element == Macros {
    /// Day (or meal) total. Empty sequences yield nil rather than a zeroed set.
    func total() -> Macros? {
        reduce(into: Macros?.none) { partial, next in
            partial = partial.map { $0 + next } ?? next
        }
    }
}
