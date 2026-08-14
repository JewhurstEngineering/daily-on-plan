import SwiftUI
import SwiftData

struct ChecklistSection: View {
    @Bindable var log: DailyLog
    let settings: AppSettings
    var scrollAnchor: String = "checklist"
    var onWillPresentSheet: ((String) -> Void)? = nil
    @Environment(\.modelContext) private var modelContext
    @State private var pickerCategory: FoodCategory?
    @State private var editingRaw: String?
    @State private var editingCategory: FoodCategory = .vegetable
    @State private var editingAmount = ""
    @State private var vegChips: [SuggestionItem] = []
    @State private var fatChips: [SuggestionItem] = []
    @State private var fruitChips: [SuggestionItem] = []
    @State private var miscChips: [SuggestionItem] = []

    var body: some View {
        SectionCard(
            title: "Fats, Veggies & More",
            systemImage: "leaf",
            isCollapsed: settings.sectionCollapsedBinding(.checklist, context: modelContext),
            collapsedMessage: DaySectionID.checklist.collapsedMessage
        ) {
            checklistGroup(
                title: "Vegetables",
                items: ChecklistStorage.vegetables(in: log),
                category: .vegetable,
                chips: vegChips
            )

            if settings.phase.allowsFatsAndFruits {
                checklistGroup(
                    title: "Fats",
                    items: ChecklistStorage.fats(in: log),
                    category: .fat,
                    chips: fatChips
                )
                checklistGroup(
                    title: "Fruits",
                    items: log.checkedFruits,
                    category: .fruit,
                    chips: fruitChips
                )
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
                    Text("\(log.checkedMiscItems.count)/\(AppLimits.miscDailyLimit)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(log.checkedMiscItems.count > AppLimits.miscDailyLimit ? .orange : .secondary)
                }
                if !miscChips.isEmpty {
                    SuggestionChipRow(items: miscChips) { item in
                        addChip(item, category: .misc)
                    }
                }
                ForEach(log.checkedMiscItems, id: \.self) { item in
                    loggedRow(item, category: .misc)
                }
                Button("Add misc item") {
                    onWillPresentSheet?(scrollAnchor)
                    pickerCategory = .misc
                }
                    .disabled(log.checkedMiscItems.count >= AppLimits.miscDailyLimit)
            }
        }
        .sheet(item: $pickerCategory, onDismiss: { onWillPresentSheet?(scrollAnchor) }) { category in
            FoodChecklistPicker(
                category: category,
                phase: settings.phase,
                excludedNames: settings.excludedFoodNames,
                onPick: { food in
                    addFood(food, category: category)
                }
            )
        }
        .alert("Edit amount", isPresented: Binding(
            get: { editingRaw != nil },
            set: { if !$0 { editingRaw = nil } }
        )) {
            TextField("Amount (e.g. 1/2 cup)", text: $editingAmount)
            Button("Save") {
                saveEditedAmount()
                onWillPresentSheet?(scrollAnchor)
            }
            Button("Cancel", role: .cancel) {
                editingRaw = nil
                onWillPresentSheet?(scrollAnchor)
            }
        }
        .onAppear {
            ChecklistStorage.migrateFatsSplit(on: log)
            refreshChips()
        }
    }

    @ViewBuilder
    private func checklistGroup(
        title: String,
        items: [String],
        category: FoodCategory,
        chips: [SuggestionItem]
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Button("Add") {
                    onWillPresentSheet?(scrollAnchor)
                    pickerCategory = category
                }
                    .font(.caption)
            }
            if !chips.isEmpty {
                SuggestionChipRow(items: chips) { item in
                    addChip(item, category: category)
                }
            }
            if items.isEmpty {
                Text("None logged")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(items, id: \.self) { item in
                    loggedRow(item, category: category)
                }
            }
        }
    }

    private func loggedRow(_ raw: String, category: FoodCategory) -> some View {
        HStack {
            Image(systemName: "checkmark.square.fill")
                .foregroundStyle(Color.accentColor)
            VStack(alignment: .leading, spacing: 2) {
                Text(ChecklistStorage.display(raw))
                    .foregroundStyle(.primary)
                Text("Tap to edit amount")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button(role: .destructive) {
                remove(raw, category: category)
            } label: {
                Image(systemName: "trash")
                    .font(.caption)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onWillPresentSheet?(scrollAnchor)
            editingCategory = category
            editingRaw = raw
            editingAmount = ChecklistStorage.parse(raw).amount
            if editingAmount.isEmpty {
                editingAmount = ChecklistStorage.defaultAmount(
                    for: ChecklistStorage.name(of: raw),
                    category: category
                )
            }
        }
    }

    private func refreshChips() {
        vegChips = UsageSuggestions.checklistChips(category: .vegetable, phase: settings.phase, in: modelContext)
        fatChips = UsageSuggestions.checklistChips(category: .fat, phase: settings.phase, in: modelContext)
        fruitChips = UsageSuggestions.checklistChips(category: .fruit, phase: settings.phase, in: modelContext)
        miscChips = UsageSuggestions.checklistChips(category: .misc, phase: settings.phase, in: modelContext)
    }

    private func addChip(_ item: SuggestionItem, category: FoodCategory) {
        let amount = item.amount ?? ChecklistStorage.defaultAmount(for: item.name, category: category)
        append(name: item.name, amount: amount, category: category)
    }

    private func addFood(_ food: CatalogFood, category: FoodCategory) {
        append(name: food.name, amount: food.servingLabel, category: category)
    }

    private func append(name: String, amount: String, category: FoodCategory) {
        let encoded = ChecklistStorage.encode(name: name, amount: amount)
        switch category {
        case .fruit:
            ChecklistStorage.appendUnique(encoded, to: &log.checkedFruits)
        case .misc:
            guard log.checkedMiscItems.count < AppLimits.miscDailyLimit else { return }
            ChecklistStorage.appendUnique(encoded, to: &log.checkedMiscItems)
        case .fat:
            ChecklistStorage.appendUnique(encoded, to: &log.checkedFats)
        default:
            ChecklistStorage.appendUnique(encoded, to: &log.checkedFatsAndVeggies)
        }
        try? modelContext.save()
        refreshChips()
    }

    private func remove(_ item: String, category: FoodCategory) {
        switch category {
        case .fruit:
            log.checkedFruits.removeAll { $0 == item }
        case .misc:
            log.checkedMiscItems.removeAll { $0 == item }
        case .fat:
            log.checkedFats.removeAll { $0 == item }
        default:
            log.checkedFatsAndVeggies.removeAll { $0 == item }
        }
        try? modelContext.save()
        refreshChips()
    }

    private func saveEditedAmount() {
        guard let editingRaw else { return }
        let name = ChecklistStorage.name(of: editingRaw)
        let encoded = ChecklistStorage.encode(name: name, amount: editingAmount)
        switch editingCategory {
        case .fruit:
            if let idx = log.checkedFruits.firstIndex(of: editingRaw) {
                log.checkedFruits[idx] = encoded
            }
        case .misc:
            if let idx = log.checkedMiscItems.firstIndex(of: editingRaw) {
                log.checkedMiscItems[idx] = encoded
            }
        case .fat:
            if let idx = log.checkedFats.firstIndex(of: editingRaw) {
                log.checkedFats[idx] = encoded
            }
        default:
            if let idx = log.checkedFatsAndVeggies.firstIndex(of: editingRaw) {
                log.checkedFatsAndVeggies[idx] = encoded
            }
        }
        try? modelContext.save()
        self.editingRaw = nil
        refreshChips()
    }
}
