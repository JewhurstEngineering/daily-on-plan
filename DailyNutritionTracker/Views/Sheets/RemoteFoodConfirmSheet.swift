import SwiftUI
import SwiftData

struct RemoteFoodConfirmSheet: View {
    let candidate: RemoteFoodCandidate
    @Bindable var log: DailyLog
    let settings: AppSettings
    var defaultProteinCategory: ProteinCategory = .other
    var onFinished: (() -> Void)? = nil

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \CustomFoodPreset.name) private var presets: [CustomFoodPreset]

    @State private var name: String = ""
    @State private var servingLabel: String = "1 serving"
    @State private var unitCalories: Int = 100
    @State private var proteinCategory: ProteinCategory = .other
    @State private var saveAsPreset = true
    @State private var logNow = true
    @FocusState private var focused: Bool

    private var canConfirm: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && unitCalories > 0
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $name)
                        .focused($focused)
                    TextField("Serving", text: $servingLabel)
                    HStack {
                        Text("Calories per serving")
                        Spacer()
                        TextField("kcal", value: $unitCalories, format: .number)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(maxWidth: 90)
                        Text("kcal")
                            .foregroundStyle(.secondary)
                    }
                    Picker("Category", selection: $proteinCategory) {
                        Text("Custom / other").tag(ProteinCategory.other)
                        ForEach(ProteinCategory.allCases.filter { $0 != .other }) { cat in
                            Text(cat.title).tag(cat)
                        }
                    }
                } header: {
                    Text(candidate.source.title)
                } footer: {
                    if candidate.caloriesPerServing <= 0 {
                        Text("Calories were missing — enter them from the package label.")
                    } else if let brand = candidate.brand, !brand.isEmpty {
                        Text(brand)
                    }
                }

                Section {
                    Toggle("Save as preset", isOn: $saveAsPreset)
                    Toggle("Log now", isOn: $logNow)
                } footer: {
                    Text("Presets show up in protein search and chips next time.")
                }
            }
            .navigationTitle("Confirm food")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { confirm() }
                        .disabled(!canConfirm)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { focused = false }
                }
            }
            .onAppear {
                name = candidate.name
                servingLabel = candidate.servingLabel.isEmpty ? "1 serving" : candidate.servingLabel
                unitCalories = max(candidate.caloriesPerServing, 0)
                if unitCalories == 0 { unitCalories = 100 }
                proteinCategory = defaultProteinCategory
            }
        }
    }

    private func confirm() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, unitCalories > 0 else { return }
        let label = servingLabel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "1 serving"
            : servingLabel.trimmingCharacters(in: .whitespacesAndNewlines)

        if saveAsPreset {
            upsertPreset(name: trimmed, servingLabel: label, unitCalories: unitCalories)
        }

        if logNow {
            let entry = ProteinEntry(
                name: trimmed,
                servingSize: label,
                calories: unitCalories,
                proteinCategory: proteinCategory.rawValue,
                servings: 1,
                hydrationOz: settings.suggestedHydrationOz(
                    forProteinCategory: proteinCategory.rawValue,
                    servings: 1
                )
            )
            modelContext.insert(entry)
            log.proteinEntries.append(entry)
        }

        try? modelContext.save()
        onFinished?()
        dismiss()
    }

    private func upsertPreset(name: String, servingLabel: String, unitCalories: Int) {
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
