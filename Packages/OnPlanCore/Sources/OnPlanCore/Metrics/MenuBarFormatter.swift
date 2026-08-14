import Foundation

public struct MenuBarSegment: Sendable, Equatable {
    public var systemImage: String?
    public var text: String
    public var spoken: String

    public init(systemImage: String? = nil, text: String, spoken: String? = nil) {
        self.systemImage = systemImage
        self.text = text
        self.spoken = spoken ?? text
    }
}

public enum MenuBarFormatter {
    public static func segments(
        snapshot: ChromeSnapshot?,
        preferences: DisplayPreferences
    ) -> [MenuBarSegment] {
        guard let snapshot else {
            return [.init(text: "On Plan")]
        }
        let toggles = preferences.menuBar
        let useIcons = preferences.menuBarLabelStyle == .icons
        var parts: [MenuBarSegment] = []

        func add(icon: String, value: String, spoken: String) {
            if useIcons {
                parts.append(.init(systemImage: icon, text: value, spoken: spoken))
            } else {
                parts.append(.init(text: spoken, spoken: spoken))
            }
        }

        if preferences.menuBarFormat == .compact {
            if toggles.protein {
                add(
                    icon: "fork.knife",
                    value: "\(snapshot.proteinCalories)",
                    spoken: "Protein \(snapshot.proteinCalories)"
                )
                return parts
            }
            if toggles.water {
                add(
                    icon: "drop.fill",
                    value: "\(snapshot.waterOz)",
                    spoken: "Water \(snapshot.waterOz) oz"
                )
                return parts
            }
            add(
                icon: snapshot.followedPlan ? "checkmark.seal.fill" : "xmark.seal",
                value: "",
                spoken: snapshot.followedPlan ? "On plan" : "Off plan"
            )
            return parts
        }

        if toggles.followedPlan {
            add(
                icon: snapshot.followedPlan ? "checkmark.seal.fill" : "xmark.seal",
                value: "",
                spoken: snapshot.followedPlan ? "Plan" : "Off"
            )
        }
        if toggles.ketosis {
            add(
                icon: snapshot.ketosis ? "flame.fill" : "flame",
                value: "",
                spoken: snapshot.ketosis ? "Keto" : "No keto"
            )
        }
        if toggles.protein {
            add(
                icon: "fork.knife",
                value: "\(snapshot.proteinCalories)",
                spoken: "Protein \(snapshot.proteinCalories)"
            )
        }
        if toggles.water {
            add(
                icon: "drop.fill",
                value: "\(snapshot.waterOz)",
                spoken: "Water \(snapshot.waterOz) oz"
            )
        }
        if toggles.fasting, snapshot.fastingEnabled {
            add(
                icon: snapshot.isEatingWindowOpen ? "fork.knife.circle.fill" : "clock",
                value: snapshot.fastingStreak > 0 ? "\(snapshot.fastingStreak)" : "",
                spoken: snapshot.fastingStatusLine.isEmpty ? "Fasting" : snapshot.fastingStatusLine
            )
        }
        if toggles.smoking, snapshot.smokingEnabled {
            add(
                icon: "smoke.fill",
                value: "\(snapshot.cigarettes)",
                spoken: "Cigs \(snapshot.cigarettes)"
            )
        }
        if toggles.drinking, snapshot.drinkingEnabled {
            add(
                icon: "wineglass.fill",
                value: "\(snapshot.drinks)",
                spoken: "Drinks \(snapshot.drinks)"
            )
        }
        if parts.isEmpty {
            return [.init(text: "On Plan")]
        }
        return parts
    }

    public static func title(
        snapshot: ChromeSnapshot?,
        preferences: DisplayPreferences
    ) -> String {
        let spoken = segments(snapshot: snapshot, preferences: preferences)
            .map(\.spoken)
            .filter { !$0.isEmpty }
            .joined(separator: " · ")
        return spoken.isEmpty ? "On Plan" : spoken
    }
}
