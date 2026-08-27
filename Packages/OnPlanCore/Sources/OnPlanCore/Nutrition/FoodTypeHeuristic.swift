import Foundation

/// What kind of food an entry is, inferred from its name at report time.
///
/// Deliberately not stored: nothing extra to pick when logging, and the keyword lists can be
/// improved later without a migration or a re-tagging pass over history. The cost is that
/// anything unrecognised lands in `unclassified` rather than being silently dropped.
public enum FoodType: String, CaseIterable, Identifiable, Sendable {
    case redMeat
    case poultry
    case seafood
    case egg
    case dairy
    case plant
    case shake
    case bar
    case treat
    case unclassified

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .redMeat: return "Red meat"
        case .poultry: return "Poultry"
        case .seafood: return "Seafood"
        case .egg: return "Eggs"
        case .dairy: return "Dairy"
        case .plant: return "Plant"
        case .shake: return "Shakes"
        case .bar: return "Bars"
        case .treat: return "Treats"
        case .unclassified: return "Unclassified"
        }
    }

    /// SF Symbol used in the reports breakdown.
    public var symbolName: String {
        switch self {
        case .redMeat: return "fork.knife"
        case .poultry: return "bird"
        case .seafood: return "fish"
        case .egg: return "oval.portrait"
        case .dairy: return "waterbottle"
        case .plant: return "leaf"
        case .shake: return "cup.and.saucer"
        case .bar: return "rectangle.split.3x1"
        case .treat: return "birthday.cake"
        case .unclassified: return "questionmark.circle"
        }
    }
}

/// Keyword classifier for food names, in the mould of `DrinkKindHeuristic`.
public enum FoodTypeHeuristic {

    /// Order matters: the first list with a hit wins, so the more specific forms are checked
    /// before the general ones. "Turkey bacon" is poultry, not red meat; "protein bar" is a bar,
    /// not a shake.
    private static let rules: [(FoodType, [String])] = [
        (.shake, [
            "shake", "protein powder", "whey", "casein", "isolate", "premier protein",
            "fairlife core power", "muscle milk", "smoothie", "rtd", "meal replacement"
        ]),
        (.bar, [
            "protein bar", "quest bar", "clif", "rx bar", "rxbar", "kind bar", "power bar",
            "granola bar", "protein cookie"
        ]),
        (.poultry, [
            "chicken", "turkey", "duck", "hen", "poultry", "rotisserie", "chick-fil", "nugget"
        ]),
        (.seafood, [
            "fish", "salmon", "tuna", "cod", "tilapia", "halibut", "haddock", "trout", "sardine",
            "anchov", "mackerel", "shrimp", "prawn", "crab", "lobster", "scallop", "oyster",
            "mussel", "clam", "calamari", "squid", "seafood", "pollock", "mahi"
        ]),
        (.redMeat, [
            "beef", "steak", "burger", "ground chuck", "sirloin", "ribeye", "brisket", "pork",
            "bacon", "ham", "sausage", "lamb", "veal", "venison", "bison", "pepperoni", "salami",
            "prosciutto", "chorizo", "meatball", "jerky", "hot dog", "hotdog", "ribs", "pastrami"
        ]),
        (.egg, ["egg", "omelet", "omelette", "frittata", "egg white"]),
        (.dairy, [
            "yogurt", "yoghurt", "greek", "cottage cheese", "cheese", "milk", "cheddar",
            "mozzarella", "parmesan", "ricotta", "skyr", "kefir", "cream cheese", "butter"
        ]),
        (.plant, [
            "tofu", "tempeh", "seitan", "edamame", "lentil", "bean", "chickpea", "hummus",
            "quinoa", "almond", "peanut", "walnut", "cashew", "pistachio", "nut butter",
            "soy", "pea protein", "veggie burger", "falafel", "oat"
        ]),
        (.treat, [
            "cake", "cookie", "candy", "chocolate", "ice cream", "donut", "doughnut", "pastry",
            "brownie", "pie", "chips", "crisps", "fries", "pizza", "soda", "dessert", "pudding",
            "croissant", "muffin"
        ])
    ]

    /// Classifies a food name. Unknown names return `.unclassified` rather than a guess.
    public static func classify(_ name: String) -> FoodType {
        let lower = name.lowercased()
        guard !lower.trimmingCharacters(in: .whitespaces).isEmpty else { return .unclassified }

        // "Turkey bacon" and friends: a poultry word anywhere beats a red-meat word, because the
        // qualifier is the thing that makes it poultry.
        if rules.first(where: { $0.0 == .poultry })?.1.contains(where: { lower.contains($0) }) == true {
            return .poultry
        }
        for (type, keywords) in rules where keywords.contains(where: { lower.contains($0) }) {
            return type
        }
        return .unclassified
    }

    /// Counts names by type, heaviest first, dropping empty buckets.
    public static func breakdown(of names: [String]) -> [(type: FoodType, count: Int)] {
        var counts: [FoodType: Int] = [:]
        for name in names {
            counts[classify(name), default: 0] += 1
        }
        return counts
            .map { (type: $0.key, count: $0.value) }
            .sorted {
                $0.count == $1.count
                    ? $0.type.title < $1.type.title
                    : $0.count > $1.count
            }
    }
}
