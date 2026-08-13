import Foundation
#if !WIDGET_EXTENSION
import CoreData

enum CloudKitJournal {
    /// SwiftData+CloudKit imports land as persistent-store remote changes.
    @discardableResult
    static func observeRemoteChanges(_ handler: @escaping @MainActor () -> Void) -> NSObjectProtocol {
        NotificationCenter.default.addObserver(
            forName: .NSPersistentStoreRemoteChange,
            object: nil,
            queue: .main
        ) { _ in
            Task { @MainActor in
                handler()
            }
        }
    }
}
#endif
