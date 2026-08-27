import Foundation

/// Macro estimates derived from the meat-exchange chart the app's protein categories come from.
///
/// The exchange system is exact by construction: every meat exchange is 7 g of protein, and the
/// categories differ only in fat — which is what produces the 35 / 55 / 75 kcal steps. So a
/// 55 kcal "lean" entry logged before macros existed can be restated as roughly 7 g protein and
/// 3 g fat without inventing anything.
///
/// Used only to *prefill* the backfill form. Nothing is written from these numbers without the
/// user confirming them, and anything saved is marked `.estimated` unless they edit it.
public enum ExchangeEstimate {

    /// Grams of protein in one meat exchange, the constant the whole chart is built on.
    public static let proteinGramsPerExchange: Double = 7

    /// The three chart rows, as (kcal per exchange, grams of fat per exchange).
    public enum Category: String, CaseIterable, Sendable {
        case veryLean
        case lean
        case mediumFat

        public var kcalPerExchange: Double {
            switch self {
            case .veryLean: return 35
            case .lean: return 55
            case .mediumFat: return 75
            }
        }

        /// Very lean is "0–1 g"; 0.5 is the midpoint rather than a false precision.
        public var fatGramsPerExchange: Double {
            switch self {
            case .veryLean: return 0.5
            case .lean: return 3
            case .mediumFat: return 5
            }
        }
    }

    /// Estimated macros for an entry of `calories` kcal in the given category.
    ///
    /// Returns nil for categories outside the chart — shakes, snacks and substitutions have no
    /// fixed composition, so there is nothing honest to infer.
    public static func macros(calories: Int, category: Category) -> Macros {
        let exchanges = Double(calories) / category.kcalPerExchange
        return Macros(
            protein: round(exchanges * proteinGramsPerExchange, places: 1),
            totalCarb: 0,
            fiber: 0,
            sugars: 0,
            fat: round(exchanges * category.fatGramsPerExchange, places: 1),
            carbBasis: .total,
            source: .estimated,
            labelKcal: calories
        )
    }

    /// Maps a stored `ProteinCategory` raw value onto the chart, when it is on it.
    public static func category(forRawValue raw: String) -> Category? {
        Category(rawValue: raw)
    }

    private static func round(_ value: Double, places: Int) -> Double {
        let factor = pow(10.0, Double(places))
        return (value * factor).rounded() / factor
    }
}
