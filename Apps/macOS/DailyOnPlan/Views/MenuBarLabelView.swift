import SwiftUI
import OnPlanCore

struct MenuBarLabelView: View {
    @EnvironmentObject private var store: OnPlanStore

    var body: some View {
        let segments = MenuBarFormatter.segments(
            snapshot: store.snapshot,
            preferences: store.preferences
        )
        let spoken = MenuBarFormatter.title(
            snapshot: store.snapshot,
            preferences: store.preferences
        )
        HStack(spacing: 3) {
            AppLogo(size: 16)
            if store.preferences.showInMenuBar {
                ForEach(Array(segments.enumerated()), id: \.offset) { index, segment in
                    if index > 0 {
                        Text("·")
                            .opacity(0.7)
                    }
                    HStack(spacing: 1) {
                        if let icon = segment.systemImage {
                            Image(systemName: icon)
                        }
                        if !segment.text.isEmpty {
                            Text(segment.text)
                        }
                    }
                }
            }
        }
        .fixedSize()
        .help(spoken)
        .accessibilityLabel(spoken)
    }
}
