import Foundation
import SwiftData

enum AppGroupStore {
    static let identifier = "group.com.dailyonplan.tracker"
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

    static var schema: Schema {
        Schema([
            DailyLog.self,
            FeelingEntry.self,
            ProteinEntry.self,
            WorkoutEntry.self,
            WeightEntry.self,
            BodyMeasurementEntry.self,
            BodyCompositionReading.self,
            CustomFoodPreset.self,
            SavedMeal.self,
            AppSettings.self
        ])
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

    static func makeConfiguration() -> ModelConfiguration {
        migrateLegacyStoreIfNeeded()
        return ModelConfiguration(
            schema: schema,
            url: storeURL,
            cloudKitDatabase: .none
        )
    }
}
