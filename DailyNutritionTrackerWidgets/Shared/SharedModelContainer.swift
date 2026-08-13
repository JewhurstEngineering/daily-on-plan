import Foundation
import SwiftData
import OnPlanCore

enum SharedModelContainer {
    private static var cached: ModelContainer?

    @MainActor
    static func shared() throws -> ModelContainer {
        if let cached { return cached }

        let container: ModelContainer
        #if WIDGET_EXTENSION
        container = try AppGroupStore.makeContainer(cloudKitDatabase: .none)
        #else
        do {
            container = try AppGroupStore.makeContainer(
                cloudKitDatabase: .private(AppGroupIDs.cloudKitContainer)
            )
        } catch {
            // SwiftData CloudKit requires optional relationships; current @Model
            // graphs may fail to open. Fall back to the same App Group file locally.
            container = try AppGroupStore.makeContainer(cloudKitDatabase: .none)
        }
        #endif
        cached = container
        return container
    }
}
