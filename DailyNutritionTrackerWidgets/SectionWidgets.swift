import WidgetKit
import SwiftUI

struct HydrationWidget: Widget {
    var body: some WidgetConfiguration {
        sectionConfig(.hydration)
    }
}

struct ProteinWidget: Widget {
    var body: some WidgetConfiguration {
        sectionConfig(.protein)
    }
}

struct SmokingWidget: Widget {
    var body: some WidgetConfiguration {
        sectionConfig(.smoking)
    }
}

struct DrinkingWidget: Widget {
    var body: some WidgetConfiguration {
        sectionConfig(.drinking)
    }
}

struct BathroomWidget: Widget {
    var body: some WidgetConfiguration {
        sectionConfig(.bathroom)
    }
}

struct WeightWidget: Widget {
    var body: some WidgetConfiguration {
        sectionConfig(.weight)
    }
}

struct WorkoutsWidget: Widget {
    var body: some WidgetConfiguration {
        sectionConfig(.workouts)
    }
}

struct FeelingsWidget: Widget {
    var body: some WidgetConfiguration {
        sectionConfig(.feelings)
    }
}

struct ChecklistWidget: Widget {
    var body: some WidgetConfiguration {
        sectionConfig(.checklist)
    }
}

struct SupplementsWidget: Widget {
    var body: some WidgetConfiguration {
        sectionConfig(.supplements)
    }
}

struct DailyStatusWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: WidgetKind.dailyStatus, provider: SectionTimelineProvider()) { entry in
            DailySummaryRoot(entry: entry)
        }
        .configurationDisplayName(WidgetSection.dailyStatus.title)
        .description(WidgetSection.dailyStatus.galleryDescription)
        .supportedFamilies(WidgetFamilies.all)
    }
}

private func sectionConfig(_ section: WidgetSection) -> some WidgetConfiguration {
    StaticConfiguration(kind: section.kind, provider: SectionTimelineProvider()) { entry in
        SectionWidgetRoot(section: section, entry: entry)
    }
    .configurationDisplayName(section.title)
    .description(section.galleryDescription)
    .supportedFamilies(WidgetFamilies.all)
}
