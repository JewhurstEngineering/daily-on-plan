import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var healthKit: HealthKitService
    @Query private var settingsList: [AppSettings]
    @State private var selectedDate = Date()
    @State private var showSettings = false
    @State private var showExport = false
    @State private var showReports = false
    @State private var pendingScrollSection: String?

    private var theme: AccentTheme {
        settingsList.first?.accentTheme ?? .onPlan
    }

    var body: some View {
        NavigationStack {
            DayView(
                selectedDate: $selectedDate,
                onOpenSettings: { showSettings = true },
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
                    .tint(theme.primary)
                    .environment(\.accentTheme, theme)
            }
            .sheet(isPresented: $showExport) {
                ExportSheetView(selectedDate: selectedDate)
                    .tint(theme.primary)
                    .environment(\.accentTheme, theme)
            }
            .sheet(isPresented: $showReports) {
                ReportsView()
                    .tint(theme.primary)
                    .environment(\.accentTheme, theme)
            }
            .task {
                _ = DataStore.settings(in: modelContext)
                await healthKit.requestAuthorization()
                let settings = DataStore.settings(in: modelContext)
                await NotificationService.shared.reschedule(using: settings)
            }
            .onReceive(NotificationCenter.default.publisher(for: .openDaySection)) { note in
                selectedDate = Date()
                if let section = note.userInfo?["section"] as? String {
                    pendingScrollSection = section
                }
            }
        }
        .environment(\.accentTheme, theme)
        .tint(theme.primary)
    }
}
