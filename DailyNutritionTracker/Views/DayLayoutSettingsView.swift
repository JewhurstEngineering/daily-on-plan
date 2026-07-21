import SwiftUI
import SwiftData

struct DayLayoutSettingsView: View {
    @Bindable var settings: AppSettings
    @Environment(\.modelContext) private var modelContext
    @State private var order: [DaySectionID] = []

    var body: some View {
        List {
            Section {
                Text("Daily status always stays at the top. Drag the rest into the order you want on the day sheet.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("Order") {
                ForEach(order, id: \.self) { section in
                    HStack {
                        Text(section.settingsTitle)
                        Spacer()
                        if !isVisible(section) {
                            Text("Hidden")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                        Image(systemName: "line.3.horizontal")
                            .foregroundStyle(.secondary)
                    }
                    .foregroundStyle(isVisible(section) ? .primary : .secondary)
                }
                .onMove(perform: move)
            }

            Section {
                Button("Reset to default order") {
                    order = DaySectionID.defaultReorderableOrder
                    persist()
                }
            }
        }
        .environment(\.editMode, .constant(.active))
        .navigationTitle("Day layout")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            order = settings.sectionOrder
        }
    }

    private func isVisible(_ section: DaySectionID) -> Bool {
        switch section {
        case .smoking: return settings.smokingMode.showsSection
        case .drinking: return settings.drinkingMode.showsSection
        case .supplements: return settings.showSupplementsSection
        default: return true
        }
    }

    private func move(from source: IndexSet, to destination: Int) {
        order.move(fromOffsets: source, toOffset: destination)
        persist()
    }

    private func persist() {
        settings.sectionOrder = order
        try? modelContext.save()
    }
}
