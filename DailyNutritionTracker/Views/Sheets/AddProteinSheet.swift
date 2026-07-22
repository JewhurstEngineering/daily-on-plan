import SwiftUI
import SwiftData

/// Unified catalog + saved-preset row for search-first protein logging.
private struct ProteinSearchItem: Identifiable, Hashable {
    enum Source: Hashable {
        case catalog
        case preset
    }

    let id: String
    let name: String
    let servingLabel: String
    let unitCalories: Int
    let proteinCategory: ProteinCategory
    let source: Source

    var subtitle: String {
        let cat = proteinCategory == .other ? "Custom" : proteinCategory.title
        return "\(servingLabel) · \(unitCalories) kcal · \(cat)"
    }

    static func from(catalog food: CatalogFood) -> ProteinSearchItem {
        let category = food.proteinCategory ?? .other
        let unit = category.caloriesPerServing ?? max(food.calories, 1)
        return ProteinSearchItem(
            id: "catalog-\(food.id)",
            name: food.name,
            servingLabel: food.servingLabel,
            unitCalories: unit,
            proteinCategory: category,
            source: .catalog
        )
    }

    static func from(preset: CustomFoodPreset) -> ProteinSearchItem {
        let category = ProteinCategory(rawValue: preset.proteinCategory) ?? .other
        let unit: Int
        if preset.servingsPerUnit > 0 {
            unit = max(1, Int((Double(preset.calories) / preset.servingsPerUnit).rounded()))
        } else {
            unit = max(preset.calories, 1)
        }
        return ProteinSearchItem(
            id: "preset-\(preset.id.uuidString)",
            name: preset.name,
            servingLabel: preset.servingLabel.isEmpty ? "1 serving" : preset.servingLabel,
            unitCalories: unit,
            proteinCategory: category,
            source: .preset
        )
    }
}

