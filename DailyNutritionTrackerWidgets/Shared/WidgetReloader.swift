import Foundation
import WidgetKit

enum WidgetKind {
    static let hydration = "com.dailyonplan.widget.hydration"
    static let protein = "com.dailyonplan.widget.protein"
    static let smoking = "com.dailyonplan.widget.smoking"
    static let drinking = "com.dailyonplan.widget.drinking"
    static let bathroom = "com.dailyonplan.widget.bathroom"
    static let weight = "com.dailyonplan.widget.weight"
    static let workouts = "com.dailyonplan.widget.workouts"
    static let feelings = "com.dailyonplan.widget.feelings"
    static let checklist = "com.dailyonplan.widget.checklist"
    static let supplements = "com.dailyonplan.widget.supplements"
    static let dailyStatus = "com.dailyonplan.widget.dailyStatus"

    static let all: [String] = [
        hydration, protein, smoking, drinking, bathroom,
        weight, workouts, feelings, checklist, supplements, dailyStatus
    ]
}

enum WidgetFamilies {
    static let all: [WidgetFamily] = [
        .accessoryCircular,
        .accessoryRectangular,
        .accessoryInline,
        .systemSmall,
        .systemMedium,
        .systemLarge,
        .systemExtraLarge
    ]
}

enum WidgetReloader {
    static func reloadAll() {
        let center = WidgetCenter.shared
        for kind in WidgetKind.all {
            center.reloadTimelines(ofKind: kind)
        }
        center.reloadAllTimelines()
    }
}

enum WidgetSection: String, CaseIterable, Identifiable {
    case hydration
    case protein
    case smoking
    case drinking
    case bathroom
    case weight
    case workouts
    case feelings
    case checklist
    case supplements
    case dailyStatus

    var id: String { rawValue }

    var daySection: DaySectionID {
        switch self {
        case .hydration: return .hydration
        case .protein: return .protein
        case .smoking: return .smoking
        case .drinking: return .drinking
        case .bathroom: return .bathroom
        case .weight: return .weight
        case .workouts: return .workouts
        case .feelings: return .feelings
        case .checklist: return .checklist
        case .supplements: return .supplements
        case .dailyStatus: return .dailyStatus
        }
    }

    var title: String {
        switch self {
        case .hydration: return "Hydration"
        case .protein: return "Protein"
        case .smoking: return "Smoking"
        case .drinking: return "Drinking"
        case .bathroom: return "Bathroom"
        case .weight: return "Weight"
        case .workouts: return "Workouts"
        case .feelings: return "Feelings"
        case .checklist: return "Fats & Veggies"
        case .supplements: return "Supplements"
        case .dailyStatus: return "Daily Summary"
        }
    }

    var symbolName: String {
        switch self {
        case .hydration: return "drop.fill"
        case .protein: return "fork.knife"
        case .smoking: return "flame.fill"
        case .drinking: return "wineglass.fill"
        case .bathroom: return "toilet.fill"
        case .weight: return "scalemass.fill"
        case .workouts: return "figure.run"
        case .feelings: return "heart.fill"
        case .checklist: return "leaf.fill"
        case .supplements: return "pills.fill"
        case .dailyStatus: return "calendar"
        }
    }

    var kind: String {
        switch self {
        case .hydration: return WidgetKind.hydration
        case .protein: return WidgetKind.protein
        case .smoking: return WidgetKind.smoking
        case .drinking: return WidgetKind.drinking
        case .bathroom: return WidgetKind.bathroom
        case .weight: return WidgetKind.weight
        case .workouts: return WidgetKind.workouts
        case .feelings: return WidgetKind.feelings
        case .checklist: return WidgetKind.checklist
        case .supplements: return WidgetKind.supplements
        case .dailyStatus: return WidgetKind.dailyStatus
        }
    }

    var galleryDescription: String {
        switch self {
        case .hydration: return "Water progress and one-tap bottle logging."
        case .protein: return "Protein calories vs goal. Tap to open logging."
        case .smoking: return "Today’s cigarette count and quick log."
        case .drinking: return "Today’s drinks and quick log."
        case .bathroom: return "Urine and stool counts with quick-add buttons."
        case .weight: return "Today’s weight and BMI at a glance."
        case .workouts: return "Workout minutes today. Tap to add."
        case .feelings: return "Feelings logged today. Tap to add."
        case .checklist: return "Veggies, fats, fruit, and misc counts."
        case .supplements: return "Dose progress and mark the next dose."
        case .dailyStatus: return "Today at a glance — plan, ketosis, protein & water rings, plus quick water log."
        }
    }
}
