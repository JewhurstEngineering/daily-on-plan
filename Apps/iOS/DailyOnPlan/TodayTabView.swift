import SwiftUI
import SwiftData
import WidgetKit
import OnPlanCore

struct TodayTabView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.appTheme) private var appTheme
    @Environment(\.colorScheme) private var scheme
    @EnvironmentObject private var healthKit: HealthKitService
    @EnvironmentObject private var store: OnPlanStore
    var onOpenSettings: () -> Void = {}
    @State private var selectedDate = Date()
    @State private var showExport = false
    @State private var showBodyComposition = false
    @State private var showBodyMeasurements = false
    @State private var pendingScrollSection: String?

    /// `\.appTheme` (from the app-wide Theme setting) drives every accent color here — see docs/DESIGN_IMPROVEMENT_PLAN.md §5.1.
    private var accentPrimary: Color { appTheme.tint }
    private var accentProgress: Color { appTheme.protein }

    var body: some View {
        NavigationStack {
            DayView(
                selectedDate: $selectedDate,
                onOpenSettings: onOpenSettings,
                onOpenBodyComposition: { showBodyComposition = true },
                onOpenBodyMeasurements: { showBodyMeasurements = true },
                pendingScrollSection: $pendingScrollSection
            )
            .navigationTitle(AppIdentity.displayName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showExport = true
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .accessibilityLabel("Export")
                }
            }
            .sheet(isPresented: $showExport) {
                ExportSheetView(selectedDate: selectedDate)
                    .tint(accentPrimary)
                    .environment(\.accentPrimary, accentPrimary)
                    .environment(\.accentProgress, accentProgress)
                    .preferredColorScheme(scheme)
            }
            .sheet(isPresented: $showBodyComposition) {
                NavigationStack {
                    BodyCompositionListView()
                }
                .tint(accentPrimary)
                .environment(\.accentPrimary, accentPrimary)
                .environment(\.accentProgress, accentProgress)
                .preferredColorScheme(scheme)
            }
            .sheet(isPresented: $showBodyMeasurements) {
                NavigationStack {
                    BodyMeasurementsListView()
                }
                .tint(accentPrimary)
                .environment(\.accentPrimary, accentPrimary)
                .environment(\.accentProgress, accentProgress)
                .preferredColorScheme(scheme)
            }
            .task {
                snapToTodayIfNeeded()
                _ = DataStore.settings(in: modelContext)
                let alreadyOffered = UserDefaults.standard.bool(forKey: FirstLaunchImportView.didOfferKey)
                if alreadyOffered || DataStore.hasAnyJournalData(in: modelContext) {
                    await healthKit.requestAuthorization()
                }
                let settings = DataStore.settings(in: modelContext)
                await NotificationService.shared.reschedule(using: settings)
                store.setSnapshot(ChromeSnapshotBuilder.fromToday())
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active {
                    snapToTodayIfNeeded()
                    PhoneWatchBridge.shared.pushSnapshot()
                    store.setSnapshot(ChromeSnapshotBuilder.fromToday())
                    Task {
                        let settings = DataStore.settings(in: modelContext)
                        await NotificationService.shared.reschedule(using: settings)
                    }
                } else {
                    WidgetReloader.reloadAll()
                    PhoneWatchBridge.shared.pushSnapshot()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .openDaySection)) { note in
                selectedDate = Date()
                if let section = note.userInfo?["section"] as? String {
                    if section == "bodyComposition" {
                        showBodyComposition = true
                    } else if section == "bodyMeasurements" {
                        showBodyMeasurements = true
                    } else {
                        pendingScrollSection = section
                    }
                }
            }
        }
        .environment(\.accentPrimary, accentPrimary)
        .environment(\.accentProgress, accentProgress)
        .tint(accentPrimary)
        .preferredColorScheme(scheme)
    }

    private func snapToTodayIfNeeded() {
        let startOfToday = DateHelpers.startOfDay(Date())
        if DateHelpers.startOfDay(selectedDate) < startOfToday {
            selectedDate = Date()
        }
    }
}
