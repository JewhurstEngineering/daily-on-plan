import SwiftUI
import SwiftData

@main
struct DailyNutritionTrackerApp: App {
    let container: ModelContainer

    init() {
        container = DataStore.makeContainer()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(HealthKitService.shared)
        }
        .modelContainer(container)
    }
}
