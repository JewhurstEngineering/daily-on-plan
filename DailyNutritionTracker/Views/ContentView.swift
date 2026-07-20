import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var healthKit: HealthKitService
    @State private var selectedDate = Date()
    @State private var showSettings = false
    @State private var showExport = false
    @State private var showReports = false

    var body: some View {
        NavigationStack {
            DayView(selectedDate: $selectedDate, onOpenSettings: { showSettings = true })
                .navigationTitle("Daily Nutrition")
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
                }
                .sheet(isPresented: $showExport) {
                    ExportSheetView(selectedDate: selectedDate)
                }
                .sheet(isPresented: $showReports) {
                    ReportsView()
                }
                .task {
                    await healthKit.requestAuthorization()
                    let settings = DataStore.settings(in: modelContext)
                    await NotificationService.shared.reschedule(using: settings)
                }
        }
    }
}
