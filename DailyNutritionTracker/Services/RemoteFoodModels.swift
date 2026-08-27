import Foundation
import OnPlanCore

enum RemoteFoodSource: String, Hashable {
    case openFoodFacts
    case usda

    var title: String {
        switch self {
        case .openFoodFacts: return "Open Food Facts"
        case .usda: return "USDA"
        }
    }
}

struct RemoteFoodCandidate: Identifiable, Hashable {
    let id: String
    let name: String
    let brand: String?
    let servingLabel: String
    let caloriesPerServing: Int
    let source: RemoteFoodSource
    let barcode: String?
    let fdcId: Int?
    /// Label macros for one serving, when the source published them.
    var macros: Macros?
    /// True when the carbohydrate convention was inferred rather than stated, so the confirm
    /// sheet can offer to correct it.
    var carbBasisWasGuessed: Bool = false

    var subtitle: String {
        var parts: [String] = []
        if let brand, !brand.isEmpty { parts.append(brand) }
        parts.append(servingLabel)
        parts.append("\(caloriesPerServing) kcal")
        if let protein = Macros.gramsText(macros?.protein) {
            parts.append("\(protein) g protein")
        }
        parts.append(source.title)
        return parts.joined(separator: " · ")
    }
}

enum RemoteFoodError: LocalizedError {
    case missingAPIKey
    case notFound
    case invalidResponse
    case httpStatus(Int)
    case decoding
    case missingCalories

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "Add a USDA API key in Settings → Food lookup."
        case .notFound:
            return "No matching product found."
        case .invalidResponse:
            return "Unexpected response from the food database."
        case .httpStatus(let code):
            return "Food database error (\(code))."
        case .decoding:
            return "Could not read food data."
        case .missingCalories:
            return "Product found, but calories are missing — enter them manually."
        }
    }
}
