import SwiftUI
import SwiftData
import OnPlanCore

struct MacJournalSettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var allSettings: [AppSettings]
    @State private var editor: ProgramEditor?

    var body: some View {
        Group {
            if let settings = allSettings.first {
                content(settings)
            } else {
                ProgressView("Waiting for journal…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .onAppear { _ = DataStore.settings(in: modelContext) }
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .sheet(item: $editor) { item in
            if let settings = allSettings.first {
                NavigationStack {
                    editorView(item, settings: settings)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Done") { editor = nil }
                            }
                        }
                }
                .frame(minWidth: 540, idealWidth: 620, minHeight: 440, idealHeight: 560)
            }
        }
    }

    private func content(_ settings: AppSettings) -> some View {
        MacSettingsScroll {
            SettingsPanel(
                title: "Journal extras",
                systemImage: "square.grid.2x2",
                subtitle: "Lists and catalogs. Opens a panel — they still sync with iPhone."
            ) {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 200), spacing: 10)], spacing: 10) {
                    ForEach(ProgramEditor.allCases) { item in
                        Button {
                            editor = item
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Label(item.title, systemImage: item.systemImage)
                                    .appFont(.subheadline, weight: .semibold)
                                Text(item.blurb)
                                    .appFont(.caption2)
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .padding(10)
                            .frame(maxWidth: .infinity, minHeight: 68, alignment: .topLeading)
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(Color(nsColor: .windowBackgroundColor))
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func editorView(_ item: ProgramEditor, settings: AppSettings) -> some View {
        switch item {
        case .bodyComp: BodyCompositionListView(showsDismissButton: false)
        case .measurements: BodyMeasurementsListView(showsDismissButton: false)
        case .quotes: MotivationQuotesSettingsView(settings: settings)
        case .dayLayout: DayLayoutSettingsView(settings: settings)
        case .meals: SavedMealsListView(settings: settings)
        case .foodPrefs: FoodPreferencesView(settings: settings)
        case .foodLookup: FoodLookupSettingsView(settings: settings)
        case .supplements: SupplementsSettingsForm(settings: settings)
        case .presets: MacFoodPresetsEditor()
        }
    }
}

private enum ProgramEditor: String, Identifiable, CaseIterable {
    case bodyComp
    case measurements
    case supplements
    case meals
    case presets
    case foodPrefs
    case foodLookup
    case dayLayout
    case quotes

    var id: String { rawValue }

    var title: String {
        switch self {
        case .bodyComp: return "Body composition"
        case .measurements: return "Tape measurements"
        case .supplements: return "Supplements"
        case .meals: return "Saved meals"
        case .presets: return "Food presets"
        case .foodPrefs: return "Food preferences"
        case .foodLookup: return "Food lookup"
        case .dayLayout: return "iPhone day layout"
        case .quotes: return "Quotes"
        }
    }

    var blurb: String {
        switch self {
        case .bodyComp: return "Body composition readings and history."
        case .measurements: return "Waist, hips, and the rest of the tape."
        case .supplements: return "Names, doses, and reminder times."
        case .meals: return "Reuse a plate instead of rebuilding it."
        case .presets: return "Foods you save while logging protein."
        case .foodPrefs: return "Foods to avoid or keep off Suggest."
        case .foodLookup: return "Open Food Facts plus optional USDA key."
        case .dayLayout: return "Section order on the iPhone day sheet."
        case .quotes: return "The stay-on-plan reminder list."
        }
    }

    var systemImage: String {
        switch self {
        case .bodyComp: return "list.clipboard"
        case .measurements: return "ruler"
        case .supplements: return "pills.fill"
        case .meals: return "fork.knife"
        case .presets: return "star"
        case .foodPrefs: return "heart.slash"
        case .foodLookup: return "barcode.viewfinder"
        case .dayLayout: return "list.bullet.rectangle"
        case .quotes: return "quote.bubble"
        }
    }
}

private struct MacFoodPresetsEditor: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \CustomFoodPreset.name) private var presets: [CustomFoodPreset]

    var body: some View {
        List {
            if presets.isEmpty {
                Text("Save foods as presets when adding protein.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(presets) { preset in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(preset.name)
                            Text("\(preset.servingLabel) · \(preset.calories) kcal")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button(role: .destructive) {
                            modelContext.delete(preset)
                            modelContext.saveAndNotifyJournal()
                        } label: {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(.borderless)
                    }
                }
            }
        }
        .navigationTitle("Food presets")
    }
}
