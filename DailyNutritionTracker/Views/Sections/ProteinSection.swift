import SwiftUI
import SwiftData

struct ProteinSection: View {
    @Bindable var log: DailyLog
    let settings: AppSettings
    @Environment(\.modelContext) private var modelContext
    @State private var showAdd = false
    @Query(sort: \CustomFoodPreset.name) private var presets: [CustomFoodPreset]

    var body: some View {
        SectionCard(title: "Protein Log", systemImage: "fork.knife.circle") {
            if !presets.isEmpty || !FoodCatalog.quickProteinPresets.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(presets, id: \.id) { preset in
                            Button(preset.name) {
                                addPreset(preset)
                            }
                            .buttonStyle(.bordered)
                        }
                        ForEach(FoodCatalog.quickProteinPresets) { item in
                            Button(item.name) {
                                addCatalog(item)
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }
            }

            Button {
                showAdd = true
            } label: {
                Label("Add protein", systemImage: "plus.circle.fill")
            }
            .buttonStyle(.borderedProminent)

            if log.sortedProteins.isEmpty {
                Text("Log meals with servings and hunger before/after.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(log.sortedProteins, id: \.id) { entry in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(entry.name)
                                .font(.subheadline.weight(.semibold))
                            Spacer()
                            Text("\(entry.calories) kcal")
                                .font(.subheadline.monospacedDigit())
                        }
                        Text("\(DateHelpers.formattedTime(entry.time)) · \(entry.servingSize) · hunger \(entry.hungerBefore)→\(entry.hungerAfter)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .swipeActions {
                        Button(role: .destructive) {
                            log.proteinEntries.removeAll { $0.id == entry.id }
                            modelContext.delete(entry)
                            try? modelContext.save()
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                    Divider()
                }
            }
        }
        .sheet(isPresented: $showAdd) {
            AddProteinSheet(log: log, settings: settings)
        }
    }

    private func addPreset(_ preset: CustomFoodPreset) {
        let entry = ProteinEntry(
            name: preset.name,
            servingSize: preset.servingLabel,
            calories: preset.calories,
            proteinCategory: preset.proteinCategory,
            servings: preset.servingsPerUnit
        )
        modelContext.insert(entry)
        log.proteinEntries.append(entry)
        try? modelContext.save()
    }

    private func addCatalog(_ item: CatalogFood) {
        let calories: Int
        if let per = item.proteinCategory?.caloriesPerServing {
            calories = Int((Double(per) * item.servingsPerUnit).rounded())
        } else {
            calories = item.calories
        }
        let entry = ProteinEntry(
            name: item.name,
            servingSize: item.servingLabel,
            calories: calories,
            proteinCategory: item.proteinCategory?.rawValue ?? ProteinCategory.other.rawValue,
            servings: item.servingsPerUnit
        )
        modelContext.insert(entry)
        log.proteinEntries.append(entry)
        try? modelContext.save()
    }
}
