import Foundation

public enum MenuBarFormatter {
    public static func title(
        snapshot: ChromeSnapshot?,
        preferences: DisplayPreferences
    ) -> String {
        guard let snapshot else { return "On Plan" }
        let toggles = preferences.menuBar
        var parts: [String] = []

        func metric(_ enabled: Bool, icons: String, words: String) {
            guard enabled else { return }
            parts.append(preferences.menuBarLabelStyle == .icons ? icons : words)
        }

        if preferences.menuBarFormat == .compact {
            if toggles.protein {
                return preferences.menuBarLabelStyle == .icons
                    ? "P \(snapshot.proteinCalories)"
                    : "Protein \(snapshot.proteinCalories)"
            }
            if toggles.water {
                return preferences.menuBarLabelStyle == .icons
                    ? "W \(snapshot.waterOz)"
                    : "Water \(snapshot.waterOz) oz"
            }
            return snapshot.followedPlan ? "On plan" : "Off plan"
        }

        metric(toggles.followedPlan, icons: snapshot.followedPlan ? "✓" : "✗", words: snapshot.followedPlan ? "Plan" : "Off")
        metric(toggles.ketosis, icons: snapshot.ketosis ? "🔥" : "○", words: snapshot.ketosis ? "Keto" : "No keto")
        metric(toggles.protein, icons: "P \(snapshot.proteinCalories)", words: "Protein \(snapshot.proteinCalories)")
        metric(toggles.water, icons: "W \(snapshot.waterOz)", words: "Water \(snapshot.waterOz) oz")
        if toggles.smoking, snapshot.smokingEnabled {
            metric(true, icons: "S \(snapshot.cigarettes)", words: "Cigs \(snapshot.cigarettes)")
        }
        if toggles.drinking, snapshot.drinkingEnabled {
            metric(true, icons: "D \(snapshot.drinks)", words: "Drinks \(snapshot.drinks)")
        }
        if parts.isEmpty { return "On Plan" }
        return parts.joined(separator: " · ")
    }
}
