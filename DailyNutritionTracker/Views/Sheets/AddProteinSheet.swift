import SwiftUI
import SwiftData

struct AddProteinSheet: View {
    @Bindable var log: DailyLog
    let settings: AppSettings
    var onSaved: (() -> Void)? = nil
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var search = ""
    @State private var selectedCategory: ProteinCategory = .veryLean
    @State private var selected: CatalogFood?
    @State private var servings: Double = 1
    @State private var totalCalories: Int = 35
    @State private var caloriesText = "35"
    @State private var hungerBefore = 4
    @State private var hungerAfter = 6
    @State private var time = Date()
    @State private var saveAsPreset = false
    @State private var customName = ""
    @State private var customUnitCalories = 35
    @State private var useCustom = false
    @State private var showHungerHelp = false
    @State private var countTowardHydration = false
    @State private var hydrationOz: Double = 8
    @FocusState private var caloriesFocused: Bool

    private var catalogItems: [CatalogFood] {
        let excluded = Set(settings.excludedFoodNames.map { $0.lowercased() })
        return FoodCatalog.foods(category: .protein, phase: settings.phase, search: search)
            .filter { food in
                if excluded.contains(food.name.lowercased()) { return false }
                guard let cat = food.proteinCategory else { return true }
                return cat == selectedCategory
            }
    }

    private var unitCalories: Int {
        if useCustom { return max(customUnitCalories, 1) }
        guard let selected else { return 35 }
        if let per = selected.proteinCategory?.caloriesPerServing {
            return per
        }
        return max(selected.calories, 1)
    }

    private var servingLabel: String {
        if useCustom {
            return abs(servings - 1) < 0.01 ? "1 serving" : String(format: "%.1f× serving", servings)
        }
        guard let selected else { return "" }
        if abs(servings - 1) < 0.01 {
            return selected.servingLabel
        }
        return String(format: "%.1f × %@", servings, selected.servingLabel)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Custom entry", isOn: $useCustom)
                    if useCustom {
                        TextField("Food name", text: $customName)
                        Stepper("Unit calories: \(customUnitCalories)", value: $customUnitCalories, in: 5...800, step: 5)
                    } else {
                        Picker("Category", selection: $selectedCategory) {
                            ForEach(ProteinCategory.allCases.filter { $0 != .other }) { cat in
                                Text(cat.title).tag(cat)
                            }
                        }
                        .pickerStyle(.menu)

                        TextField("Search", text: $search)
                        Picker("Food", selection: $selected) {
                            Text("Select…").tag(Optional<CatalogFood>.none)
                            ForEach(catalogItems) { food in
                                Text("\(food.name) (\(food.servingLabel))").tag(Optional(food))
                            }
                        }
                    }
                } header: {
                    Text("Food")
                } footer: {
                    Text("Very lean 35 / lean 55 / medium fat 75 kcal per serving unit.")
                }

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
                    .onChange(of: servings) { _, newValue in
                        // Keep calories in sync when using stepper (not when typing calories).
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
                    Text("Amount")
                } footer: {
                    Text("Multipliers are shortcuts. Edit total calories anytime — that’s what gets logged.")
                }

                Section("Details") {
                    DatePicker("Time", selection: $time, displayedComponents: .hourAndMinute)
                    Toggle("Save to My Presets", isOn: $saveAsPreset)
                }

                if settings.proteinDrinksCountTowardHydration {
                    Section {
                        Toggle("Also count toward hydration", isOn: $countTowardHydration)
                        if countTowardHydration {
                            Stepper(
                                "\(Int(hydrationOz)) oz fluid",
                                value: $hydrationOz,
                                in: 2...40,
                                step: 1
                            )
                        }
                    } header: {
                        Text("Hydration")
                    } footer: {
                        Text("Protein shakes and ready-to-drink items can add to today’s water total without logging a separate bottle.")
                    }
                }

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
            .navigationTitle("Add Protein")
            .keyboardDoneToolbar(focus: $caloriesFocused)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        Keyboard.dismiss()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(!canSave)
                }
            }
            .alert("Hunger Scale", isPresented: $showHungerHelp) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(HungerScale.guidance)
            }
            .onChange(of: selected) { _, _ in
                servings = 1
                syncCaloriesFromServings()
                refreshHydrationDefaults()
            }
            .onChange(of: selectedCategory) { _, _ in
                selected = nil
                refreshHydrationDefaults()
            }
            .onChange(of: servings) { _, _ in
                if countTowardHydration, let suggested = currentSuggestedHydration {
                    hydrationOz = suggested
                }
            }
            .onChange(of: useCustom) { _, _ in
                syncCaloriesFromServings()
                refreshHydrationDefaults()
            }
            .onChange(of: customUnitCalories) { _, _ in
                if useCustom { syncCaloriesFromServings() }
            }
            .onAppear {
                syncCaloriesFromServings()
                refreshHydrationDefaults()
            }
        }
    }

    private var currentSuggestedHydration: Double? {
        let category: String
        if useCustom {
            category = ProteinCategory.other.rawValue
        } else if let selected {
            category = selected.proteinCategory?.rawValue ?? selectedCategory.rawValue
        } else {
            category = selectedCategory.rawValue
        }
        return settings.suggestedHydrationOz(forProteinCategory: category, servings: servings)
    }

    private func refreshHydrationDefaults() {
        guard settings.proteinDrinksCountTowardHydration else {
            countTowardHydration = false
            return
        }
        if let suggested = currentSuggestedHydration {
            countTowardHydration = true
            hydrationOz = suggested
        } else if selectedCategory == .shake || (!useCustom && selected?.proteinCategory == .shake) {
            countTowardHydration = true
            hydrationOz = settings.defaultShakeHydrationOz * max(servings, 0.5)
        } else {
            // Keep manual toggle state if user already enabled it for a non-shake.
            if !countTowardHydration {
                hydrationOz = settings.defaultShakeHydrationOz
            }
        }
    }

    private var canSave: Bool {
        if useCustom {
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
        // Prefer typed calories if valid.
        if let typed = Int(caloriesText.filter(\.isNumber)), typed > 0 {
            totalCalories = typed
        }

        let name: String
        let category: String
        if useCustom {
            name = customName.trimmingCharacters(in: .whitespaces)
            category = ProteinCategory.other.rawValue
        } else if let selected {
            name = selected.name
            category = selected.proteinCategory?.rawValue ?? ProteinCategory.other.rawValue
        } else {
            return
        }

        let entry = ProteinEntry(
            name: name,
            time: time,
            servingSize: servingLabel.isEmpty ? "1 serving" : servingLabel,
            calories: totalCalories,
            hungerBefore: hungerBefore,
            hungerAfter: hungerAfter,
            proteinCategory: category,
            servings: servings,
            hydrationOz: (settings.proteinDrinksCountTowardHydration && countTowardHydration)
                ? hydrationOz
                : nil
        )
        modelContext.insert(entry)
        log.proteinEntries.append(entry)

        if saveAsPreset {
            let preset = CustomFoodPreset(
                name: name,
                servingLabel: entry.servingSize,
                calories: totalCalories,
                proteinCategory: category,
                servingsPerUnit: servings
            )
            modelContext.insert(preset)
        }

        try? modelContext.save()
        onSaved?()
        dismiss()
    }
}
