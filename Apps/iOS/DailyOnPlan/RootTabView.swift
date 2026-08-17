import SwiftUI
import SwiftData
import OnPlanCore

private enum RootTab: Hashable {
    case today, reports, settings
}

struct RootTabView: View {
    @EnvironmentObject private var store: OnPlanStore
    @Environment(\.modelContext) private var modelContext

    @State private var showFirstLaunchImport = false
    @State private var didEvaluateFirstLaunch = false
    @State private var selectedTab: RootTab = .today

    var body: some View {
        ZStack {
            if didEvaluateFirstLaunch {
                TabView(selection: $selectedTab) {
                    TodayTabView(onOpenSettings: { selectedTab = .settings })
                        .tabItem { Label("Today", systemImage: "checkmark.seal.fill") }
                        .tag(RootTab.today)
                    ReportsView(showsCloseButton: false)
                        .tabItem { Label("Reports", systemImage: "chart.xyaxis.line") }
                        .tag(RootTab.reports)
                    PhoneSettingsView()
                        .tabItem { Label("Settings", systemImage: "gearshape.fill") }
                        .tag(RootTab.settings)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .appThemed(store.preferences)
        .sheet(isPresented: $showFirstLaunchImport) {
            FirstLaunchImportView()
                .environmentObject(HealthKitService.shared)
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
