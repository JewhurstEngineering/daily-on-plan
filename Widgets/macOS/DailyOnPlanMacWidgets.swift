import WidgetKit
import SwiftUI
import OnPlanCore

struct DailyStatusEntry: TimelineEntry {
    let date: Date
    let snapshot: ChromeSnapshot?
}

struct DailyStatusProvider: TimelineProvider {
    func placeholder(in context: Context) -> DailyStatusEntry {
        DailyStatusEntry(date: .now, snapshot: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (DailyStatusEntry) -> Void) {
        completion(DailyStatusEntry(date: .now, snapshot: ChromeSnapshotStore.read()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<DailyStatusEntry>) -> Void) {
        let entry = DailyStatusEntry(date: .now, snapshot: ChromeSnapshotStore.read())
        completion(Timeline(entries: [entry], policy: .after(.now.addingTimeInterval(15 * 60))))
    }
}

struct DailyStatusWidgetView: View {
    @Environment(\.widgetFamily) private var family
    var entry: DailyStatusEntry

    var body: some View {
        Group {
            if let snap = entry.snapshot, snap.generatedAt != .distantPast {
                switch family {
                case .systemMedium:
                    medium(snap)
                default:
                    small(snap)
                }
            } else {
                Text("Open Daily On Plan to sync.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            }
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }

    private func small(_ snap: ChromeSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "checkmark.seal.fill")
                Text(snap.followedPlan ? "On plan" : "Off plan")
                    .font(.caption.weight(.semibold))
                Spacer(minLength: 0)
            }
            Spacer(minLength: 0)
            metric("Protein", current: snap.proteinCalories, goal: snap.proteinGoal, fraction: snap.proteinFraction)
            metric("Water", current: snap.waterOz, goal: snap.waterTargetOz, fraction: snap.waterFraction)
        }
    }

    private func medium(_ snap: ChromeSnapshot) -> some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Label(snap.followedPlan ? "On plan" : "Off plan", systemImage: "checkmark.seal.fill")
                    .font(.subheadline.weight(.semibold))
                Text(snap.ketosis ? "Ketosis" : "No ketosis")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
            }
            VStack(alignment: .leading, spacing: 10) {
                metric("Protein", current: snap.proteinCalories, goal: snap.proteinGoal, fraction: snap.proteinFraction)
                metric("Water", current: snap.waterOz, goal: snap.waterTargetOz, fraction: snap.waterFraction)
            }
        }
    }

    private func metric(_ title: String, current: Int, goal: Int, fraction: Double) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(title)
                    .font(.caption2.weight(.semibold))
                Spacer()
                Text("\(current)/\(goal)")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.primary.opacity(0.12))
                    Capsule()
                        .fill(title == "Water" ? Color.cyan : Color.blue)
                        .frame(width: geo.size.width * min(1, max(0, fraction)))
                }
            }
            .frame(height: 6)
        }
    }
}

struct DailyStatusWidget: Widget {
    let kind = "DailyOnPlanMacStatus"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: DailyStatusProvider()) { entry in
            DailyStatusWidgetView(entry: entry)
        }
        .configurationDisplayName("Daily Status")
        .description("Protein, water, and plan for today.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

@main
struct DailyOnPlanMacWidgets: WidgetBundle {
    var body: some Widget {
        DailyStatusWidget()
    }
}
