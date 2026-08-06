import Foundation

struct DrinkScanCandidate: Identifiable, Hashable {
    let id: String
    let name: String
    let brand: String?
    let suggestedOz: Double?
    let kind: HydrationDrinkKind
    let otherSubtype: HydrationOtherSubtype?
    let barcode: String?

    var subtitle: String {
        var parts: [String] = []
        if let brand, !brand.isEmpty { parts.append(brand) }
        if let suggestedOz {
            parts.append(String(format: suggestedOz == suggestedOz.rounded() ? "%.0f oz" : "%.1f oz", suggestedOz))
        }
        parts.append(WaterSlotRecord(oz: 1, kind: kind, otherSubtype: otherSubtype).displayLabel)
        return parts.joined(separator: " · ")
    }
}

enum OpenFoodFactsClient {
    private static let baseURL = URL(string: "https://world.openfoodfacts.org")!

    static var userAgent: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let name = AppIdentity.displayName.replacingOccurrences(of: " ", with: "")
        return "\(name)/\(version) (personal-ios-app)"
    }

    static func product(barcode: String) async throws -> RemoteFoodCandidate {
        let product = try await fetchProduct(barcode: barcode)
        let name = product.productName?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let name, !name.isEmpty else { throw RemoteFoodError.notFound }

        let calories = product.caloriesPerServing ?? 0
        let serving = product.servingSize?.trimmingCharacters(in: .whitespacesAndNewlines)
        let servingLabel = (serving?.isEmpty == false) ? serving! : "1 serving"
        let brand = product.brands?.split(separator: ",").first.map {
            String($0).trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return RemoteFoodCandidate(
            id: "off-\(product.code ?? barcode)",
            name: name,
            brand: brand,
            servingLabel: servingLabel,
            caloriesPerServing: max(0, calories),
            source: .openFoodFacts,
            barcode: product.code ?? barcode,
            fdcId: nil
        )
    }

    static func drink(barcode: String) async throws -> DrinkScanCandidate {
        let product = try await fetchProduct(barcode: barcode)
        let name = product.productName?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let name, !name.isEmpty else { throw RemoteFoodError.notFound }

        let brand = product.brands?.split(separator: ",").first.map {
            String($0).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        let haystack = [name, brand, product.quantity, product.productQuantity, product.servingSize]
            .compactMap { $0 }
            .joined(separator: " ")
        let guess = DrinkKindHeuristic.guess(from: haystack)
        let oz = DrinkVolumeParser.fluidOunces(
            servingSize: product.servingSize,
            quantity: product.quantity,
            productQuantity: product.productQuantity,
            servingQuantity: product.servingQuantity
        )

        return DrinkScanCandidate(
            id: "off-drink-\(product.code ?? barcode)",
            name: name,
            brand: brand,
            suggestedOz: oz,
            kind: guess.kind,
            otherSubtype: guess.subtype,
            barcode: product.code ?? barcode
        )
    }

    private static func fetchProduct(barcode: String) async throws -> OFFProduct {
        let code = barcode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !code.isEmpty else { throw RemoteFoodError.notFound }

        var components = URLComponents(
            url: baseURL.appendingPathComponent("api/v2/product/\(code)"),
            resolvingAgainstBaseURL: false
        )!
        components.queryItems = [
            URLQueryItem(
                name: "fields",
                value: "code,product_name,brands,serving_size,serving_quantity,quantity,product_quantity,nutriments"
            )
        ]
        guard let url = components.url else { throw RemoteFoodError.invalidResponse }

        var request = URLRequest(url: url)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 20

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw RemoteFoodError.invalidResponse }
        guard (200...299).contains(http.statusCode) else { throw RemoteFoodError.httpStatus(http.statusCode) }

        let decoded = try JSONDecoder().decode(OFFProductResponse.self, from: data)
        guard decoded.status == 1, let product = decoded.product else {
            throw RemoteFoodError.notFound
        }
        return product
    }
}

