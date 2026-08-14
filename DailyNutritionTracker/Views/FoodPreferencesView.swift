import SwiftUI
import SwiftData

struct FoodPreferencesView: View {
    @Bindable var settings: AppSettings
    @Environment(\.modelContext) private var modelContext
    @State private var search = ""

    var body: some View {
        List {
            Section {
                Text("Excluded foods never appear in pickers or meal suggestions (allergies and hard nos). Preferred foods are prioritized for suggestions and for picky eaters.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("Excluded") {
                if settings.excludedFoodNames.isEmpty {
                    Text("None yet")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(settings.excludedFoodNames.sorted(), id: \.self) { name in
                        Text(name)
                    }
                    .onDelete { offsets in
                        var list = settings.excludedFoodNames.sorted()
                        list.remove(atOffsets: offsets)
                        settings.excludedFoodNames = list
                        save()
                    }
                }
            }

            Section("Preferred") {
                if settings.preferredFoodNames.isEmpty {
                    Text("None yet — suggestions use the full allowed catalog.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(settings.preferredFoodNames.sorted(), id: \.self) { name in
                        Text(name)
                    }
                    .onDelete { offsets in
                        var list = settings.preferredFoodNames.sorted()
                        list.remove(atOffsets: offsets)
                        settings.preferredFoodNames = list
                        save()
                    }
                }
            }

            Section("Add from library") {
                TextField("Search foods", text: $search)
                ForEach(filteredFoods, id: \.id) { food in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(food.name)
                            Text("\(food.category.title) · \(food.servingLabel)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Menu {
                            Button("Exclude") { addExclude(food.name) }
                            Button("Prefer") { addPrefer(food.name) }
                        } label: {
                            Image(systemName: "plus.circle")
                        }
                    }
                }
            }
        }
        .navigationTitle("Food preferences")
        .onPlanInlineNav()
    }

    private var filteredFoods: [CatalogFood] {
        FoodCatalog.foods(phase: settings.phase, search: search)
            .filter { !settings.isExcluded($0.name) || search.isEmpty }
            .prefix(40)
            .map { $0 }
    }

    private func addExclude(_ name: String) {
        var list = settings.excludedFoodNames
        if !list.contains(where: { $0.caseInsensitiveCompare(name) == .orderedSame }) {
            list.append(name)
        }
        settings.excludedFoodNames = list
        settings.preferredFoodNames = settings.preferredFoodNames.filter {
            $0.caseInsensitiveCompare(name) != .orderedSame
        }
        save()
    }

    private func addPrefer(_ name: String) {
        guard !settings.isExcluded(name) else { return }
        var list = settings.preferredFoodNames
        if !list.contains(where: { $0.caseInsensitiveCompare(name) == .orderedSame }) {
            list.append(name)
        }
        settings.preferredFoodNames = list
        save()
    }

    private func save() {
        modelContext.saveAndNotifyJournal()
    }
}
