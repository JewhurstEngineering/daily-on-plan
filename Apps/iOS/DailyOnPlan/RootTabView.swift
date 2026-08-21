import SwiftUI
import SwiftData
import OnPlanCore

private enum RootTab: Hashable {
    case today, reports, settings
}

struct RootTabView: View {
    @EnvironmentObject private var store: OnPlanStore
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase

    /// Owned here so a revealed weight is re-hidden the moment the app leaves the
    /// foreground, and never survives a relaunch.
    @StateObject private var weightReveal = WeightRevealState()
    @State private var showFirstLaunchImport = false
    @State private var didEvaluateFirstLaunch = false
    @State private var selectedTab: RootTab = {
        #if DEBUG
        // Lets a screenshot run open straight onto a tab: `-dop.startTab trends`.
        switch UserDefaults.standard.string(forKey: "dop.startTab") {
        case "trends": return .reports
        case "settings": return .settings
        default: return .today
        }
        #else
        .today
        #endif
    }()

    var body: some View {
        ZStack {
            if didEvaluateFirstLaunch {
                TabView(selection: $selectedTab) {
                    TodayTabView(onOpenSettings: { selectedTab = .settings })
                        .tabItem { Label("Today", systemImage: "checkmark.seal.fill") }
                        .tag(RootTab.today)
                    TrendsView()
                        .tabItem { Label("Trends", systemImage: "chart.xyaxis.line") }
                        .tag(RootTab.reports)
                    PhoneSettingsView()
                        .tabItem { Label("Settings", systemImage: "gearshape.fill") }
                        .tag(RootTab.settings)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .environmentObject(weightReveal)
        .rehidesWeightOnBackground(weightReveal, phase: scenePhase)
        .appThemed(store.preferences)
        .sheet(isPresented: $showFirstLaunchImport) {
            FirstLaunchImportView()
                .environmentObject(HealthKitService.shared)
        }
        .task { evaluateFirstLaunchImport() }
    }

    private func evaluateFirstLaunchImport() {
        guard !didEvaluateFirstLaunch else { return }
        #if DEBUG
        SampleDataSeeder.seedIfRequested(in: modelContext)
        #endif
        let alreadyOffered = UserDefaults.standard.bool(forKey: FirstLaunchImportView.didOfferKey)
        if !alreadyOffered && !DataStore.hasAnyJournalData(in: modelContext) {
            showFirstLaunchImport = true
        }
        didEvaluateFirstLaunch = true
    }
}