enum DrinkKindHeuristic {
    static func guess(from text: String) -> (kind: HydrationDrinkKind, subtype: HydrationOtherSubtype?) {
        let lower = text.lowercased()

        let electrolyteTokens = [
            "electrolyte", "lmnt", "liquid i.v", "liquid iv", "pedialyte", "nuun",
            "hydration multiplier", "dripdrop", "liquidiv"
        ]
        if electrolyteTokens.contains(where: { lower.contains($0) }) {
            return (.electrolyte, nil)
        }

        let waterTokens = ["purified water", "spring water", "distilled water", "drinking water", "mineral water"]
        if waterTokens.contains(where: { lower.contains($0) })
            || (lower.contains("water")
                && !lower.contains("coconut")
                && !lower.contains("soda")
                && !lower.contains("tonic")
                && !lower.contains("watermelon")
                && !lower.contains("water ice")) {
            return (.water, nil)
        }

        if lower.contains("coffee") || lower.contains("espresso") || lower.contains("latte") || lower.contains("cold brew") {
            return (.other, .coffee)
        }
        if lower.contains("tea") || lower.contains("chai") {
            return (.other, .tea)
        }
        if lower.contains("juice") || lower.contains("nectar") || lower.contains("lemonade") {
            return (.other, .juice)
        }
        if lower.contains("soda") || lower.contains("cola") || lower.contains("pepsi") || lower.contains("coke")
            || lower.contains("sprite") || lower.contains("fanta") || lower.contains("soft drink") {
            return (.other, .soda)
        }
        if lower.contains("sparkling") || lower.contains("seltzer") || lower.contains("la croix") || lower.contains("bubbly") {
            return (.other, .sparkling)
        }
        if lower.contains("milk") || lower.contains("oatly") || lower.contains("almond milk") {
            return (.other, .milk)
        }

        return (.other, .other)
    }
}

enum DrinkVolumeParser {
    private static let mlPerFlOz = 29.5735

    static func fluidOunces(
        servingSize: String?,
        quantity: String?,
        productQuantity: String?,
        servingQuantity: Double?
    ) -> Double? {
        for raw in [servingSize, quantity, productQuantity] {
            if let oz = parse(raw) { return oz }
        }
        if let qty = servingQuantity, qty > 0 {
            if qty >= 50 { return roundOz(qty / mlPerFlOz) }
            if qty <= 40 { return roundOz(qty) }
        }
        return nil
    }

    static func parse(_ raw: String?) -> Double? {
        guard let raw else { return nil }
        let text = raw.lowercased().replacingOccurrences(of: ",", with: ".")
        let pattern = #"(\d+(?:\.\d+)?)\s*(fl\.?\s*oz|floz|oz|ml|l|liter|litre)\b"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let valueRange = Range(match.range(at: 1), in: text),
              let unitRange = Range(match.range(at: 2), in: text),
              let value = Double(text[valueRange]) else {
            return nil
        }
        let unit = String(text[unitRange]).replacingOccurrences(of: " ", with: "")
        switch unit {
        case "ml":
            return roundOz(value / mlPerFlOz)
        case "l", "liter", "litre":
            return roundOz(value * 1000 / mlPerFlOz)
        default:
            return roundOz(value)
        }
    }

    private static func roundOz(_ value: Double) -> Double {
        (value * 10).rounded() / 10
    }
}

private struct OFFProductResponse: Decodable {
    let status: Int
    let product: OFFProduct?
}

private struct OFFProduct: Decodable {
    let code: String?
    let productName: String?
    let brands: String?
    let servingSize: String?
    let servingQuantity: Double?
    let quantity: String?
    let productQuantity: String?
    let nutriments: OFFNutriments?

    enum CodingKeys: String, CodingKey {
        case code
        case productName = "product_name"
        case brands
        case servingSize = "serving_size"
        case servingQuantity = "serving_quantity"
        case quantity
        case productQuantity = "product_quantity"
        case nutriments
    }

    var caloriesPerServing: Int? {
        if let serving = nutriments?.energyKcalServing, serving > 0 {
            return Int(serving.rounded())
        }
        if let per100 = nutriments?.energyKcal100g, per100 > 0 {
            if let qty = servingQuantity, qty > 0 {
                return max(1, Int((per100 * qty / 100.0).rounded()))
            }
            return Int(per100.rounded())
        }
        return nil
    }
}

private struct OFFNutriments: Decodable {
    let energyKcalServing: Double?
    let energyKcal100g: Double?

    enum CodingKeys: String, CodingKey {
        case energyKcalServing = "energy-kcal_serving"
        case energyKcal100g = "energy-kcal_100g"
    }
}
