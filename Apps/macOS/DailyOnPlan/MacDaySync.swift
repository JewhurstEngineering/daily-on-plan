import SwiftData
import OnPlanCore

enum MacDaySync {
    @MainActor
    static func refresh(store: OnPlanStore, context: ModelContext? = nil) {
        let ctx: ModelContext
        if let context {
            ctx = context
        } else if let container = try? SharedModelContainer.shared() {
            ctx = ModelContext(container)
        } else {
            return
        }
        store.setSnapshot(DaySnapshotBuilder.build(in: ctx))
        WidgetReloader.reloadAll()
    }
}
