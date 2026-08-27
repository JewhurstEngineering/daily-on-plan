import Foundation

/// The two judgement calls a food-database import has to make, kept pure so they can be tested
/// against real payloads without a network.
public enum LabelConventions {

    /// Which carbohydrate convention a product's figures follow.
    ///
    /// Open Food Facts stores one `carbohydrates` field copied from whatever the package printed
    /// and does not record whether fibre was included, so it has to be inferred:
    ///
    /// 1. An explicit `carbohydrates-total` figure is only produced for US-style labels.
    /// 2. Otherwise a US or Canadian market means a fibre-inclusive total.
    /// 3. Otherwise assume the EU convention, where fibre is already excluded.
    ///
    /// A product with no country tags at all falls back to `.total`, matching the US label the
    /// user is most likely holding — flagged as a guess so the UI can offer to correct it.
    ///
    /// - Returns: the basis, and whether it was inferred rather than stated.
    public static func carbBasis(
        hasExplicitTotalCarb: Bool,
        countryTags: [String]
    ) -> (basis: Macros.CarbBasis, wasGuessed: Bool) {
        if hasExplicitTotalCarb {
            return (.total, false)
        }
        if countryTags.contains(where: { $0 == "en:united-states" || $0 == "en:canada" }) {
            return (.total, true)
        }
        if countryTags.isEmpty {
            return (.total, true)
        }
        return (.available, true)
    }

    /// A nutrient figure for one serving.
    ///
    /// Prefers a published per-serving value; otherwise scales the per-100g value by the serving
    /// size. With no serving size to scale by, the per-100g figure is returned as-is — which is
    /// what "per 100 g" means for a product sold by weight.
    public static func perServing(
        servingValue: Double?,
        per100Value: Double?,
        servingQuantity: Double?
    ) -> Double? {
        if let servingValue { return servingValue }
        guard let per100Value else { return nil }
        if let servingQuantity, servingQuantity > 0 {
            return per100Value * servingQuantity / 100.0
        }
        return per100Value
    }
}
