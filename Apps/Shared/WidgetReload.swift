import WidgetKit

enum WidgetReload {
    static func afterWritingSnapshot() {
        WidgetCenter.shared.reloadTimelines(ofKind: "com.dailyonplan.widget.dailyStatus")
        WidgetCenter.shared.reloadTimelines(ofKind: "DailyOnPlanMacStatus")
        WidgetCenter.shared.reloadAllTimelines()
    }
}
