import WidgetKit
import SwiftUI

struct SectionWidgetEntry: TimelineEntry {
    let date: Date
    let snapshot: DaySnapshot
}

struct SectionTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> SectionWidgetEntry {
        SectionWidgetEntry(date: Date(), snapshot: .preview)
    }

    func getSnapshot(in context: Context, completion: @escaping (SectionWidgetEntry) -> Void) {
        completion(SectionWidgetEntry(date: Date(), snapshot: WidgetSnapshotAccess.read()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SectionWidgetEntry>) -> Void) {
        let entry = SectionWidgetEntry(date: Date(), snapshot: WidgetSnapshotAccess.read())
        let midnight = Calendar.current.startOfDay(for: Date()).addingTimeInterval(86_400)
        completion(Timeline(entries: [entry], policy: .after(midnight)))
    }
}

extension DaySnapshot {
    static let preview = DaySnapshot(
        proteinCalories: 320,
        proteinGoal: 500,
        proteinEntryCount: 3,
        waterOz: 34,
        waterTargetOz: 64,
        bottleOz: 16.9,
        electrolyteCount: 1,
        cigarettes: 2,
        cigaretteLimit: 20,
        smokingEnabled: true,
        smokingModeRaw: SmokingMode.count.rawValue,
        drinks: 1,
        drinkLimit: 2,
        drinkingEnabled: true,
        drinkingModeRaw: DrinkingMode.count.rawValue,
        urineCount: 4,
        stoolCount: 1,
        bathroomEnabled: true,
        weightLbs: 182.4,
        priorWeightLbs: 183.1,
        heightInches: 70,
        goalWeightLbs: 170,
        workoutCount: 1,
        workoutMinutes: 35,
        lastWorkoutName: "Walk",
        feelingCount: 2,
        lastFeelingName: "Hungry",
        vegCount: 0,
        fatCount: 0,
        fruitCount: 1,
        miscCount: 1,
        fatsAndVeggiesCount: 5,
        supplementsEnabled: true,
        supplementDosesCompleted: 5,
        supplementDosesTotal: 12,
        supplements: [
            SupplementDoseSnapshot(id: "prescription", name: "Prescription", completed: 2, dosesPerDay: 3),
            SupplementDoseSnapshot(id: "calcium", name: "Calcium", completed: 1, dosesPerDay: 2)
        ],
        followedPlan: true,
        ketosis: true,
        hasLog: true
    )
}

struct SectionWidgetRoot: View {
    @Environment(\.widgetFamily) private var family
    let section: WidgetSection
    let entry: SectionWidgetEntry

    var body: some View {
        Group {
            switch family {
            case .accessoryCircular:
                SectionCircularView(section: section, snapshot: entry.snapshot)
            case .accessoryRectangular:
                SectionRectangularView(section: section, snapshot: entry.snapshot)
            case .accessoryInline:
                Text(inlineText)
            case .systemSmall:
                SectionSmallView(section: section, snapshot: entry.snapshot)
            case .systemMedium:
                SectionMediumView(section: section, snapshot: entry.snapshot)
            case .systemLarge, .systemExtraLarge:
                SectionLargeView(section: section, snapshot: entry.snapshot)
            default:
                SectionSmallView(section: section, snapshot: entry.snapshot)
            }
        }
        .containerBackground(for: .widget) { Color.clear }
        .widgetURL(AppDeepLink.sectionURL(section.daySection))
    }

    private var inlineText: String {
        let s = entry.snapshot
        switch section {
        case .hydration: return "💧 \(s.waterOz)/\(s.waterTargetOz) oz"
        case .protein: return "🥩 \(s.proteinCalories)/\(s.proteinGoal) kcal"
        case .smoking: return s.smokingEnabled ? "🚬 \(s.cigarettes)" : "Smoking off"
        case .drinking: return s.drinkingEnabled ? "🍷 \(s.drinks)" : "Drinking off"
        case .bathroom: return "🚽 U\(s.urineCount) · S\(s.stoolCount)"
        case .weight:
            if let w = s.weightLbs { return String(format: "⚖️ %.1f lb", w) }
            return "⚖️ No weigh-in"
        case .workouts: return "🏃 \(s.workoutMinutes) min · \(s.workoutCount)"
        case .feelings: return "❤️ \(s.feelingCount) feelings"
        case .checklist: return "🥬 \(s.checklistTotal) items"
        case .supplements: return "💊 \(s.supplementDosesCompleted)/\(s.supplementDosesTotal)"
        case .dailyStatus:
            return "Plan \(s.followedPlan ? "✅" : "❌") · Keto \(s.ketosis ? "✅" : "❌")"
        }
    }
}
