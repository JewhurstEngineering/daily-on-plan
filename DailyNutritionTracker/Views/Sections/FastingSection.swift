import SwiftUI
import SwiftData

struct FastingSection: View {
    @Bindable var log: DailyLog
    @Bindable var settings: AppSettings
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        SectionCard(
            title: "Fasting",
            systemImage: "clock",
            isCollapsed: settings.sectionCollapsedBinding(.fasting, context: modelContext),
            collapsedMessage: DaySectionID.fasting.collapsedMessage
        ) {
            FastingTrackerCard(
                log: log,
                previous: previousLog,
                settings: settings,
                streak: streak,
                onChange: { modelContext.saveAndNotifyJournal() }
            )
        }
    }

    private var previousLog: DailyLog? {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: log.date) ?? log.date
        return DataStore.existingLog(for: yesterday, in: modelContext)
    }

    private var streak: Int {
        let recent = DataStore.logs(
            from: Calendar.current.date(byAdding: .day, value: -60, to: log.date) ?? log.date,
            to: log.date,
            in: modelContext
        )
        return FastingMath.streak(logs: recent, settings: settings)
    }
}
