import SwiftUI
import SwiftData

struct ProteinSection: View {
    @Bindable var log: DailyLog
    let settings: AppSettings
    var scrollAnchor: String = "protein"
    var onWillPresentSheet: ((String) -> Void)? = nil

    @Environment(\.modelContext) private var modelContext
    @State private var showAdd = false
    @State private var showMeals = false
    @State private var editingEntry: ProteinEntry?
    @State private var editMultiplier: Double = 1
    @State private var suggestionChips: [SuggestionItem] = []
    @Query(sort: \CustomFoodPreset.name) private var presets: [CustomFoodPreset]
    @Query(sort: \SavedMeal.name) private var savedMeals: [SavedMeal]

    var body: some View {
        SectionCard(title: "Protein Log", systemImage: "fork.knife.circle") {
            if !suggestionChips.isEmpty {
                Text(hasHistory ? "Popular & recent" : "Suggestions")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                SuggestionChipRow(items: suggestionChips) { item in
                    addSuggestion(item)
                }
            }

            if !presets.isEmpty {
                Text("My presets")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(presets, id: \.id) { preset in
                            Button(preset.name) { addPreset(preset) }
                                .buttonStyle(.bordered)
                        }
                    }
                }
            }

            if !savedMeals.isEmpty {
                Text("Saved meals")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(savedMeals, id: \.id) { meal in
                            Button(meal.name) {
                                MealLogger.apply(components: meal.components, to: log, settings: settings)
                                try? modelContext.save()
                                refreshChips()
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }
            }

            HStack(spacing: 10) {
                Button {
                    onWillPresentSheet?(scrollAnchor)
                    showAdd = true
                } label: {
                    Label("Add protein", systemImage: "plus.circle.fill")
                }
                .buttonStyle(.borderedProminent)

                Button {
                    onWillPresentSheet?(scrollAnchor)
                    showMeals = true
                } label: {
                    Label("Meals", systemImage: "square.stack.3d.up")
                }
                .buttonStyle(.bordered)
            }

            if log.sortedProteins.isEmpty {
                Text("Log meals with a multiplier (1×, 3×, 6×…) and hunger before/after. Or use Saved meals / Suggest.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 0) {
                    ForEach(log.sortedProteins, id: \.id) { entry in
                        HStack(alignment: .top) {
                            Button {
                                onWillPresentSheet?(scrollAnchor)
                                editingEntry = entry
                                editMultiplier = max(entry.servings, 1)
                            } label: {
                                HStack(alignment: .top) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(entry.name)
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(.primary)
                                        Text("\(DateHelpers.formattedTime(entry.time)) · \(entry.servingSize) · hunger \(entry.hungerBefore)→\(entry.hungerAfter)")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        Text("Tap to edit amount")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer(minLength: 8)
                                    Text("\(entry.calories) kcal")
                                        .font(.subheadline.monospacedDigit())
                                        .foregroundStyle(.primary)
                                }
                            }
                            .buttonStyle(.plain)

                            Button(role: .destructive) {
                                delete(entry)
                            } label: {
                                Image(systemName: "trash")
                                    .font(.body)
                                    .foregroundStyle(.red)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Delete \(entry.name)")
                        }
                        .padding(.vertical, 6)
                        Divider()
                    }
                }
            }
        }
        .sheet(isPresented: $showAdd, onDismiss: { onWillPresentSheet?(scrollAnchor) }) {
            AddProteinSheet(log: log, settings: settings) {
                refreshChips()
            }
        }
        .sheet(isPresented: $showMeals, onDismiss: { onWillPresentSheet?(scrollAnchor) }) {
            NavigationStack {
                SavedMealsListView(settings: settings, log: log)
            }
        }
        .sheet(item: $editingEntry, onDismiss: { onWillPresentSheet?(scrollAnchor) }) { entry in
            NavigationStack {
                Form {
                    Section("\(entry.name)") {
                        Text("Unit: \(unitCalories(for: entry)) kcal per serving")
                        MultiplierPicker(multiplier: $editMultiplier)
                        Stepper(
                            value: $editMultiplier,
                            in: 0.5...20,
                            step: 0.5
                        ) {
                            Text(String(format: "Amount: %.1f×", editMultiplier))
                        }
                        Text("New total: \(Int((Double(unitCalories(for: entry)) * editMultiplier).rounded())) kcal")
                            .font(.headline.monospacedDigit())
                    }
                }
                .navigationTitle("Update amount")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { editingEntry = nil }
                    }
                    ToolbarItem(placement: .destructiveAction) {
                        Button("Delete", role: .destructive) {
                            delete(entry)
                            editingEntry = nil
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            applyMultiplier(to: entry, multiplier: editMultiplier)
                            editingEntry = nil
                            refreshChips()
                        }
                    }
                }
            }
            .presentationDetents([.medium])
        }
        .onAppear { refreshChips() }
    }

    private var hasHistory: Bool {
        !((try? modelContext.fetch(FetchDescriptor<DailyLog>())) ?? []).flatMap(\.proteinEntries).isEmpty
    }

    private func refreshChips() {
        suggestionChips = UsageSuggestions.proteinChips(in: modelContext)
    }

    private func delete(_ entry: ProteinEntry) {
        log.proteinEntries.removeAll { $0.id == entry.id }
        modelContext.delete(entry)
        try? modelContext.save()
        refreshChips()
    }

    private func unitCalories(for entry: ProteinEntry) -> Int {
        if entry.servings > 0 {
            return max(1, Int((Double(entry.calories) / entry.servings).rounded()))
        }
        if let cat = ProteinCategory(rawValue: entry.proteinCategory), let per = cat.caloriesPerServing {
            return per
        }
        return entry.calories
    }

    private func applyMultiplier(to entry: ProteinEntry, multiplier: Double) {
        let unit = unitCalories(for: entry)
        entry.servings = multiplier
        entry.calories = Int((Double(unit) * multiplier).rounded())
        if abs(multiplier - 1) < 0.01 {
            if entry.servingSize.contains("×") {
                entry.servingSize = "1 serving"
            }
        } else {
            entry.servingSize = String(format: "%.1f× serving", multiplier)
        }
        try? modelContext.save()
    }

    private func addSuggestion(_ item: SuggestionItem) {
        let totalCalories = item.calories ?? 35
        let entry = ProteinEntry(
            name: item.name,
            servingSize: item.subtitle ?? "1 serving",
            calories: totalCalories,
            proteinCategory: item.proteinCategory ?? ProteinCategory.other.rawValue,
            servings: max(item.servings, 1)
        )
        modelContext.insert(entry)
        log.proteinEntries.append(entry)
        try? modelContext.save()
        refreshChips()
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
        refreshChips()
    }
}

extension ProteinEntry: @retroactive Identifiable {}
extension SavedMeal: @retroactive Identifiable {}
