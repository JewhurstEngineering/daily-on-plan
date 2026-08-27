import Foundation

/// Display strings for macros. Shared so the log rows, the export and the reports all phrase
/// a gram value the same way.
public extension Macros {

    /// Grams with at most one decimal, trailing `.0` dropped: `24`, `2.5`.
    static func gramsText(_ value: Double?) -> String? {
        guard let value else { return nil }
        let rounded = (value * 10).rounded() / 10
        if rounded == rounded.rounded() {
            return String(format: "%.0f", rounded)
        }
        return String(format: "%.1f", rounded)
    }

    /// One-line summary for a log row: `P 24g · C 8g (5 net) · F 6g`.
    /// Skips anything that was never recorded rather than printing a misleading zero.
    var compactSummary: String {
        var parts: [String] = []
        if let p = Macros.gramsText(protein) { parts.append("P \(p)g") }
        if let c = Macros.gramsText(totalCarb) {
            if let net = Macros.gramsText(netCarb), net != c {
                parts.append("C \(c)g (\(net) net)")
            } else {
                parts.append("C \(c)g")
            }
        }
        if let f = Macros.gramsText(fat) { parts.append("F \(f)g") }
        return parts.joined(separator: " · ")
    }

    /// Every recorded value, for the export and the detail view.
    var fullSummary: String {
        var parts: [String] = []
        func add(_ label: String, _ value: Double?, _ unit: String = "g") {
            guard let text = Macros.gramsText(value) else { return }
            parts.append("\(label) \(text)\(unit)")
        }
        add("protein", protein)
        add("carb", totalCarb)
        if let net = Macros.gramsText(netCarb) { parts.append("netCarb \(net)g") }
        add("fiber", fiber)
        add("sugars", sugars)
        add("addedSugars", addedSugars)
        add("sugarAlcohols", sugarAlcohols)
        add("fat", fat)
        add("satFat", saturatedFat)
        add("transFat", transFat)
        add("cholesterol", cholesterolMg, "mg")
        add("sodium", sodiumMg, "mg")
        add("alcohol", alcohol)
        if carbBasis == .available { parts.append("carbBasis available") }
        parts.append("source \(source.rawValue)")
        return parts.joined(separator: " ")
    }
}
