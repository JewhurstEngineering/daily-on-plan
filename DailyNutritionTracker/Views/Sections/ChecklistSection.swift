import SwiftUI
import SwiftData

struct ChecklistSection: View {
    @Bindable var log: DailyLog
    let settings: AppSettings
    @Environment(\.modelContext) private var modelContext
    @State private var pickerCategory: FoodCategory?

    var body: some View {
        SectionCard(title: "Fats, Veggies & More", systemImage: "leaf") {
            checklistGroup(
                title: "Vegetables",
                items: log.checkedFatsAndVeggies.filter { name in
                    FoodCatalog.vegetables.contains(where: { $0.name == name })
                },
                category: .vegetable
            )

            if settings.phase.allowsFatsAndFruits {
                checklistGroup(title: "Fats", items: log.checkedFatsAndVeggies.filter { name in
                    FoodCatalog.fats.contains(where: { $0.name == name })
                }, category: .fat)
                checklistGroup(title: "Fruits", items: log.checkedFruits, category: .fruit)
            } else {
                Text("Fats & fruits unlock in Week 2+. Change phase in Settings.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Miscellaneous")
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Text("\(log.checkedMiscItems.count)/4")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(log.checkedMiscItems.count > 4 ? .orange : .secondary)
                }
                ForEach(log.checkedMiscItems, id: \.self) { item in
                    toggleRow(item, isOn: true) {
                        log.checkedMiscItems.removeAll { $0 == item }
                        try? modelContext.save()
                    }
                }
                Button("Add misc item") { pickerCategory = .misc }
                    .disabled(log.checkedMiscItems.count >= 4)
            }
        }
        .sheet(item: $pickerCategory) { category in
            FoodChecklistPicker(
                category: category,
                phase: settings.phase,
                selected: binding(for: category)
            )
        }
    }

    @ViewBuilder
    private func checklistGroup(title: String, items: [String], category: FoodCategory) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Button("Add") { pickerCategory = category }
                    .font(.caption)
            }
            if items.isEmpty {
                Text("None logged")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(items, id: \.self) { item in
                    toggleRow(item, isOn: true) {
                        remove(item, category: category)
                    }
                }
            }
        }
    }

    private func toggleRow(_ title: String, isOn: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Image(systemName: isOn ? "checkmark.square.fill" : "square")
                    .foregroundStyle(Color.accentColor)
                Text(title)
                    .foregroundStyle(.primary)
                Spacer()
            }
        }
        .buttonStyle(.plain)
    }

    private func binding(for category: FoodCategory) -> Binding<[String]> {
        switch category {
        case .fruit:
            return Binding(
                get: { log.checkedFruits },
                set: {
                    log.checkedFruits = $0
                    try? modelContext.save()
                }
            )
        case .misc:
            return Binding(
                get: { log.checkedMiscItems },
                set: {
                    log.checkedMiscItems = Array($0.prefix(4))
                    try? modelContext.save()
                }
            )
        case .fat, .vegetable:
            return Binding(
                get: { log.checkedFatsAndVeggies },
                set: {
                    log.checkedFatsAndVeggies = $0
                    try? modelContext.save()
                }
            )
        case .protein:
            return .constant([])
        }
    }

    private func remove(_ item: String, category: FoodCategory) {
        switch category {
        case .fruit:
            log.checkedFruits.removeAll { $0 == item }
        case .misc:
            log.checkedMiscItems.removeAll { $0 == item }
        default:
            log.checkedFatsAndVeggies.removeAll { $0 == item }
        }
        try? modelContext.save()
    }
}

struct FoodChecklistPicker: View {
    let category: FoodCategory
    let phase: ProgramPhase
    @Binding var selected: [String]
    @Environment(\.dismiss) private var dismiss
    @State private var search = ""

    private var foods: [CatalogFood] {
        FoodCatalog.foods(category: category, phase: phase, search: search)
    }

    var body: some View {
        NavigationStack {
            List(foods) { food in
                Button {
                    if selected.contains(food.name) {
                        selected.removeAll { $0 == food.name }
                    } else if category != .misc || selected.count < 4 {
                        selected.append(food.name)
                    }
                } label: {
                    HStack {
                        VStack(alignment: .leading) {
                            Text(food.name)
                            Text(food.servingLabel)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if selected.contains(food.name) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(Color.accentColor)
                        }
                    }
                }
            }
            .searchable(text: $search)
            .navigationTitle(category.title)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
