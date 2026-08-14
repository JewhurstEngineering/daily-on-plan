import Foundation
import SwiftData
import OnPlanCore

enum AppGroupStore {
    static var identifier: String {
        #if os(macOS)
        AppGroupIDs.macOS
        #else
        AppGroupIDs.iOS
        #endif
    }
    static let storeFileName = "DailyOnPlan.store"

    /// Shared SwiftData store URL inside the App Group container.
    static var storeURL: URL {
        guard let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier) else {
            // Simulator / misconfigured signing fallback — keep data local to this process.
            let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? FileManager.default.temporaryDirectory
            try? FileManager.default.createDirectory(at: support, withIntermediateDirectories: true)
            return support.appendingPathComponent(storeFileName)
        }
        try? FileManager.default.createDirectory(at: container, withIntermediateDirectories: true)
        return container.appendingPathComponent(storeFileName)
    }

    enum CloudKitStyle {
        case none
        case automatic
        case appGroupPrivate

        var label: String {
            switch self {
            case .none: return "local"
            case .automatic: return "automatic"
            case .appGroupPrivate: return "app-group"
            }
        }
    }

    static var schema: Schema {
        Schema(versionedSchema: JournalSchemaV2.self)
    }

    /// Copies the legacy app-sandbox SwiftData store into the App Group once.
    static func migrateLegacyStoreIfNeeded() {
        let destination = storeURL
        let fm = FileManager.default
        guard !fm.fileExists(atPath: destination.path) else { return }

        let support = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        guard let support else { return }

        // Default SwiftData file when ModelConfiguration has no custom URL.
        let candidates = [
            support.appendingPathComponent("default.store"),
            support.appendingPathComponent("DailyNutritionTracker.store"),
            support.appendingPathComponent("Model.store")
        ]

        guard let source = candidates.first(where: { fm.fileExists(atPath: $0.path) }) else { return }

        for ext in ["", "-shm", "-wal"] {
            let from = URL(fileURLWithPath: source.path + ext)
            let to = URL(fileURLWithPath: destination.path + ext)
            guard fm.fileExists(atPath: from.path) else { continue }
            try? fm.copyItem(at: from, to: to)
        }
    }

    static func makeConfiguration(cloudKitEnabled: Bool) -> ModelConfiguration {
        makeConfiguration(cloudKit: cloudKitEnabled ? .appGroupPrivate : .none)
    }

    static func makeConfiguration(cloudKit: CloudKitStyle) -> ModelConfiguration {
        if cloudKit == .none {
            migrateLegacyStoreIfNeeded()
        }
        switch cloudKit {
        case .automatic:
            return ModelConfiguration(
                "OnPlanJournal",
                schema: schema,
                cloudKitDatabase: .automatic
            )
        case .appGroupPrivate:
            return ModelConfiguration(
                "OnPlanJournal",
                schema: schema,
                groupContainer: .identifier(identifier),
                cloudKitDatabase: .private(AppGroupIDs.cloudKitContainer)
            )
        case .none:
            return ModelConfiguration(
                schema: schema,
                url: storeURL,
                cloudKitDatabase: .none
            )
        }
    }

    static func makeContainer(cloudKitEnabled: Bool = false) throws -> ModelContainer {
        try makeContainer(cloudKit: cloudKitEnabled ? .appGroupPrivate : .none)
    }

    static func makeContainer(cloudKit: CloudKitStyle) throws -> ModelContainer {
        let config = makeConfiguration(cloudKit: cloudKit)
        return try ModelContainer(
            for: schema,
            migrationPlan: JournalMigrationPlan.self,
            configurations: config
        )
    }
}
