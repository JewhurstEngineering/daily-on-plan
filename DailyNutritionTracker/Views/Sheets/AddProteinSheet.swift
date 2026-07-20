import SwiftUI
import SwiftData

struct AddProteinSheet: View {
    @Bindable var log: DailyLog
    let settings: AppSettings
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var search = ""
    @State private var selectedCategory: ProteinCategory = .veryLean
    @State private var selected: CatalogFood?
    @State private var servings: Double = 1
    @State private var hungerBefore = 4
    @State private var hungerAfter = 6
    @State private var time = Date()
    @State private var saveAsPreset = false
    @State private var customName = ""
    @State private var customCalories = 35
    @State private var useCustom = false
    @State private var showHungerHelp = false

    private var catalogItems: [CatalogFood] {
        FoodCatalog.foods(category: .protein, phase: settings.phase, search: search)
            .filter { food in
                guard let cat = food.proteinCategory else { return true }
                return cat == selectedCategory
            }
    }

    private var computedCalories: Int {
        if useCustom { return customCalories }
        guard let selected else { return 0 }
        if let per = selected.proteinCategory?.caloriesPerServing {
            return Int((Double(per) * servings).rounded())
        }
        return Int((Double(selected.calories) * servings).rounded())
    }

    private var servingLabel: String {
        if useCustom { return "custom" }
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
                        Stepper("Calories: \(customCalories)", value: $customCalories, in: 5...800, step: 5)
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

                        if let selected, selected.proteinCategory?.caloriesPerServing != nil {
                            Stepper(value: $servings, in: 0.5...12, step: 0.5) {
                                Text(String(format: "Servings: %.1f", servings))
                            }
                        }
                    }
                } header: {
                    Text("Food")
                } footer: {
                    Text("Very lean 35 / lean 55 / medium fat 75 kcal per serving.")
                }

                Section("Details") {
                    DatePicker("Time", selection: $time, displayedComponents: .hourAndMinute)
                    Text("Protein calories: \(computedCalories)")
                        .font(.headline.monospacedDigit())
                    Toggle("Save to My Presets", isOn: $saveAsPreset)
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
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
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
        }
    }

    private var canSave: Bool {
        if useCustom {
            return !customName.trimmingCharacters(in: .whitespaces).isEmpty && customCalories > 0
        }
        return selected != nil
    }

    private func save() {
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
            calories: computedCalories,
            hungerBefore: hungerBefore,
            hungerAfter: hungerAfter,
            proteinCategory: category,
            servings: servings
        )
        modelContext.insert(entry)
        log.proteinEntries.append(entry)

        if saveAsPreset {
            let preset = CustomFoodPreset(
                name: name,
                servingLabel: entry.servingSize,
                calories: computedCalories,
                proteinCategory: category,
                servingsPerUnit: servings
            )
            modelContext.insert(preset)
        }

        try? modelContext.save()
        dismiss()
    }
}
