import SwiftUI
import SwiftData

@main
struct DailyNutritionTrackerApp: App {
    let container: ModelContainer

    init() {
        container = DataStore.makeContainer()
        NotificationService.shared.configure(container: container)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(HealthKitService.shared)
        }
        .modelContainer(container)
    }
}
