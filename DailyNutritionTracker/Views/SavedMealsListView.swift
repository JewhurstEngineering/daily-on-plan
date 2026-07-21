import SwiftUI
import SwiftData

struct SavedMealsListView: View {
    @Bindable var settings: AppSettings
    var log: DailyLog?
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \SavedMeal.name) private var meals: [SavedMeal]
    @State private var editing: SavedMeal?
    @State private var showCreate = false
    @State private var draftSuggest: [MealComponent]?
    @State private var suggestName = "Suggested meal"

    var body: some View {
        List {
            Section {
                Text("Save meals you actually eat, then log them in one tap. That’s the reliable path.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Text("Suggest is intentionally simple — not AI. It picks a protein (aiming near remaining calories) plus a couple of veggies from your allowed list, and fats/fruit only in Week 2+. Results can feel random if your preferences are empty.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                NavigationLink {
                    FoodPreferencesView(settings: settings)
                } label: {
                    Label("Set food preferences first", systemImage: "heart.text.square")
                }
                Text("Add prefers (foods you like) and excludes (allergies / hard nos). Suggest uses those; without them it just shuffles the catalog.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } header: {
                Text("How this works")
            }

            Section {
                Button {
                    let remaining = max((log?.proteinGoal ?? settings.defaultProteinGoal) - (log?.totalProteinCalories ?? 0), 70)
                    draftSuggest = MealSuggestor.suggest(settings: settings, remainingProteinCalories: remaining)
                    suggestName = "Suggested meal"
                } label: {
                    Label("Suggest a meal", systemImage: "lightbulb")
                }
                if settings.preferredFoodNames.isEmpty && settings.excludedFoodNames.isEmpty {
                    Text("Preferences are empty — expect a rough draft. Set prefers/excludes above for better picks.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Button {
                    showCreate = true
                } label: {
                    Label("Create meal", systemImage: "plus.circle")
                }
            }

            Section("Saved") {
                if meals.isEmpty {
                    Text("No saved meals yet.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(meals, id: \.id) { meal in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(meal.name)
                                        .font(.headline)
                                    Text(meal.summary)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Text("\(meal.proteinCalories) protein kcal")
                                        .font(.caption.monospacedDigit())
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Button("Edit") { editing = meal }
                                    .buttonStyle(.bordered)
                            }
                            if log != nil {
                                Button("Log this meal") {
                                    logMeal(meal)
                                }
                                .buttonStyle(.borderedProminent)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .onDelete(perform: delete)
                }
            }
        }
        .navigationTitle("Saved meals")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $editing) { meal in
            EditSavedMealView(meal: meal, settings: settings)
        }
        .sheet(isPresented: $showCreate) {
            EditSavedMealView(meal: nil, settings: settings)
        }
        .sheet(isPresented: Binding(
            get: { draftSuggest != nil },
            set: { if !$0 { draftSuggest = nil } }
        )) {
            if let draft = draftSuggest {
                NavigationStack {
                    Form {
                        Section {
                            TextField("Name", text: $suggestName)
                            Text("Simple shuffle from your preferences/catalog — not a smart meal plan. Edit or dismiss if it’s off.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        Section("Draft") {
                            ForEach(draft) { component in
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(component.name)
                                        Text(component.category.title)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Text(component.displayAmount)
                                        .font(.caption.monospacedDigit())
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    .navigationTitle("Suggested meal")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Dismiss") { draftSuggest = nil }
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            Menu("Keep") {
                                Button("Save meal") {
                                    saveDraft(draft)
                                    draftSuggest = nil
                                }
                                if log != nil {
                                    Button("Log today") {
                                        applyDraft(draft)
                                        draftSuggest = nil
                                        dismiss()
                                    }
                                    Button("Save & log") {
                                        saveDraft(draft)
                                        applyDraft(draft)
                                        draftSuggest = nil
                                        dismiss()
                                    }
                                }
                            }
                        }
                    }
                    .toolbar {
                        ToolbarItem(placement: .bottomBar) {
                            Button("Suggest again") {
                                let remaining = max((log?.proteinGoal ?? settings.defaultProteinGoal) - (log?.totalProteinCalories ?? 0), 70)
                                draftSuggest = MealSuggestor.suggest(settings: settings, remainingProteinCalories: remaining)
                            }
                        }
                    }
                }
            }
        }
    }

    private func delete(_ offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(meals[index])
        }
        try? modelContext.save()
    }

    private func logMeal(_ meal: SavedMeal) {
        guard let log else { return }
        MealLogger.apply(components: meal.components, to: log, settings: settings)
        try? modelContext.save()
        dismiss()
    }

    private func saveDraft(_ components: [MealComponent]) {
        let meal = SavedMeal(name: suggestName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Suggested meal" : suggestName, components: components)
        modelContext.insert(meal)
        try? modelContext.save()
    }

    private func applyDraft(_ components: [MealComponent]) {
        guard let log else { return }
        MealLogger.apply(components: components, to: log, settings: settings)
        try? modelContext.save()
    }
}

struct EditSavedMealView: View {
    var meal: SavedMeal?
    let settings: AppSettings
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var components: [MealComponent] = []
    @State private var pickerCategory: FoodCategory?
    @State private var proteinServings: Double = 3

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("Meal name", text: $name)
                }
                Section("Items") {
                    if components.isEmpty {
                        Text("Add protein, veggies, and more from the library.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(components) { component in
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(component.name)
                                    Text("\(component.category.title) · \(component.displayAmount)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                            }
                        }
                        .onDelete { offsets in
                            components.remove(atOffsets: offsets)
                        }
                    }
                    Text("Protein total: \(components.filter { $0.category == .protein }.reduce(0) { $0 + $1.totalCalories }) kcal")
                        .font(.subheadline.monospacedDigit())
                }
                Section("Add") {
                    ForEach(addableCategories, id: \.self) { category in
                        Button("Add \(category.title.lowercased())") {
                            pickerCategory = category
                        }
                    }
                }
                if pickerCategory == .protein || components.contains(where: { $0.category == .protein }) {
                    Section("Default protein multiplier for next add") {
                        MultiplierPicker(multiplier: $proteinServings)
                        Stepper(value: $proteinServings, in: 0.5...20, step: 0.5) {
                            Text(String(format: "%.1f×", proteinServings))
                        }
                    }
                }
            }
            .navigationTitle(meal == nil ? "New meal" : "Edit meal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || components.isEmpty)
                }
            }
            .onAppear {
                if let meal {
                    name = meal.name
                    components = meal.components
                }
            }
            .sheet(item: $pickerCategory) { category in
                FoodChecklistPicker(
                    category: category,
                    phase: settings.phase,
                    excludedNames: settings.excludedFoodNames,
                    onPick: { food in
                        add(food)
                        pickerCategory = nil
                    }
                )
            }
        }
    }

    private var addableCategories: [FoodCategory] {
        var list: [FoodCategory] = [.protein, .vegetable, .misc]
        if settings.phase.allowsFatsAndFruits {
            list.append(contentsOf: [.fat, .fruit])
        }
        return list
    }

    private func add(_ food: CatalogFood) {
        if settings.isExcluded(food.name) { return }
        if food.category == .protein {
            components.append(MealComponent(from: food, servings: proteinServings))
        } else {
            components.append(MealComponent(from: food))
        }
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if let meal {
            meal.name = trimmed
            meal.components = components
        } else {
            modelContext.insert(SavedMeal(name: trimmed, components: components))
        }
        try? modelContext.save()
        dismiss()
    }
}
