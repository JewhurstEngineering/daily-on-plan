import SwiftUI
import SwiftData
import WidgetKit
import OnPlanCore

@main
struct DailyOnPlanApp: App {
    let container: ModelContainer
    @StateObject private var store = OnPlanStore()

    init() {
        container = DataStore.makeContainer()
        NotificationService.shared.configure(container: container)
        PhoneWatchBridge.shared.activate()
        PhoneWatchBridge.shared.pushSnapshot()
    }

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environmentObject(HealthKitService.shared)
                .environmentObject(store)
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
