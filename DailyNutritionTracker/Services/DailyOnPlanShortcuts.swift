import AppIntents

struct DailyOnPlanShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: AddWaterBottleIntent(),
            phrases: [
                "Log water in \(.applicationName)",
                "Add a water bottle in \(.applicationName)"
            ],
            shortTitle: "Add Water",
            systemImageName: "drop.fill"
        )
        AppShortcut(
            intent: AddCigaretteIntent(),
            phrases: [
                "Log a cigarette in \(.applicationName)"
            ],
            shortTitle: "Log Cigarette",
            systemImageName: "flame"
        )
        AppShortcut(
            intent: AddDrinkIntent(),
            phrases: [
                "Log a drink in \(.applicationName)"
            ],
            shortTitle: "Log Drink",
            systemImageName: "wineglass"
        )
        AppShortcut(
            intent: AddBathroomIntent(kind: .urine),
            phrases: [
                "Log bathroom in \(.applicationName)"
            ],
            shortTitle: "Log Bathroom",
            systemImageName: "toilet"
        )
        AppShortcut(
            intent: MarkNextSupplementIntent(),
            phrases: [
                "Mark my supplement in \(.applicationName)"
            ],
            shortTitle: "Mark Supplement",
            systemImageName: "pills"
        )
    }
}
