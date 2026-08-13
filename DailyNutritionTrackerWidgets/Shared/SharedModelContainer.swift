import Foundation
import SwiftData
import OnPlanCore
import os.log

enum SharedModelContainer {
    private static var cached: ModelContainer?
    private static let log = Logger(subsystem: "com.dailyonplan", category: "CloudKit")

    private(set) static var usesCloudKit = false
    private(set) static var cloudKitError: String?

    @MainActor
    static func shared() throws -> ModelContainer {
        if let cached { return cached }

        let container: ModelContainer
        #if WIDGET_EXTENSION
        container = try AppGroupStore.makeContainer(cloudKitEnabled: false)
        usesCloudKit = false
        #else
        do {
            container = try AppGroupStore.makeContainer(cloudKitEnabled: true)
            usesCloudKit = true
            cloudKitError = nil
            log.info("Opened journal with CloudKit \(AppGroupIDs.cloudKitContainer, privacy: .public)")
        } catch {
            cloudKitError = error.localizedDescription
            usesCloudKit = false
            log.error("CloudKit journal failed: \(error.localizedDescription, privacy: .public)")
            container = try AppGroupStore.makeContainer(cloudKitEnabled: false)
        }
        #endif
        cached = container
        return container
    }
}
