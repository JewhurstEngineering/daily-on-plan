import SwiftUI
import SwiftData

/// Protein/hydration rings, the remaining-stats strip, and health glances — split out of the old
/// monolithic "Daily Status" header so this content can collapse and reorder like every other
/// section instead of being permanently pinned and always-expanded. The daily ritual toggles
/// (ketosis, followed plan, notes) stay in `DayHeaderSection`, still pinned at the top.
/// See docs/DESIGN_IMPROVEMENT_PLAN.md §5.5.
struct GoalsSection: View {
    let selectedDate: Date
    @Bindable var log: DailyLog
    @Bindable var settings: AppSettings
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var healthKit: HealthKitService

    var body: some View {
        SectionCard(
            title: "Goals",
            systemImage: "target",
            isCollapsed: settings.sectionCollapsedBinding(.goals, context: modelContext),
            collapsedMessage: DaySectionID.goals.collapsedMessage
        ) {
            HStack(alignment: .top, spacing: 16) {
                VStack(spacing: 8) {
                    GoalRingView(
                        current: log.totalProteinCalories,
                        goal: log.proteinGoal,
                        unit: "kcal",
                        treatOverAsWarning: true
                    )
                    Text("Protein")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)

                VStack(spacing: 8) {
                    GoalRingView(
                        current: log.totalHydrationOz(settings: settings),
                        goal: settings.hydrationTargetOz,
                        unit: "oz",
                        successWhenMet: true,
                        electrolyteSegments: HydrationRingSegments.electrolyteSegments(
                            slots: log.waterSlots,
                            goalOz: settings.hydrationTargetOz
                        )
                    )
                    Text("Hydration")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    if log.hasElectrolyteDrink {
                        Label("Electrolytes", systemImage: "bolt.fill")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(Color.yellow.opacity(0.9))
                    }
                }
                .frame(maxWidth: .infinity)
            }

            remainingStatsStrip

            healthGlances
        }
    }

    private var remainingStatsStrip: some View {
        let waterOz = log.totalHydrationOz(settings: settings)
        let proteinLeft = max(0, log.proteinGoal - log.totalProteinCalories)
        let waterLeft = max(0, settings.hydrationTargetOz - waterOz)
        let todayWeight = DataStore.weight(for: selectedDate, in: modelContext)

        return HStack(spacing: 0) {
            remainingStat(icon: "fork.knife", value: "\(proteinLeft) kcal", caption: "Left")
            Divider().frame(height: 36)
            remainingStat(icon: "drop.fill", value: "\(waterLeft) oz", caption: "Left")
            if settings.smokingMode.showsSection {
                Divider().frame(height: 36)
                remainingStat(icon: "flame.fill", value: "\(log.cigarettesSmoked)", caption: "Cigs")
            }
            if settings.drinkingMode.showsSection {
                Divider().frame(height: 36)
                remainingStat(icon: "wineglass.fill", value: "\(log.drinksLogged)", caption: "Drinks")
            }
            if let todayWeight {
                Divider().frame(height: 36)
                remainingStat(
                    icon: "scalemass.fill",
                    value: String(format: "%.0f", todayWeight.weightLbs),
                    caption: "Weight"
                )
            }
        }
        .padding(.vertical, 10)
        .background(Color.onPlanTertiaryFill, in: RoundedRectangle(cornerRadius: Radius.control))
        .accessibilityElement(children: .combine)
    }

    private func remainingStat(icon: String, value: String, caption: String) -> some View {
        VStack(spacing: 3) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.weight(.semibold).monospacedDigit())
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            Text(caption)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var healthGlances: some View {
        let steps = healthKit.todayStepCount
        let sleep = healthKit.lastNightSleepHours
        if steps != nil || sleep != nil {
            HStack(spacing: 16) {
                if let steps {
                    Label("\(steps) steps", systemImage: "figure.walk")
                }
                if let sleep {
                    Label(String(format: "%.1f h sleep", sleep), systemImage: "moon.zzz")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }
}
