import SwiftUI
import SwiftData
import OnPlanCore

/// The full list behind Today's "See all" — every optional section the viewer still has
/// switched on, one row each, grouped by whether it is part of the daily routine.
struct AlsoTodayScreen: View {
    @Bindable var settings: AppSettings
    @Bindable var log: DailyLog
    let onSelect: (DaySectionID) -> Void

    private var routine: [DaySectionID] {
        AlsoTodayCatalog.sections(for: settings).filter {
            [.fasting, .checklist, .workouts, .feelings].contains($0)
        }
    }

    private var tracking: [DaySectionID] {
        AlsoTodayCatalog.sections(for: settings).filter {
            [.smoking, .drinking, .bathroom, .supplements].contains($0)
        }
    }

    var body: some View {
        List {
            if !routine.isEmpty {
                Section("Part of my day") {
                    ForEach(routine, id: \.self) { section in
                        AlsoTodayRow(section: section, settings: settings, log: log) {
                            onSelect(section)
                        }
                    }
                }
            }

            if !tracking.isEmpty {
                Section {
                    ForEach(tracking, id: \.self) { section in
                        AlsoTodayRow(section: section, settings: settings, log: log) {
                            onSelect(section)
                        }
                    }
                } header: {
                    Text("Tracking")
                } footer: {
                    Text("Switch anything off in Settings → Tracking & habits and it leaves this list and Today for good.")
                }
            }
        }
        .navigationTitle("Also today")
        .onPlanInlineNav()
    }
}

/// Renders one existing section view on its own pushed screen. The section views already
/// hold all the logging behaviour — the redesign changes where they are reached from,
/// not what they do.
struct SectionDetailScreen: View {
    let section: DaySectionID
    let selectedDate: Date
    @Bindable var settings: AppSettings
    @Bindable var log: DailyLog
    let recentLogs: [DailyLog]
    let recentWeights: [WeightEntry]
    let todayWeight: WeightEntry?
    var onSaveWeight: (Double) -> Void = { _ in }
    var onOpenSettings: () -> Void = {}
    var onOpenBodyComposition: () -> Void = {}
    var onOpenBodyMeasurements: () -> Void = {}

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xl) {
                content
            }
            .padding()
        }
        .environment(\.sectionChrome, .detail)
        .background(Color.onPlanGroupedBackground)
        .navigationTitle(section.settingsTitle)
        .onPlanInlineNav()
    }

    @ViewBuilder
    private var content: some View {
        switch section {
        case .weight:
            WeightBMISection(
                selectedDate: selectedDate,
                weight: todayWeight,
                recentWeights: recentWeights,
                settings: settings,
                onSave: onSaveWeight,
                onOpenSettings: onOpenSettings,
                onOpenBodyComposition: onOpenBodyComposition,
                onOpenBodyMeasurements: onOpenBodyMeasurements
            )
        case .protein:
            ProteinSection(log: log, settings: settings, scrollAnchor: "protein")
        case .hydration:
            HydrationSection(
                log: log,
                settings: settings,
                date: selectedDate,
                onOpenSettings: onOpenSettings
            )
        case .dailyStatus, .goals:
            DayHeaderSection(selectedDate: .constant(selectedDate), log: log, settings: settings)
        case .fasting:
            FastingSection(log: log, settings: settings, recentLogs: recentLogs)
        case .checklist:
            ChecklistSection(log: log, settings: settings, scrollAnchor: "checklist")
        case .workouts:
            WorkoutSection(log: log, settings: settings)
        case .feelings:
            FeelingsSection(log: log, settings: settings)
        case .smoking:
            SmokingSection(
                log: log,
                settings: settings,
                recentLogs: recentLogs,
                onOpenSettings: onOpenSettings
            )
        case .drinking:
            DrinkingSection(
                log: log,
                settings: settings,
                recentLogs: recentLogs,
                onOpenSettings: onOpenSettings
            )
        case .bathroom:
            BathroomSection(log: log, settings: settings)
        case .supplements:
            SupplementsSection(log: log, settings: settings)
        }
    }
}
