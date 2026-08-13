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
    var includesMealSides: Bool = true
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

    @State private var showBarcodeScanner = false
    @State private var isLookingUpBarcode = false
    @State private var barcodeError: String?
    @State private var confirmCandidate: RemoteFoodCandidate?

    @State private var usdaResults: [RemoteFoodCandidate] = []
    @State private var isSearchingUSDA = false
    @State private var usdaError: String?
    @State private var usdaSearchTask: Task<Void, Never>?

    @State private var mealSides: Set<MealSidePick> = []
    @State private var vegSideChips: [SuggestionItem] = []
    @State private var fatSideChips: [SuggestionItem] = []
    @State private var fruitSideChips: [SuggestionItem] = []

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
        includesMealSides: Bool = true,
        onSaved: (() -> Void)? = nil
    ) {
        self.log = log
        self.settings = settings
        self.navigationTitleText = navigationTitleText
        self.includesMealSides = includesMealSides
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
                    if includesMealSides { mealSidesSection }
                    hungerSection
                } else if showCustomForm {
                    customFoodSection
                    amountSection
                    detailsSection
                    hydrationSection
                    if includesMealSides { mealSidesSection }
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
                        Button(includesMealSides ? "Log meal" : "Save") { save() }
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
            .sheet(isPresented: $showBarcodeScanner) {
                BarcodeScannerSheet { code in
                    Task { await lookupBarcode(code) }
                }
            }
            .sheet(item: $confirmCandidate) { candidate in
                RemoteFoodConfirmSheet(candidate: candidate, log: log, settings: settings) {
                    onSaved?()
                    dismiss()
                }
            }
            .alert("Lookup", isPresented: Binding(
                get: { barcodeError != nil },
                set: { if !$0 { barcodeError = nil } }
            )) {
                Button("OK", role: .cancel) { barcodeError = nil }
                Button("Add custom") {
                    barcodeError = nil
                    beginCustomEntry()
                }
            } message: {
                Text(barcodeError ?? "")
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
            .onChange(of: search) { _, newValue in
                scheduleUSDASearch(for: newValue)
            }
            .onAppear {
                searchFocused = true
                refreshMealSideChips()
            }
            .overlay {
                if isLookingUpBarcode {
                    ZStack {
                        Color.black.opacity(0.2).ignoresSafeArea()
                        ProgressView("Looking up…")
                            .padding(20)
                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                    }
                }
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
                        usdaResults = []
                        usdaError = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }

            Button {
                showBarcodeScanner = true
            } label: {
                Label("Scan barcode", systemImage: "barcode.viewfinder")
            }

            if searchResults.isEmpty {
                Text(search.isEmpty ? "Type a name to search the full list." : "No local matches.")
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

            if shouldShowUSDASection {
                usdaSection
            }

            Button {
                beginCustomEntry()
            } label: {
                Label("Add custom food", systemImage: "plus.circle.fill")
            }
        } header: {
            Text("Find food")
        } footer: {
            Text("Search local foods first. Scan a package barcode (Open Food Facts) or search USDA when needed. Results save as presets.")
        }
    }

    private var shouldShowUSDASection: Bool {
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
        guard query.count >= 2 else { return false }
        return searchResults.count < 3 || !usdaResults.isEmpty || isSearchingUSDA || usdaError != nil
    }

    @ViewBuilder
    private var usdaSection: some View {
        if settings.usdaAPIKey.isEmpty {
            Text("Add a USDA API key in Settings → Food lookup to search the USDA database.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        } else {
            if isSearchingUSDA {
                HStack {
                    ProgressView()
                    Text("Searching USDA…")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            if let usdaError {
                Text(usdaError)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            if !usdaResults.isEmpty {
                Text("USDA results")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                ForEach(usdaResults) { item in
                    Button {
                        confirmCandidate = item
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.name)
                                .font(.body.weight(.medium))
                                .foregroundStyle(.primary)
                                .multilineTextAlignment(.leading)
                            Text(item.subtitle)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 2)
                    }
                    .buttonStyle(.plain)
                }
            } else if !isSearchingUSDA, usdaError == nil, searchResults.count < 3 {
                Button("Search USDA") {
                    Task { await runUSDASearch(force: true) }
                }
            }
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

    private var mealSidesSection: some View {
        Section {
            mealSideGroup(title: "Vegetables", chips: vegSideChips, category: .vegetable)
            if settings.phase.allowsFatsAndFruits {
                mealSideGroup(title: "Fats", chips: fatSideChips, category: .fat)
                mealSideGroup(title: "Fruits", chips: fruitSideChips, category: .fruit)
            } else {
                Text("Fats and fruits unlock in Week 2+.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("Also on this meal")
        } footer: {
            Text("One confirm logs protein plus sides. Use Fats, Veggies & More later for leftovers.")
        }
    }

    @ViewBuilder
    private func mealSideGroup(title: String, chips: [SuggestionItem], category: FoodCategory) -> some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
        if chips.isEmpty {
            Text("No suggestions yet")
                .font(.footnote)
                .foregroundStyle(.secondary)
        } else {
            FlexibleMealSideChips(items: chips, category: category, selection: $mealSides)
        }
    }

    private func refreshMealSideChips() {
        vegSideChips = UsageSuggestions.checklistChips(category: .vegetable, phase: settings.phase, in: modelContext)
        fatSideChips = UsageSuggestions.checklistChips(category: .fat, phase: settings.phase, in: modelContext)
        fruitSideChips = UsageSuggestions.checklistChips(category: .fruit, phase: settings.phase, in: modelContext)
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

        if includesMealSides, !mealSides.isEmpty {
            let components = mealSides.map { side in
                MealComponent(
                    name: side.name,
                    category: side.category,
                    servingLabel: side.amount,
                    unitCalories: 0,
                    amount: side.amount
                )
            }
            MealLogger.apply(components: components, to: log, settings: settings)
        }

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

    // MARK: - Remote lookup

    private func lookupBarcode(_ code: String) async {
        await MainActor.run { isLookingUpBarcode = true }
        do {
            let candidate = try await OpenFoodFactsClient.product(barcode: code)
            await MainActor.run {
                isLookingUpBarcode = false
                confirmCandidate = candidate
            }
        } catch {
            await MainActor.run {
                isLookingUpBarcode = false
                barcodeError = error.localizedDescription
            }
        }
    }

    private func scheduleUSDASearch(for query: String) {
        usdaSearchTask?.cancel()
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2, !settings.usdaAPIKey.isEmpty else {
            usdaResults = []
            usdaError = nil
            isSearchingUSDA = false
            return
        }
        // Only auto-search when local hits are thin.
        guard searchResults.count < 3 else {
            usdaResults = []
            usdaError = nil
            return
        }
        usdaSearchTask = Task {
            try? await Task.sleep(nanoseconds: 450_000_000)
            guard !Task.isCancelled else { return }
            await runUSDASearch(force: false)
        }
    }

    private func runUSDASearch(force: Bool) async {
        let trimmed = search.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else { return }
        if settings.usdaAPIKey.isEmpty {
            await MainActor.run {
                usdaError = RemoteFoodError.missingAPIKey.localizedDescription
            }
            return
        }
        if !force, searchResults.count >= 3 { return }

        await MainActor.run {
            isSearchingUSDA = true
            usdaError = nil
        }
        do {
            let results = try await USDAFoodDataClient.search(query: trimmed, apiKey: settings.usdaAPIKey)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                usdaResults = results
                isSearchingUSDA = false
                if results.isEmpty {
                    usdaError = "No USDA matches for “\(trimmed)”."
                }
            }
        } catch {
            guard !Task.isCancelled else { return }
            await MainActor.run {
                isSearchingUSDA = false
                usdaResults = []
                usdaError = error.localizedDescription
            }
        }
    }
}

private struct MealSidePick: Hashable, Identifiable {
    var id: String { "\(category.rawValue)-\(name)" }
    var category: FoodCategory
    var name: String
    var amount: String
}

private struct FlexibleMealSideChips: View {
    let items: [SuggestionItem]
    let category: FoodCategory
    @Binding var selection: Set<MealSidePick>

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(items) { item in
                    let pick = MealSidePick(
                        category: category,
                        name: item.name,
                        amount: item.amount ?? item.subtitle ?? ChecklistStorage.defaultAmount(for: item.name, category: category)
                    )
                    let selected = selection.contains(pick)
                    Button {
                        if selected {
                            selection.remove(pick)
                        } else {
                            selection.insert(pick)
                        }
                    } label: {
                        Text(item.name)
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(selected ? Color.accentColor.opacity(0.2) : Color.secondary.opacity(0.12))
                            .foregroundStyle(selected ? Color.accentColor : Color.primary)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 2)
        }
    }
}
