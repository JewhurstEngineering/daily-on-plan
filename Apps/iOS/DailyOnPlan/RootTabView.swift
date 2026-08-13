import SwiftUI
import SwiftData
import OnPlanCore

struct RootTabView: View {
    @EnvironmentObject private var store: OnPlanStore
    @Environment(\.modelContext) private var modelContext

    @State private var showFirstLaunchImport = false
    @State private var didEvaluateFirstLaunch = false

    var body: some View {
        ZStack {
            if didEvaluateFirstLaunch {
                TabView {
                    TodayTabView()
                        .tabItem { Label("Today", systemImage: "checkmark.seal.fill") }
                    ReportsView(showsCloseButton: false)
                        .tabItem { Label("Reports", systemImage: "chart.xyaxis.line") }
                    PhoneSettingsView()
                        .tabItem { Label("Settings", systemImage: "gearshape.fill") }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .appThemed(store.preferences)
        .sheet(isPresented: $showFirstLaunchImport) {
            FirstLaunchImportView()
        }
        .task { evaluateFirstLaunchImport() }
    }

    private func evaluateFirstLaunchImport() {
        guard !didEvaluateFirstLaunch else { return }
        let alreadyOffered = UserDefaults.standard.bool(forKey: FirstLaunchImportView.didOfferKey)
        if !alreadyOffered && !DataStore.hasAnyJournalData(in: modelContext) {
            showFirstLaunchImport = true
        }
        didEvaluateFirstLaunch = true
    }
}
