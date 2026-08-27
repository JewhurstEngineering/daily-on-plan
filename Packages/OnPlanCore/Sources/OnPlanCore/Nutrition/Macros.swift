import Foundation

/// Label macros for one logged amount of food.
///
/// Every field is optional because labels and food databases are patchy — a missing value means
/// "not known", never "zero". Grams throughout, except the two `Mg` fields.
///
/// Stored as JSON on `ProteinEntry` (totals for the logged amount) and on `CustomFoodPreset`
/// (per unit serving), following the `waterDrinksJSON` / `componentsJSON` idiom used elsewhere.
public struct Macros: Codable, Hashable, Sendable {

    /// Which convention `totalCarb` follows, because the two regions disagree and the food
    /// databases don't record which one a product used.
    ///
    /// - `total`: US/Canada "Total Carbohydrate" — fibre and polyols are *included*, so net carbs
    ///   must subtract them.
    /// - `available`: EU/UK "carbohydrate" — fibre is *already excluded*. Subtracting it again
    ///   double-counts.
    public enum CarbBasis: String, Codable, Sendable {
        case total
        case available
    }

    /// Where the numbers came from, so the UI can distinguish measured from inferred.
    public enum Source: String, Codable, Sendable {
        case scan
        case manual
        case preset
        case estimated
    }

    public var protein: Double?
    public var totalCarb: Double?
    public var fiber: Double?
    public var sugars: Double?
    public var addedSugars: Double?
    public var sugarAlcohols: Double?
    public var fat: Double?
    public var saturatedFat: Double?
    public var transFat: Double?
    public var cholesterolMg: Double?
    public var sodiumMg: Double?
    public var alcohol: Double?

    public var carbBasis: CarbBasis
    public var source: Source

    /// Energy as declared on the package. Authoritative when present — see `NutritionMath`.
    public var labelKcal: Int?

    public init(
        protein: Double? = nil,
        totalCarb: Double? = nil,
        fiber: Double? = nil,
        sugars: Double? = nil,
        addedSugars: Double? = nil,
        sugarAlcohols: Double? = nil,
        fat: Double? = nil,
        saturatedFat: Double? = nil,
        transFat: Double? = nil,
        cholesterolMg: Double? = nil,
        sodiumMg: Double? = nil,
        alcohol: Double? = nil,
        carbBasis: CarbBasis = .total,
        source: Source = .manual,
        labelKcal: Int? = nil
    ) {
        self.protein = protein
        self.totalCarb = totalCarb
        self.fiber = fiber
        self.sugars = sugars
        self.addedSugars = addedSugars
        self.sugarAlcohols = sugarAlcohols
        self.fat = fat
        self.saturatedFat = saturatedFat
        self.transFat = transFat
        self.cholesterolMg = cholesterolMg
        self.sodiumMg = sodiumMg
        self.alcohol = alcohol
        self.carbBasis = carbBasis
        self.source = source
        self.labelKcal = labelKcal
    }

    public static let empty = Macros()

    /// True when nothing at all has been filled in — used to decide whether an entry still needs
    /// backfilling.
    public var isEmpty: Bool {
        protein == nil && totalCarb == nil && fiber == nil && sugars == nil
            && addedSugars == nil && sugarAlcohols == nil && fat == nil
            && saturatedFat == nil && transFat == nil && cholesterolMg == nil
            && sodiumMg == nil && alcohol == nil && labelKcal == nil
    }

    /// True when the five fields that carry the day-to-day math are all present.
    public var hasCoreFive: Bool {
        protein != nil && totalCarb != nil && fiber != nil && sugars != nil && fat != nil
    }

    // MARK: - Codable

    /// Decoding tolerates a payload written before a field existed, and defaults the two enums so
    /// an older blob still reads.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        protein = try c.decodeIfPresent(Double.self, forKey: .protein)
        totalCarb = try c.decodeIfPresent(Double.self, forKey: .totalCarb)
        fiber = try c.decodeIfPresent(Double.self, forKey: .fiber)
        sugars = try c.decodeIfPresent(Double.self, forKey: .sugars)
        addedSugars = try c.decodeIfPresent(Double.self, forKey: .addedSugars)
        sugarAlcohols = try c.decodeIfPresent(Double.self, forKey: .sugarAlcohols)
        fat = try c.decodeIfPresent(Double.self, forKey: .fat)
        saturatedFat = try c.decodeIfPresent(Double.self, forKey: .saturatedFat)
        transFat = try c.decodeIfPresent(Double.self, forKey: .transFat)
        cholesterolMg = try c.decodeIfPresent(Double.self, forKey: .cholesterolMg)
        sodiumMg = try c.decodeIfPresent(Double.self, forKey: .sodiumMg)
        alcohol = try c.decodeIfPresent(Double.self, forKey: .alcohol)
        carbBasis = try c.decodeIfPresent(CarbBasis.self, forKey: .carbBasis) ?? .total
        source = try c.decodeIfPresent(Source.self, forKey: .source) ?? .manual
        labelKcal = try c.decodeIfPresent(Int.self, forKey: .labelKcal)
    }
}

// MARK: - JSON storage

public extension Macros {
    /// Decodes a stored blob. Returns nil for nil, empty, or unreadable JSON so a corrupt value
    /// reads as "no macros" rather than throwing at a call site that can't do anything about it.
    static func decode(json: String?) -> Macros? {
        guard let json, !json.isEmpty, let data = json.data(using: .utf8) else { return nil }
        guard let decoded = try? JSONDecoder().decode(Macros.self, from: data) else { return nil }
        return decoded.isEmpty ? nil : decoded
    }

    /// Encodes for storage. An all-nil set encodes to nil so the column stays empty.
    var encodedJSON: String? {
        guard !isEmpty else { return nil }
        guard let data = try? JSONEncoder().encode(self) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}
