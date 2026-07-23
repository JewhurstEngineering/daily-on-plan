import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var healthKit: HealthKitService
    @Query private var settingsList: [AppSettings]
    @State private var selectedDate = Date()
    @State private var showSettings = false
    @State private var showExport = false
    @State private var showReports = false
    @State private var showBodyComposition = false
    @State private var pendingScrollSection: String?

    private var theme: AccentTheme {
        settingsList.first?.accentTheme ?? .onPlan
    }

    private var accentPrimary: Color {
        settingsList.first?.accentPrimary ?? theme.primary
    }

    private var accentProgress: Color {
        settingsList.first?.accentProgress ?? theme.progress
    }

    private var appearanceMode: AppearanceMode {
        settingsList.first?.appearanceMode ?? .system
    }

    var body: some View {
        TimelineView(.periodic(from: .now, by: appearanceMode == .sunriseSunset ? 60 : 86_400)) { context in
            let scheme = appearanceMode.resolvedColorScheme(at: context.date)
            NavigationStack {
                DayView(
                    selectedDate: $selectedDate,
                    onOpenSettings: { showSettings = true },
                    onOpenBodyComposition: { showBodyComposition = true },
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
                    ToolbarItem(placement: .topBarTrailing) {
                        HStack(spacing: 12) {
                            Button {
                                showReports = true
                            } label: {
                                Image(systemName: "chart.xyaxis.line")
                            }
                            .accessibilityLabel("Reports")
                            Button {
                                showSettings = true
                            } label: {
                                Image(systemName: "gearshape")
                            }
                            .accessibilityLabel("Settings")
                        }
                    }
                }
                .sheet(isPresented: $showSettings) {
                    SettingsView()
                        .tint(accentPrimary)
                        .environment(\.accentTheme, theme)
                        .environment(\.accentPrimary, accentPrimary)
                        .environment(\.accentProgress, accentProgress)
                        .preferredColorScheme(scheme)
                }
                .sheet(isPresented: $showExport) {
                    ExportSheetView(selectedDate: selectedDate)
                        .tint(accentPrimary)
                        .environment(\.accentTheme, theme)
                        .environment(\.accentPrimary, accentPrimary)
                        .environment(\.accentProgress, accentProgress)
                        .preferredColorScheme(scheme)
                }
                .sheet(isPresented: $showReports) {
                    ReportsView()
                        .tint(accentPrimary)
                        .environment(\.accentTheme, theme)
                        .environment(\.accentPrimary, accentPrimary)
                        .environment(\.accentProgress, accentProgress)
                        .preferredColorScheme(scheme)
                }
                .sheet(isPresented: $showBodyComposition) {
                    NavigationStack {
                        BodyCompositionListView()
                    }
                    .tint(accentPrimary)
                    .environment(\.accentTheme, theme)
                    .environment(\.accentPrimary, accentPrimary)
                    .environment(\.accentProgress, accentProgress)
                    .preferredColorScheme(scheme)
                }
                .task {
                    snapToTodayIfNeeded()
                    _ = DataStore.settings(in: modelContext)
                    await healthKit.requestAuthorization()
                    let settings = DataStore.settings(in: modelContext)
                    await NotificationService.shared.reschedule(using: settings)
                }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active {
                        snapToTodayIfNeeded()
                        Task {
                            let settings = DataStore.settings(in: modelContext)
                            await NotificationService.shared.reschedule(using: settings)
                        }
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: .openDaySection)) { note in
                    selectedDate = Date()
                    if let section = note.userInfo?["section"] as? String {
                        if section == "bodyComposition" {
                            showBodyComposition = true
                        } else {
                            pendingScrollSection = section
                        }
                    }
                }
            }
            .environment(\.accentTheme, theme)
            .environment(\.accentPrimary, accentPrimary)
            .environment(\.accentProgress, accentProgress)
            .tint(accentPrimary)
            .preferredColorScheme(scheme)
        }
    }

    /// Roll forward when the app resumes on a later calendar day (left open overnight).
    private func snapToTodayIfNeeded() {
        let startOfToday = DateHelpers.startOfDay(Date())
        if DateHelpers.startOfDay(selectedDate) < startOfToday {
            selectedDate = Date()
        }
    }
}
