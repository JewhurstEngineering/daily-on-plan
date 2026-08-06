import WidgetKit
import SwiftUI

@main
struct DailyNutritionTrackerWidgetsBundle: WidgetBundle {
    var body: some Widget {
        DailyStatusWidget()
        HydrationWidget()
        ProteinWidget()
        SmokingWidget()
        DrinkingWidget()
        BathroomWidget()
        WeightWidget()
        WorkoutsWidget()
        FeelingsWidget()
        ChecklistWidget()
        SupplementsWidget()
    }
}
