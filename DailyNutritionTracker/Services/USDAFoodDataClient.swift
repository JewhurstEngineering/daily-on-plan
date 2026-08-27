import Foundation
import OnPlanCore

enum USDAFoodDataClient {
    private static let baseURL = URL(string: "https://api.nal.usda.gov/fdc/v1")!

    struct KeyTestResult: Equatable {
        let succeeded: Bool
        let message: String
        let sampleFoodName: String?
    }

    /// Lightweight search used to verify an API key works.
    static func testAPIKey(_ apiKey: String) async -> KeyTestResult {
        let trimmedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedKey.isEmpty else {
            return KeyTestResult(succeeded: false, message: "Paste a USDA API key first.", sampleFoodName: nil)
        }

        do {
            let foods = try await search(query: "egg", apiKey: trimmedKey, pageSize: 1)
            if let name = foods.first?.name {
                return KeyTestResult(
                    succeeded: true,
                    message: "Key works. Sample result: \(name)",
                    sampleFoodName: name
                )
            }
            return KeyTestResult(
                succeeded: true,
                message: "Key works (USDA responded OK).",
                sampleFoodName: nil
            )
        } catch RemoteFoodError.httpStatus(let code) where code == 401 || code == 403 {
            return KeyTestResult(
                succeeded: false,
                message: "Key rejected (HTTP \(code)). Check that you copied the full key from api.data.gov.",
                sampleFoodName: nil
            )
        } catch RemoteFoodError.httpStatus(let code) {
            return KeyTestResult(
                succeeded: false,
                message: "USDA returned HTTP \(code). Try again in a moment.",
                sampleFoodName: nil
            )
        } catch let error as URLError where error.code == .notConnectedToInternet {
            return KeyTestResult(
                succeeded: false,
                message: "No internet connection.",
                sampleFoodName: nil
            )
        } catch {
            return KeyTestResult(
                succeeded: false,
                message: error.localizedDescription,
                sampleFoodName: nil
            )
        }
    }

    static func search(query: String, apiKey: String, pageSize: Int = 12) async throws -> [RemoteFoodCandidate] {
        let trimmedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedKey.isEmpty else { throw RemoteFoodError.missingAPIKey }

        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard q.count >= 2 else { return [] }

        var components = URLComponents(url: baseURL.appendingPathComponent("foods/search"), resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "api_key", value: trimmedKey),
            URLQueryItem(name: "query", value: q),
            URLQueryItem(name: "pageSize", value: String(pageSize)),
            URLQueryItem(name: "dataType", value: "Foundation,SR Legacy,Branded")
        ]
        guard let url = components.url else { throw RemoteFoodError.invalidResponse }

        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 20

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw RemoteFoodError.invalidResponse }
        guard (200...299).contains(http.statusCode) else { throw RemoteFoodError.httpStatus(http.statusCode) }

        let decoded = try JSONDecoder().decode(USDASearchResponse.self, from: data)
        return (decoded.foods ?? []).compactMap { food in
            guard let fdcId = food.fdcId else { return nil }
            let name = food.description?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !name.isEmpty else { return nil }

            let calories = food.caloriesPerServing
            guard let calories, calories > 0 else { return nil }

            let brand = food.brandOwner ?? food.brandName
            let servingLabel = food.servingLabel

            return RemoteFoodCandidate(
                id: "usda-\(fdcId)",
                name: name,
                brand: brand,
                servingLabel: servingLabel,
                caloriesPerServing: calories,
                source: .usda,
                barcode: food.gtinUpc,
                fdcId: fdcId,
                macros: food.macrosPerServing,
                carbBasisWasGuessed: false
            )
        }
    }
}

private struct USDASearchResponse: Decodable {
    let foods: [USDAFood]?
}

private struct USDAFood: Decodable {
    let fdcId: Int?
    let description: String?
    let brandOwner: String?
    let brandName: String?
    let gtinUpc: String?
    let servingSize: Double?
    let servingSizeUnit: String?
    let householdServingFullText: String?
    let foodNutrients: [USDANutrient]?

    var servingLabel: String {
        if let text = householdServingFullText?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty {
            return text
        }
        if let size = servingSize, size > 0 {
            let unit = servingSizeUnit?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "g"
            if size == floor(size) {
                return "\(Int(size)) \(unit)"
            }
            return String(format: "%.1f %@", size, unit)
        }
        return "100 g"
    }

    /// Energy nutrient number 1008 is kcal. Search results often include it inline.
    var caloriesPerServing: Int? {
        guard let value = nutrientValue(id: 1008, nameContains: "Energy", unit: "kcal"), value > 0 else {
            return nil
        }
        return max(1, Int(scaledToServing(value).rounded()))
    }

    /// Looks a nutrient up by FoodData Central id, falling back to a name match.
    ///
    /// The id is matched against both `nutrientId` and `nutrientNumber` because the search and
    /// detail endpoints disagree about which they populate, and the name fallback covers ids that
    /// shift between dataset releases.
    private func nutrientValue(id: Int, nameContains name: String, unit: String? = nil) -> Double? {
        guard let nutrients = foodNutrients else { return nil }
        for nutrient in nutrients {
            let matchesID = nutrient.nutrientId == id || nutrient.nutrientNumber == String(id)
            let matchesName = nutrient.nutrientName?.localizedCaseInsensitiveContains(name) == true
                && (unit == nil
                    || nutrient.unitName?.localizedCaseInsensitiveCompare(unit!) == .orderedSame)
            guard matchesID || matchesName else { continue }
            if let value = nutrient.value ?? nutrient.amount { return value }
        }
        return nil
    }

    /// USDA figures are per 100 g for Foundation and SR Legacy; branded rows are per serving.
    private func scaledToServing(_ value: Double) -> Double {
        if let size = servingSize, size > 0, size != 100,
           householdServingFullText == nil,
           brandOwner == nil, brandName == nil {
            return value * size / 100.0
        }
        return value
    }

    /// Macros for one serving.
    ///
    /// Nutrient 1005 is "Carbohydrate, by difference", which always includes fibre — USDA has no
    /// EU-style available-carbohydrate ambiguity to resolve.
    var macrosPerServing: Macros? {
        func grams(_ id: Int, _ name: String) -> Double? {
            guard let value = nutrientValue(id: id, nameContains: name) else { return nil }
            return scaledToServing(value)
        }

        let macros = Macros(
            protein: grams(1003, "Protein"),
            totalCarb: grams(1005, "Carbohydrate, by difference"),
            fiber: grams(1079, "Fiber, total dietary"),
            sugars: grams(2000, "Sugars, total"),
            addedSugars: grams(1235, "Sugars, added"),
            sugarAlcohols: grams(1086, "Sugar alcohol"),
            fat: grams(1004, "Total lipid"),
            saturatedFat: grams(1258, "Fatty acids, total saturated"),
            transFat: grams(1257, "Fatty acids, total trans"),
            cholesterolMg: grams(1253, "Cholesterol"),
            sodiumMg: grams(1093, "Sodium"),
            alcohol: grams(1018, "Alcohol, ethyl"),
            carbBasis: .total,
            source: .scan,
            labelKcal: caloriesPerServing
        )
        return macros.isEmpty ? nil : macros
    }
}

private struct USDANutrient: Decodable {
    let nutrientId: Int?
    let nutrientNumber: String?
    let nutrientName: String?
    let unitName: String?
    let value: Double?
    let amount: Double?
}
