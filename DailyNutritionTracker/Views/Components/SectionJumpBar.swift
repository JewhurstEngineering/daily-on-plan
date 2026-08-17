import SwiftUI

/// A pinned-under-the-header row of chips, one per enabled section, that scrolls the day sheet to
/// that section on tap — for once someone has most sections turned on and the page runs long.
/// Doesn't change the single continuous "one page" layout, just makes it faster to navigate.
/// See docs/DESIGN_IMPROVEMENT_PLAN.md §5.6.
struct SectionJumpBar: View {
    let sections: [DaySectionID]
    let onSelect: (DaySectionID) -> Void

    var body: some View {
        if sections.count > 1 {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Spacing.s) {
                    ForEach(sections) { section in
                        Button {
                            onSelect(section)
                        } label: {
                            Label(section.settingsTitle, systemImage: section.systemImage)
                                .labelStyle(.titleAndIcon)
                                .font(.caption.weight(.semibold))
                        }
                        .chipStyle(shape: .capsule)
                        .buttonStyle(.plain)
                    }
                }
            }
            .accessibilityLabel("Jump to section")
        }
    }
}
