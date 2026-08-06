import WidgetKit
import SwiftUI

struct WatchComplicationEntry: TimelineEntry {
    let date: Date
    let snapshot: WatchDaySnapshot
}

struct WatchComplicationProvider: TimelineProvider {
    func placeholder(in context: Context) -> WatchComplicationEntry {
        WatchComplicationEntry(date: Date(), snapshot: .empty)
    }

    func getSnapshot(in context: Context, completion: @escaping (WatchComplicationEntry) -> Void) {
        completion(WatchComplicationEntry(date: Date(), snapshot: WatchSnapshotCache.load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WatchComplicationEntry>) -> Void) {
        let entry = WatchComplicationEntry(date: Date(), snapshot: WatchSnapshotCache.load())
        let next = Calendar.current.date(byAdding: .minute, value: 15, to: Date()) ?? Date().addingTimeInterval(900)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}

struct WatchProteinComplication: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "com.dailyonplan.watch.protein", provider: WatchComplicationProvider()) { entry in
            WatchProteinView(entry: entry)
                .containerBackground(for: .widget) { Color.clear }
        }
        .configurationDisplayName("Protein")
        .description("Today’s protein progress.")
        .supportedFamilies(watchFamilies)
    }
}

struct WatchWaterComplication: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "com.dailyonplan.watch.water", provider: WatchComplicationProvider()) { entry in
            WatchWaterView(entry: entry)
                .containerBackground(for: .widget) { Color.clear }
        }
        .configurationDisplayName("Hydration")
        .description("Today’s water progress.")
        .supportedFamilies(watchFamilies)
    }
}

struct WatchSummaryComplication: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "com.dailyonplan.watch.summary", provider: WatchComplicationProvider()) { entry in
            WatchSummaryComplicationView(entry: entry)
                .containerBackground(for: .widget) { Color.clear }
        }
        .configurationDisplayName("Daily Summary")
        .description("Protein and water at a glance.")
        .supportedFamilies([.accessoryRectangular, .accessoryInline])
    }
}

private var watchFamilies: [WidgetFamily] {
    #if os(watchOS)
    [
        .accessoryCircular,
        .accessoryCorner,
        .accessoryInline,
        .accessoryRectangular
    ]
    #else
    [
        .accessoryCircular,
        .accessoryInline,
        .accessoryRectangular
    ]
    #endif
}

struct WatchProteinView: View {
    @Environment(\.widgetFamily) private var family
    let entry: WatchComplicationEntry

    var body: some View {
        switch family {
        case .accessoryCircular:
            Gauge(value: entry.snapshot.proteinFraction) {
                Text("P")
            } currentValueLabel: {
                Text("\(entry.snapshot.proteinCalories)")
            }
            .gaugeStyle(.accessoryCircularCapacity)
        case .accessoryInline:
            Text("P \(entry.snapshot.proteinCalories)/\(entry.snapshot.proteinGoal)")
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 2) {
                Text("Protein")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text("\(entry.snapshot.proteinCalories)/\(entry.snapshot.proteinGoal)")
                    .font(.headline.monospacedDigit())
                Text("\(entry.snapshot.proteinLeft) left")
                    .font(.caption2)
                    .foregroundStyle(.orange)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        default:
            #if os(watchOS)
            if family == .accessoryCorner {
                Text("\(entry.snapshot.proteinCalories)")
                    .widgetAccentable()
            } else {
                Text("\(entry.snapshot.proteinCalories)")
            }
            #else
            Text("\(entry.snapshot.proteinCalories)")
            #endif
        }
    }
}

struct WatchWaterView: View {
    @Environment(\.widgetFamily) private var family
    let entry: WatchComplicationEntry

    var body: some View {
        switch family {
        case .accessoryCircular:
            Gauge(value: entry.snapshot.waterFraction) {
                Text("H")
            } currentValueLabel: {
                Text("\(entry.snapshot.waterOz)")
            }
            .gaugeStyle(.accessoryCircularCapacity)
        case .accessoryInline:
            Text("H \(entry.snapshot.waterOz)/\(entry.snapshot.waterTargetOz)")
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 2) {
                Text("Water")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text("\(entry.snapshot.waterOz)/\(entry.snapshot.waterTargetOz) oz")
                    .font(.headline.monospacedDigit())
                Text("\(entry.snapshot.waterLeft) left")
                    .font(.caption2)
                    .foregroundStyle(.cyan)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        default:
            #if os(watchOS)
            if family == .accessoryCorner {
                Text("\(entry.snapshot.waterOz)")
                    .widgetAccentable()
            } else {
                Text("\(entry.snapshot.waterOz)")
            }
            #else
            Text("\(entry.snapshot.waterOz)")
            #endif
        }
    }
}

struct WatchSummaryComplicationView: View {
    @Environment(\.widgetFamily) private var family
    let entry: WatchComplicationEntry

    var body: some View {
        switch family {
        case .accessoryInline:
            Text("P \(entry.snapshot.proteinCalories) · H \(entry.snapshot.waterOz)")
        default:
            VStack(alignment: .leading, spacing: 2) {
                Text("P \(entry.snapshot.proteinCalories)/\(entry.snapshot.proteinGoal)")
                    .font(.caption.weight(.semibold).monospacedDigit())
                Text("H \(entry.snapshot.waterOz)/\(entry.snapshot.waterTargetOz)")
                    .font(.caption.weight(.semibold).monospacedDigit())
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

@main
struct DailyNutritionTrackerWatchWidgetsBundle: WidgetBundle {
    var body: some Widget {
        WatchProteinComplication()
        WatchWaterComplication()
        WatchSummaryComplication()
    }
}
