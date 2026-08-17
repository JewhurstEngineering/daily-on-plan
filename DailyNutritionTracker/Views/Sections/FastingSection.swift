import SwiftUI
import SwiftData

struct FastingSection: View {
    @Bindable var log: DailyLog
    @Bindable var settings: AppSettings
    var recentLogs: [DailyLog]
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
                streak: FastingMath.streak(logs: recentLogs, settings: settings),
                onChange: { modelContext.saveAndNotifyJournal() }
            )
        }
    }

    private var previousLog: DailyLog? {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: log.date) ?? log.date
        return recentLogs.first { Calendar.current.isDate($0.date, inSameDayAs: yesterday) }
    }
}
