import SwiftUI
import SwiftData
import WidgetKit

@main
struct DailyNutritionTrackerApp: App {
    let container: ModelContainer

    init() {
        container = DataStore.makeContainer()
        NotificationService.shared.configure(container: container)
        PhoneWatchBridge.shared.activate()
        PhoneWatchBridge.shared.pushSnapshot()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(HealthKitService.shared)
                .onOpenURL { url in
                    handleDeepLink(url)
                }
        }
        .modelContainer(container)
    }

    private func handleDeepLink(_ url: URL) {
        guard let section = AppDeepLink.section(from: url) else { return }
        NotificationCenter.default.post(
            name: .openDaySection,
            object: nil,
            userInfo: ["section": section]
        )
    }
}
