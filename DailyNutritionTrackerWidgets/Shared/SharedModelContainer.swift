import Foundation
import SwiftData

enum SharedModelContainer {
    private static var cached: ModelContainer?

    @MainActor
    static func shared() throws -> ModelContainer {
        if let cached { return cached }
        let config = AppGroupStore.makeConfiguration()
        let container = try ModelContainer(for: AppGroupStore.schema, configurations: [config])
        cached = container
        return container
    }
}
