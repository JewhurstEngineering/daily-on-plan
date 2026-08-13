import SwiftUI
import OnPlanCore

struct MenuBarLabelView: View {
    @EnvironmentObject private var store: OnPlanStore

    var body: some View {
        let title = MenuBarFormatter.title(
            snapshot: store.snapshot,
            preferences: store.preferences
        )
        // A single Text (not an HStack of metrics) so MenuBarExtra doesn't clip to "…".
        HStack(spacing: 4) {
            Image(systemName: "checkmark.seal.fill")
            if store.preferences.showInMenuBar {
                Text(title)
            }
        }
        .fixedSize()
        .help(title)
        .accessibilityLabel(title)
    }
}