struct AddProteinSheet: View {
    @Bindable var log: DailyLog
    let settings: AppSettings
    var navigationTitleText: String = "Add Protein"
    var onSaved: (() -> Void)? = nil

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \CustomFoodPreset.name) private var presets: [CustomFoodPreset]

    @State private var search = ""
    @State private var selected: ProteinSearchItem?
    @State private var showCustomForm = false
    @State private var customName = ""
    @State private var customUnitCalories = 100
    @State private var customCategory: ProteinCategory = .other

    @State private var servings: Double = 1
    @State private var totalCalories: Int = 35
    @State private var caloriesText = "35"
    @State private var hungerBefore = 4
    @State private var hungerAfter = 6
    @State private var time = Date()
    @State private var showHungerHelp = false
    @State private var countTowardHydration = false
    @State private var hydrationOz: Double = 8

    @FocusState private var searchFocused: Bool
    @FocusState private var caloriesFocused: Bool
    @FocusState private var customNameFocused: Bool
    @FocusState private var hydrationFocused: Bool

    /// Kept for call sites that still pass a category; ignored — selection sets category.
    init(
        log: DailyLog,
        settings: AppSettings,
        initialCategory: ProteinCategory = .veryLean,
        navigationTitleText: String = "Add Protein",
        onSaved: (() -> Void)? = nil
    ) {
        self.log = log
        self.settings = settings
        self.navigationTitleText = navigationTitleText
        self.onSaved = onSaved
    }

    private var excludedNames: Set<String> {
        Set(settings.excludedFoodNames.map { $0.lowercased() })
    }

    private var catalogItems: [ProteinSearchItem] {
        FoodCatalog.foods(category: .protein, phase: settings.phase, search: "")
            .filter { !excludedNames.contains($0.name.lowercased()) }
            .map(ProteinSearchItem.from(catalog:))
    }

    private var presetItems: [ProteinSearchItem] {
        presets.map(ProteinSearchItem.from(preset:))
    }

    private var allSearchable: [ProteinSearchItem] {
        // Presets first so custom foods win name collisions in display order.
        var seen = Set<String>()
        var items: [ProteinSearchItem] = []
        for item in presetItems + catalogItems {
            let key = item.name.lowercased()
            if seen.insert(key).inserted {
                items.append(item)
            }
        }
        return items
    }

    private var searchResults: [ProteinSearchItem] {
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
        if query.isEmpty {
            // Idle: your saved foods, then a short catalog preview.
            let mine = presetItems
            let preview = catalogItems.prefix(12)
            var seen = Set(mine.map { $0.name.lowercased() })
            var rows = mine
            for item in preview where seen.insert(item.name.lowercased()).inserted {
                rows.append(item)
            }
            return rows
        }
        return allSearchable.filter { item in
            item.name.localizedCaseInsensitiveContains(query)
                || item.proteinCategory.title.localizedCaseInsensitiveContains(query)
                || item.servingLabel.localizedCaseInsensitiveContains(query)
        }
        .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private var unitCalories: Int {
        if showCustomForm { return max(customUnitCalories, 1) }
        return selected?.unitCalories ?? 35
    }

    private var servingLabel: String {
        if showCustomForm {
            return abs(servings - 1) < 0.01 ? "1 serving" : String(format: "%.1f× serving", servings)
        }
        guard let selected else { return "1 serving" }
        if abs(servings - 1) < 0.01 {
            return selected.servingLabel
        }
        return String(format: "%.1f × %@", servings, selected.servingLabel)
    }

    private var resolvedCategory: ProteinCategory {
        if showCustomForm { return customCategory }
        return selected?.proteinCategory ?? .other
    }

    var body: some View {
        NavigationStack {
            Form {
                if let selected, !showCustomForm {
                    selectedFoodSection(selected)
                    amountSection
                    detailsSection
                    hydrationSection
                    hungerSection
                } else if showCustomForm {
                    customFoodSection
                    amountSection
                    detailsSection
                    hydrationSection
                    hungerSection
                } else {
                    searchSection
                }
            }
            .navigationTitle(navigationTitleText)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        Keyboard.dismiss()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if selected != nil || showCustomForm {
                        Button("Save") { save() }
                            .disabled(!canSave)
                    }
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        searchFocused = false
                        caloriesFocused = false
                        customNameFocused = false
                        hydrationFocused = false
                        Keyboard.dismiss()
                    }
                }
            }
            .alert("Hunger Scale", isPresented: $showHungerHelp) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(HungerScale.guidance)
            }
            .onChange(of: servings) { _, _ in
                if !caloriesFocused {
                    syncCaloriesFromServings()
                }
                if countTowardHydration, let suggested = currentSuggestedHydration {
                    hydrationOz = suggested
                }
            }
            .onChange(of: customUnitCalories) { _, _ in
                if showCustomForm, !caloriesFocused {
                    syncCaloriesFromServings()
                }
            }
            .onAppear {
                searchFocused = true
            }
        }
    }

    // MARK: - Sections

    private var searchSection: some View {
        Section {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search all foods…", text: $search)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($searchFocused)
                if !search.isEmpty {
                    Button {
                        search = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }

            if searchResults.isEmpty {
                Text(search.isEmpty ? "Type a name to search the full list." : "No matches. Add it as a custom food.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(searchResults) { item in
                    Button {
                        select(item)
                    } label: {
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.name)
                                    .font(.body.weight(.medium))
                                    .foregroundStyle(.primary)
                                    .multilineTextAlignment(.leading)
                                Text(item.subtitle)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer(minLength: 8)
                            if item.source == .preset {
                                Text("Saved")
                                    .font(.caption2.weight(.semibold))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(Color.accentColor.opacity(0.15))
                                    .foregroundStyle(Color.accentColor)
                                    .clipShape(Capsule())
                            }
                        }
                        .padding(.vertical, 2)
                    }
                    .buttonStyle(.plain)
                }
            }

            Button {
                beginCustomEntry()
            } label: {
                Label("Add custom food", systemImage: "plus.circle.fill")
            }
        } header: {
            Text("Find food")
        } footer: {
            Text("Search everything — lean, shakes, snacks, and foods you’ve saved. Category is set automatically when you pick one.")
        }
    }

    private func selectedFoodSection(_ item: ProteinSearchItem) -> some View {
        Section {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.name)
                        .font(.headline)
                    Text(item.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Change") {
                    clearSelection()
                }
                .font(.subheadline.weight(.semibold))
            }
        } header: {
            Text("Selected")
        } footer: {
            Text("Category comes from the food (\(item.proteinCategory.title)). Changing calories on save is remembered for next time.")
        }
    }

    private var customFoodSection: some View {
        Section {
            TextField("Food name", text: $customName)
                .focused($customNameFocused)
            HStack {
                Text("Calories per serving")
                Spacer()
                TextField("kcal", value: $customUnitCalories, format: .number)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 80)
                Text("kcal")
                    .foregroundStyle(.secondary)
            }
            Picker("Category (optional)", selection: $customCategory) {
                Text("Custom / other").tag(ProteinCategory.other)
                ForEach(ProteinCategory.allCases.filter { $0 != .other }) { cat in
                    Text(cat.title).tag(cat)
                }
            }
            Button("Back to search") {
                showCustomForm = false
                customName = ""
                searchFocused = true
            }
            .font(.subheadline)
        } header: {
            Text("Custom food")
        } footer: {
            Text("Saved to your list automatically so you can search for it next time.")
        }
    }

    private var amountSection: some View {
        Section {
            Text("Quick multipliers")
                .font(.caption)
                .foregroundStyle(.secondary)
            MultiplierPicker(multiplier: $servings) { value in
                applyMultiplier(value)
            }

            Stepper(value: $servings, in: 0.5...20, step: 0.5) {
                Text(String(format: "Servings: %.1f×", servings))
            }

            HStack {
                Text("Total calories")
                Spacer()
                TextField("kcal", text: $caloriesText)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
                    .focused($caloriesFocused)
                    .frame(maxWidth: 80)
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
            Stepper(
                "\(totalCalories) kcal",
                value: Binding(
                    get: { totalCalories },
                    set: { newValue in
                        totalCalories = max(5, newValue)
                        caloriesText = "\(totalCalories)"
                        caloriesFocused = false
                    }
                ),
                in: 5...4000,
                step: 5
            )
        } header: {
            Text("Amount")
        } footer: {
            Text("Multipliers are shortcuts. Use +/− for ±5 kcal, or tap the number to type an exact amount.")
        }
    }

    private var detailsSection: some View {
        Section("Details") {
            DatePicker("Time", selection: $time, displayedComponents: .hourAndMinute)
        }
    }

    @ViewBuilder
    private var hydrationSection: some View {
        if settings.proteinDrinksCountTowardHydration {
            Section {
                Toggle("Also count toward hydration", isOn: $countTowardHydration)
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
                Text("Set the real bottle size (e.g. 11 oz RTD). Calories and fluid ounces are tracked separately.")
            }
        }
    }

    private var hungerSection: some View {
        Section {
            VStack(alignment: .leading) {
                Text("Hunger before: \(hungerBefore)")
                Slider(value: Binding(
                    get: { Double(hungerBefore) },
                    set: { hungerBefore = Int($0) }
                ), in: 1...10, step: 1)
                Text(HungerScale.label(for: hungerBefore))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            VStack(alignment: .leading) {
                Text("Hunger after: \(hungerAfter)")
                Slider(value: Binding(
                    get: { Double(hungerAfter) },
                    set: { hungerAfter = Int($0) }
                ), in: 1...10, step: 1)
                Text(HungerScale.label(for: hungerAfter))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Button("Hunger scale help") { showHungerHelp = true }
        }
    }

    // MARK: - Actions

    private func select(_ item: ProteinSearchItem) {
        selected = item
        showCustomForm = false
        search = ""
        servings = 1
        syncCaloriesFromServings()
        refreshHydrationDefaults()
        searchFocused = false
        Keyboard.dismiss()
    }

    private func clearSelection() {
        selected = nil
        showCustomForm = false
        servings = 1
        searchFocused = true
    }

    private func beginCustomEntry() {
        showCustomForm = true
        selected = nil
        customName = search.trimmingCharacters(in: .whitespacesAndNewlines)
        customUnitCalories = 100
        customCategory = .other
        servings = 1
        syncCaloriesFromServings()
        refreshHydrationDefaults()
        searchFocused = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            customNameFocused = true
        }
    }

    private var currentSuggestedHydration: Double? {
        settings.suggestedHydrationOz(
            forProteinCategory: resolvedCategory.rawValue,
            servings: servings
        )
    }

    private func refreshHydrationDefaults() {
        guard settings.proteinDrinksCountTowardHydration else {
            countTowardHydration = false
            return
        }
        if let suggested = currentSuggestedHydration {
            countTowardHydration = true
            hydrationOz = suggested
        } else if resolvedCategory == .shake {
            countTowardHydration = true
            hydrationOz = settings.defaultShakeHydrationOz * max(servings, 0.5)
        } else if !countTowardHydration {
            hydrationOz = settings.defaultShakeHydrationOz
        }
    }

    private var canSave: Bool {
        if showCustomForm {
            return !customName.trimmingCharacters(in: .whitespaces).isEmpty && totalCalories > 0
        }
        return selected != nil && totalCalories > 0
    }

    private func applyMultiplier(_ value: Double) {
        servings = value
        syncCaloriesFromServings()
        caloriesFocused = false
        Keyboard.dismiss()
    }

    private func syncCaloriesFromServings() {
        totalCalories = max(1, Int((Double(unitCalories) * servings).rounded()))
        caloriesText = "\(totalCalories)"
    }

    private func save() {
        Keyboard.dismiss()
        if let typed = Int(caloriesText.filter(\.isNumber)), typed > 0 {
            totalCalories = typed
        }

        let name: String
        let category: ProteinCategory
        let baseUnitCalories: Int
        let labelForPreset: String

        if showCustomForm {
            name = customName.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else { return }
            category = customCategory
            baseUnitCalories = max(customUnitCalories, 1)
            labelForPreset = "1 serving"
        } else if let selected {
            name = selected.name
            category = selected.proteinCategory
            baseUnitCalories = selected.unitCalories
            labelForPreset = selected.servingLabel
        } else {
            return
        }

        // Remember per-serving calories from what was actually logged (e.g. 45 total at 1× → 45).
        let rememberedUnit = max(1, Int((Double(totalCalories) / max(servings, 0.5)).rounded()))
        let shouldRemember = showCustomForm
            || selected?.source == .preset
            || rememberedUnit != baseUnitCalories
        if shouldRemember {
            upsertPreset(
                name: name,
                servingLabel: labelForPreset,
                unitCalories: rememberedUnit,
                proteinCategory: category
            )
        }

        let entry = ProteinEntry(
            name: name,
            time: time,
            servingSize: servingLabel,
            calories: totalCalories,
            hungerBefore: hungerBefore,
            hungerAfter: hungerAfter,
            proteinCategory: category.rawValue,
            servings: servings,
            hydrationOz: (settings.proteinDrinksCountTowardHydration && countTowardHydration)
                ? hydrationOz
                : nil
        )
        modelContext.insert(entry)
        log.proteinEntries.append(entry)

        try? modelContext.save()
        onSaved?()
        dismiss()
    }

    /// Saves or updates a custom food so it appears in future searches.
    private func upsertPreset(
        name: String,
        servingLabel: String,
        unitCalories: Int,
        proteinCategory: ProteinCategory
    ) {
        let key = name.lowercased()
        if let existing = presets.first(where: { $0.name.lowercased() == key }) {
            existing.servingLabel = servingLabel
            existing.calories = unitCalories
            existing.proteinCategory = proteinCategory.rawValue
            existing.servingsPerUnit = 1
            existing.category = FoodCategory.protein.rawValue
        } else {
            let preset = CustomFoodPreset(
                name: name,
                servingLabel: servingLabel,
                calories: unitCalories,
                category: FoodCategory.protein.rawValue,
                proteinCategory: proteinCategory.rawValue,
                servingsPerUnit: 1
            )
            modelContext.insert(preset)
        }
    }
}
