import SwiftUI
import SwiftData
import OnPlanCore

struct MacNotificationsSettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var allSettings: [AppSettings]

    var body: some View {
        NavigationStack {
            Group {
                if let settings = allSettings.first {
                    NotificationsSettingsView(settings: settings)
                } else {
                    ProgressView("Waiting for journal…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .onAppear {
                            _ = DataStore.settings(in: modelContext)
                        }
                }
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }
}
