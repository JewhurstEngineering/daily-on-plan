import Foundation
import SwiftData

/// Copies the existing App Group journal into the CloudKit store once, so iPhone
/// data actually uploads. Mac must not do this — its local store is empty.
enum CloudKitLegacyImport {
    @MainActor
    static func runIfNeeded() {
        guard SharedModelContainer.usesCloudKit else { return }
        guard let cloud = try? SharedModelContainer.shared() else { return }
        let cloudContext = ModelContext(cloud)
        let alreadyThere = (try? cloudContext.fetch(FetchDescriptor<DailyLog>())) ?? []
        if !alreadyThere.isEmpty { return }

        let legacyURL = AppGroupStore.storeURL
        guard FileManager.default.fileExists(atPath: legacyURL.path) else { return }

        guard let local = try? AppGroupStore.makeContainer(cloudKit: .none) else { return }

        let localContext = ModelContext(local)
        guard let snapshot = try? BackupService.snapshot(from: localContext) else { return }
        guard snapshot.settings != nil else { return }
        try? BackupService.replaceAll(with: snapshot, in: cloudContext)
    }
}
