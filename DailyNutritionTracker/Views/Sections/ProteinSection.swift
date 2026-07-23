import SwiftUI
import SwiftData

struct ProteinSection: View {
    @Bindable var log: DailyLog
    let settings: AppSettings
    var scrollAnchor: String = "protein"
    var onWillPresentSheet: ((String) -> Void)? = nil

    @Environment(\.modelContext) private var modelContext
    @Environment(\.accentPrimary) private var accentPrimary
    @State private var showAdd = false
    @State private var showSnack = false
    @State private var showMeals = false
    @State private var editingEntry: ProteinEntry?
    @State private var editTimeEntry: ProteinEntry?
    @State private var suggestionChips: [SuggestionItem] = []
    @Query(sort: \CustomFoodPreset.name) private var presets: [CustomFoodPreset]
    @Query(sort: \SavedMeal.name) private var savedMeals: [SavedMeal]

    var body: some View {
        SectionCard(
            title: "Protein Log",
            systemImage: "fork.knife.circle",
            isCollapsed: settings.sectionCollapsedBinding(.protein, context: modelContext),
            collapsedMessage: DaySectionID.protein.collapsedMessage
        ) {
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

            VStack(spacing: 10) {
                Button {
                    onWillPresentSheet?(scrollAnchor)
                    showAdd = true
                } label: {
                    Label("Add protein", systemImage: "plus.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)

                HStack(spacing: 10) {
                    Button {
                        onWillPresentSheet?(scrollAnchor)
                        showSnack = true
                    } label: {
                        Label("Snack", systemImage: "carrot.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)

                    Button {
                        onWillPresentSheet?(scrollAnchor)
                        showMeals = true
                    } label: {
                        Label("Meals", systemImage: "square.stack.3d.up")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
            }

            if log.sortedProteins.isEmpty {
                Text("Log meals with a multiplier (1×, 3×, 6×…) and hunger before/after. Or use Saved meals / Suggest.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 0) {
                    ForEach(log.sortedProteins, id: \.id) { entry in
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 4) {
                                Button {
                                    onWillPresentSheet?(scrollAnchor)
                                    editingEntry = entry
                                } label: {
                                    Text(entry.name)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(.primary)
                                }
                                .buttonStyle(.plain)

                                HStack(spacing: 4) {
                                    Button(DateHelpers.formattedTime(entry.time)) {
                                        editTimeEntry = entry
                                    }
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(accentPrimary)
                                    .buttonStyle(.plain)
                                    Text("· \(entry.servingSize) · hunger \(entry.hungerBefore)→\(entry.hungerAfter)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                if entry.hydrationOz > 0, settings.proteinDrinksCountTowardHydration {
                                    Text("+\(Int(entry.hydrationOz.rounded())) oz hydration")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                                Text(settings.proteinDrinksCountTowardHydration
                                     ? "Tap name to edit calories & fl oz"
                                     : "Tap name to edit amount")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer(minLength: 8)
                            Text("\(entry.calories) kcal")
                                .font(.subheadline.monospacedDigit())
                                .foregroundStyle(.primary)

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
        .sheet(isPresented: $showSnack, onDismiss: { onWillPresentSheet?(scrollAnchor) }) {
            QuickSnackSheet(log: log, settings: settings) {
                refreshChips()
            }
            .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showMeals, onDismiss: { onWillPresentSheet?(scrollAnchor) }) {
            NavigationStack {
                SavedMealsListView(settings: settings, log: log)
            }
        }
        .sheet(item: $editingEntry, onDismiss: { onWillPresentSheet?(scrollAnchor) }) { entry in
            EditProteinAmountSheet(
                entry: entry,
                allowHydrationEdit: settings.proteinDrinksCountTowardHydration,
                onSave: { multiplier, calories, hydrationOz in
                    applyAmount(to: entry, multiplier: multiplier, calories: calories, hydrationOz: hydrationOz)
                    editingEntry = nil
                    refreshChips()
                },
                onDelete: {
                    delete(entry)
                    editingEntry = nil
                },
                onCancel: { editingEntry = nil }
            )
            .presentationDetents([.medium, .large])
        }
        .sheet(item: $editTimeEntry) { entry in
            EditTimestampSheet(
                title: entry.name,
                initialDate: entry.time,
                includesDate: true
            ) { newDate in
                moveProtein(entry, to: newDate)
            }
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

    private func moveProtein(_ entry: ProteinEntry, to newDate: Date) {
        let targetDay = DateHelpers.startOfDay(newDate)
        let sourceDay = DateHelpers.startOfDay(log.date)
        entry.time = newDate
        if targetDay != sourceDay {
            log.proteinEntries.removeAll { $0.id == entry.id }
            let targetLog = DataStore.log(for: targetDay, in: modelContext, defaultGoal: settings.defaultProteinGoal)
            targetLog.proteinEntries.append(entry)
        }
        try? modelContext.save()
        refreshChips()
    }

    private func applyAmount(to entry: ProteinEntry, multiplier: Double, calories: Int, hydrationOz: Double?) {
        entry.servings = multiplier
        entry.calories = max(calories, 1)
        if let hydrationOz {
            entry.hydrationOz = hydrationOz
        }
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
        let category = item.proteinCategory ?? ProteinCategory.other.rawValue
        let entry = ProteinEntry(
            name: item.name,
            servingSize: item.subtitle ?? "1 serving",
            calories: totalCalories,
            proteinCategory: category,
            servings: max(item.servings, 1),
            hydrationOz: settings.suggestedHydrationOz(
                forProteinCategory: category,
                servings: max(item.servings, 1)
            )
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
            servings: preset.servingsPerUnit,
            hydrationOz: settings.suggestedHydrationOz(
                forProteinCategory: preset.proteinCategory,
                servings: preset.servingsPerUnit
            )
        )
        modelContext.insert(entry)
        log.proteinEntries.append(entry)
        try? modelContext.save()
        refreshChips()
    }
}

extension ProteinEntry: Identifiable {}
extension SavedMeal: Identifiable {}

struct EditProteinAmountSheet: View {
    let entry: ProteinEntry
    var allowHydrationEdit: Bool = false
    var onSave: (Double, Int, Double?) -> Void
    var onDelete: () -> Void
    var onCancel: () -> Void

    @State private var servings: Double = 1
    @State private var caloriesText = ""
    @State private var totalCalories = 0
    @State private var countTowardHydration = false
    @State private var hydrationOz: Double = 8
    @FocusState private var caloriesFocused: Bool
    @FocusState private var hydrationFocused: Bool

    private var unitCalories: Int {
        if entry.servings > 0 {
            return max(1, Int((Double(entry.calories) / entry.servings).rounded()))
        }
        if let cat = ProteinCategory(rawValue: entry.proteinCategory), let per = cat.caloriesPerServing {
            return per
        }
        return max(entry.calories, 1)
    }

    private var looksLikeDrink: Bool {
        ProteinCategory(rawValue: entry.proteinCategory) == .shake
            || entry.name.localizedCaseInsensitiveContains("shake")
            || entry.name.localizedCaseInsensitiveContains("drink")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Unit reference: \(unitCalories) kcal per 1×")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    Text("Quick multipliers")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    MultiplierPicker(multiplier: $servings) { value in
                        servings = value
                        syncCaloriesFromServings()
                        caloriesFocused = false
                        Keyboard.dismiss()
                    }

                    Stepper(value: $servings, in: 0.5...20, step: 0.5) {
                        Text(String(format: "Servings: %.1f×", servings))
                    }
                    .onChange(of: servings) { _, _ in
                        if !caloriesFocused {
                            syncCaloriesFromServings()
                        }
                    }

                    HStack {
                        Text("Total calories")
                        Spacer()
                        TextField("kcal", text: $caloriesText)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .focused($caloriesFocused)
                            .frame(maxWidth: 100)
                            .onChange(of: caloriesText) { _, newValue in
                                let filtered = newValue.filter(\.isNumber)
                                if filtered != newValue { caloriesText = filtered }
                                if let value = Int(filtered), value > 0 {
                                    totalCalories = value
                                }
                            }
                        Text("kcal")
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text(entry.name)
                } footer: {
                    Text("Multipliers are shortcuts. Edit total calories to log exactly what you ate.")
                }

                if allowHydrationEdit {
                    Section {
                        Toggle("Count toward hydration", isOn: $countTowardHydration)
                        if countTowardHydration {
                            HStack {
                                Text("Fluid ounces")
                                Spacer()
                                TextField("oz", value: $hydrationOz, format: .number)
                                    .keyboardType(.decimalPad)
                                    .multilineTextAlignment(.trailing)
                                    .focused($hydrationFocused)
                                    .frame(maxWidth: 80)
                                Text("oz")
                                    .foregroundStyle(.secondary)
                            }
                            Stepper(
                                "\(Int(hydrationOz.rounded())) oz",
                                value: $hydrationOz,
                                in: 2...40,
                                step: 1
                            )
                        }
                    } header: {
                        Text("Hydration")
                    } footer: {
                        Text("For RTDs and shakes, set the bottle size you actually drank (calories and fl oz are separate).")
                    }
                }
            }
            .navigationTitle("Update amount")
            .navigationBarTitleDisplayMode(.inline)
            .keyboardDoneToolbar(focus: $caloriesFocused)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        Keyboard.dismiss()
                        onCancel()
                    }
                }
                ToolbarItem(placement: .destructiveAction) {
                    Button("Delete", role: .destructive) {
                        Keyboard.dismiss()
                        onDelete()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Keyboard.dismiss()
                        if let typed = Int(caloriesText.filter(\.isNumber)), typed > 0 {
                            totalCalories = typed
                        }
                        let hydration: Double? = allowHydrationEdit
                            ? (countTowardHydration ? max(hydrationOz, 0) : 0)
                            : nil
                        onSave(servings, max(totalCalories, 1), hydration)
                    }
                }
            }
            .onAppear {
                servings = max(entry.servings, 0.5)
                totalCalories = max(entry.calories, 1)
                caloriesText = "\(totalCalories)"
                if entry.hydrationOz > 0 {
                    countTowardHydration = true
                    hydrationOz = entry.hydrationOz
                } else if looksLikeDrink {
                    countTowardHydration = true
                    hydrationOz = 8
                } else {
                    countTowardHydration = false
                    hydrationOz = 8
                }
            }
        }
    }

    private func syncCaloriesFromServings() {
        totalCalories = max(1, Int((Double(unitCalories) * servings).rounded()))
        caloriesText = "\(totalCalories)"
    }
}

/// One-tap snack logging — no hunger sliders, no category picker.
struct QuickSnackSheet: View {
    @Bindable var log: DailyLog
    let settings: AppSettings
    var onLogged: (() -> Void)? = nil

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var showCustom = false
    @State private var customName = ""
    @State private var customCalories = 55
    @FocusState private var customFocused: Bool

    private var recentSnacks: [SuggestionItem] {
        UsageSuggestions.snackChips(in: modelContext, limit: 6)
    }

    private var catalogSnacks: [CatalogFood] {
        let excluded = Set(settings.excludedFoodNames.map { $0.lowercased() })
        let recentNames = Set(recentSnacks.map { $0.name.lowercased() })
        return FoodCatalog.snacks.filter { food in
            !excluded.contains(food.name.lowercased()) && !recentNames.contains(food.name.lowercased())
        }
    }

    var body: some View {
        NavigationStack {
            List {
                if !recentSnacks.isEmpty {
                    Section("Recent") {
                        ForEach(recentSnacks) { item in
                            snackButton(
                                name: item.name,
                                detail: item.subtitle ?? "1 serving",
                                calories: item.calories ?? 55,
                                servings: max(item.servings, 1)
                            )
                        }
                    }
                }

                Section("Tap to log") {
                    ForEach(catalogSnacks) { food in
                        snackButton(
                            name: food.name,
                            detail: food.servingLabel,
                            calories: food.calories,
                            servings: 1
                        )
                    }
                }

                Section {
                    if showCustom {
                        TextField("What did you have?", text: $customName)
                            .focused($customFocused)
                        Stepper("\(customCalories) kcal", value: $customCalories, in: 10...400, step: 5)
                        Button("Log custom snack") {
                            logCustom()
                        }
                        .disabled(customName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    } else {
                        Button("Something else…") {
                            showCustom = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                                customFocused = true
                            }
                        }
                    }
                }
            }
            .navigationTitle("Snack")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .keyboardDoneToolbar(focus: $customFocused)
        }
    }

    private func snackButton(name: String, detail: String, calories: Int, servings: Double) -> some View {
        Button {
            logSnack(name: name, servingSize: detail, calories: calories, servings: servings)
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(name)
                        .font(.body.weight(.medium))
                        .foregroundStyle(.primary)
                    Text("\(detail) · \(calories) kcal")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "plus.circle.fill")
                    .foregroundStyle(Color.accentColor)
            }
        }
    }

    private func logSnack(name: String, servingSize: String, calories: Int, servings: Double) {
        let entry = ProteinEntry(
            name: name,
            servingSize: servingSize,
            calories: max(calories, 1),
            hungerBefore: 4,
            hungerAfter: 6,
            proteinCategory: ProteinCategory.snack.rawValue,
            servings: servings
        )
        modelContext.insert(entry)
        log.proteinEntries.append(entry)
        try? modelContext.save()
        onLogged?()
        dismiss()
    }

    private func logCustom() {
        let name = customName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        logSnack(name: name, servingSize: "1 serving", calories: customCalories, servings: 1)
    }
}
