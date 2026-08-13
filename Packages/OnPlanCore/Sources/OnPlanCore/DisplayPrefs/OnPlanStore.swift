import Foundation
import Combine

@MainActor
public final class OnPlanStore: ObservableObject {
    @Published public var preferences: DisplayPreferences
    @Published public var snapshot: ChromeSnapshot
    public var onSnapshotWritten: (() -> Void)?

    public init(
        preferences: DisplayPreferences = DisplayPreferenceStore.load(),
        snapshot: ChromeSnapshot = ChromeSnapshotStore.read() ?? .empty
    ) {
        self.preferences = preferences
        self.snapshot = snapshot
    }

    public func updatePreferences(_ body: (inout DisplayPreferences) -> Void) {
        body(&preferences)
        DisplayPreferenceStore.save(preferences)
    }

    public func applyPreferences(_ prefs: DisplayPreferences) {
        preferences = prefs
        DisplayPreferenceStore.save(prefs)
    }

    public func setSnapshot(_ snapshot: ChromeSnapshot) {
        self.snapshot = snapshot
        try? ChromeSnapshotStore.write(snapshot)
        onSnapshotWritten?()
    }
}
