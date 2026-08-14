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
        #if os(iOS)
        .environment(\.editMode, .constant(.active))
        #endif
        .navigationTitle("Day layout")
        .onPlanInlineNav()
        .onAppear {
            order = settings.sectionOrder
        }
    }

    private func isVisible(_ section: DaySectionID) -> Bool {
        switch section {
        case .fasting: return settings.fastingEnabled
        case .smoking: return settings.smokingMode.showsSection
        case .drinking: return settings.drinkingMode.showsSection
        case .supplements: return settings.showSupplementsSection
        case .bathroom: return settings.showBathroomSection
        default: return true
        }
    }

    private func move(from source: IndexSet, to destination: Int) {
        order.move(fromOffsets: source, toOffset: destination)
        persist()
    }

    private func persist() {
        settings.sectionOrder = order
        modelContext.saveAndNotifyJournal()
    }
}
