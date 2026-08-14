import SwiftUI
import SwiftData

struct BodyCompositionListView: View {
    var showsDismissButton: Bool = true

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \BodyCompositionReading.date, order: .reverse) private var readings: [BodyCompositionReading]
    @State private var showAdd = false
    @State private var editing: BodyCompositionReading?

    var body: some View {
        List {
            Section {
                Text("Log body composition readings (visit date, goals, composition numbers). Accessible from Settings and Weight.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if readings.isEmpty {
                Section {
                    ContentUnavailableView(
                        "No readings yet",
                        systemImage: "list.clipboard",
                        description: Text("Add a body composition reading after a weigh-in or scan.")
                    )
                }
            } else {
                Section("Readings") {
                    ForEach(readings, id: \.id) { reading in
                        Button {
                            editing = reading
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(DateHelpers.formattedDay(reading.date))
                                    .font(.headline)
                                    .foregroundStyle(.primary)
                                Text(reading.summaryLine)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .onDelete(perform: delete)
                }
            }
        }
        .navigationTitle("Body composition")
        .onPlanInlineNav()
        .toolbar {
            if showsDismissButton {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showAdd = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Add reading")
            }
        }
        .sheet(isPresented: $showAdd) {
            NavigationStack {
                BodyCompositionEditView(reading: nil)
            }
        }
        .sheet(item: $editing) { reading in
            NavigationStack {
                BodyCompositionEditView(reading: reading)
            }
        }
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(readings[index])
        }
        modelContext.saveAndNotifyJournal()
    }
}

extension BodyCompositionReading: Identifiable {}

struct BodyCompositionEditView: View {
    var reading: BodyCompositionReading?

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var visitDate = Date()
    @State private var proteinGoalText = ""
    @State private var waterTargetText = ""
    @State private var bodyType: BodyCompositionBodyType = .standard
    @State private var gender: BodyCompositionGender = .male
    @State private var age = 30
    @State private var heightInches = 0.0
    @State private var weightText = ""
    @State private var bmiText = ""
    @State private var bmrText = ""
    @State private var impedanceText = ""
    @State private var fatPercentText = ""
    @State private var fatMassText = ""
    @State private var ffmText = ""
    @State private var tbwText = ""
    @State private var desirableFatPercentLowText = ""
    @State private var desirableFatPercentHighText = ""
    @State private var desirableFatMassLowText = ""
    @State private var desirableFatMassHighText = ""
    @State private var notes = ""
    @State private var showApplyGoalsAlert = false
    @FocusState private var focusedField: BodyCompField?

    private enum BodyCompField: Hashable {
        case protein, water, weight, bmi, bmr, impedance, fatPercent, fatMass, ffm, tbw
        case desFatLow, desFatHigh, desMassLow, desMassHigh, notes
    }

    private var weightLbs: Double {
        Double(weightText.replacingOccurrences(of: ",", with: ".")) ?? 0
    }

    private var bmiValue: Double {
        Double(bmiText.replacingOccurrences(of: ",", with: ".")) ?? 0
    }

    var body: some View {
        Form {
            Section("Visit") {
                DatePicker("Date", selection: $visitDate, displayedComponents: .date)
            }

            Section {
                labeledField("Protein goal", placeholder: "e.g. 130-236", text: $proteinGoalText, field: .protein)
                labeledField("Water target", placeholder: "e.g. 180+1 OZ", text: $waterTargetText, field: .water)
            } header: {
                Text("Goals")
            } footer: {
                Text("Labels stay visible so you always know which field is protein vs water.")
            }

            Section {
                Picker("Body type", selection: $bodyType) {
                    ForEach(BodyCompositionBodyType.allCases) { type in
                        Text(type.rawValue).tag(type)
                    }
                }
                Picker("Gender", selection: $gender) {
                    ForEach(BodyCompositionGender.allCases) { item in
                        Text(item.rawValue).tag(item)
                    }
                }

                LabeledContent("Age") {
                    Text(age > 0 ? "\(age)" : "Set in Settings")
                        .foregroundStyle(age > 0 ? .primary : .secondary)
                }
                LabeledContent("Height") {
                    Text(heightInches > 0 ? heightDisplay(heightInches) : "Set in Settings")
                        .foregroundStyle(heightInches > 0 ? .primary : .secondary)
                }

                labeledField("Weight (lb)", placeholder: "0.0", text: $weightText, field: .weight, keyboard: .decimalPad)

                Button {
                    suggestBMI()
                } label: {
                    Label("Suggest BMI from height & weight", systemImage: "function")
                }
                .disabled(weightLbs <= 0 || heightInches <= 0)

                if bmiValue > 0 {
                    Text("BMI \(String(format: "%.1f", bmiValue)) · \(BMICalculator.category(for: bmiValue))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Subject")
            } footer: {
                Text("Age and height come from Settings → Body metrics. Change them there so every reading starts prefilled.")
            }

            Section {
                receiptNumberField(
                    "BMI",
                    placeholder: "e.g. 28.4",
                    text: $bmiText,
                    field: .bmi,
                    keyboard: .decimalPad,
                    hint: "Usually 15–50"
                )
                receiptNumberField(
                    "BMR (kcal)",
                    placeholder: "e.g. 2048",
                    text: $bmrText,
                    field: .bmr,
                    keyboard: .numberPad,
                    hint: "Whole calories from the receipt"
                )
                receiptNumberField(
                    "Impedance",
                    placeholder: "e.g. 512",
                    text: $impedanceText,
                    field: .impedance,
                    keyboard: .decimalPad,
                    hint: "Typically a few hundred"
                )
                receiptNumberField(
                    "Fat %",
                    placeholder: "e.g. 32.1",
                    text: $fatPercentText,
                    field: .fatPercent,
                    keyboard: .decimalPad,
                    hint: "Percent fat"
                )
                receiptNumberField(
                    "Fat mass (lb)",
                    placeholder: "e.g. 68.4",
                    text: $fatMassText,
                    field: .fatMass,
                    keyboard: .decimalPad,
                    hint: "Pounds of fat"
                )
                receiptNumberField(
                    "FFM (lb)",
                    placeholder: "e.g. 140.2",
                    text: $ffmText,
                    field: .ffm,
                    keyboard: .decimalPad,
                    hint: "Fat-free mass"
                )
                receiptNumberField(
                    "TBW (lb)",
                    placeholder: "e.g. 92.5",
                    text: $tbwText,
                    field: .tbw,
                    keyboard: .decimalPad,
                    hint: "Total body water"
                )
            } header: {
                Text("Composition")
            } footer: {
                Text("Type the numbers from the receipt — no need to tap +/− hundreds of times.")
            }

            Section {
                receiptNumberField(
                    "Fat % low",
                    placeholder: "e.g. 18",
                    text: $desirableFatPercentLowText,
                    field: .desFatLow,
                    keyboard: .decimalPad
                )
                receiptNumberField(
                    "Fat % high",
                    placeholder: "e.g. 28",
                    text: $desirableFatPercentHighText,
                    field: .desFatHigh,
                    keyboard: .decimalPad
                )
                receiptNumberField(
                    "Fat mass low (lb)",
                    placeholder: "e.g. 30",
                    text: $desirableFatMassLowText,
                    field: .desMassLow,
                    keyboard: .decimalPad
                )
                receiptNumberField(
                    "Fat mass high (lb)",
                    placeholder: "e.g. 50",
                    text: $desirableFatMassHighText,
                    field: .desMassHigh,
                    keyboard: .decimalPad
                )
            } header: {
                Text("Desirable range")
            }

            Section("Notes") {
                TextField("Optional notes", text: $notes, axis: .vertical)
                    .lineLimit(2...4)
                    .focused($focusedField, equals: .notes)
            }
        }
        .navigationTitle(reading == nil ? "Add reading" : "Edit reading")
        .onPlanInlineNav()
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    if hasGoalText {
                        showApplyGoalsAlert = true
                    } else {
                        persist(applyGoals: false)
                    }
                }
            }
        }
        .onPlanKeyboardDone {
            focusedField = nil
            Keyboard.dismiss()
        }
        .alert("Apply goals to settings?", isPresented: $showApplyGoalsAlert) {
            Button("Just save reading") {
                persist(applyGoals: false)
            }
            Button("Save & apply goals") {
                persist(applyGoals: true)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Protein and water goals on a reading can update your default protein goal and hydration target.")
        }
        .onAppear(perform: load)
        .onChange(of: weightText) { _, _ in
            // Keep suggested BMI in sync when weight is edited and BMI is empty.
            if bmiText.isEmpty { suggestBMI() }
        }
    }

    private var hasGoalText: Bool {
        !proteinGoalText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !waterTargetText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func labeledField(
        _ title: String,
        placeholder: String,
        text: Binding<String>,
        field: BodyCompField,
        keyboard: OnPlanKeyboard = .default
    ) -> some View {
        receiptNumberField(title, placeholder: placeholder, text: text, field: field, keyboard: keyboard)
    }

    private func receiptNumberField(
        _ title: String,
        placeholder: String,
        text: Binding<String>,
        field: BodyCompField,
        keyboard: OnPlanKeyboard = .decimalPad,
        hint: String? = nil
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.subheadline.weight(.semibold))
            TextField(placeholder, text: text)
                .onPlanKeyboard(keyboard)
                .font(.title3.monospacedDigit())
                .padding(.horizontal, 14)
                .padding(.vertical, 14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.onPlanSecondaryFill)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .focused($focusedField, equals: field)
            if let hint {
                Text(hint)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))
    }

    private func heightDisplay(_ inches: Double) -> String {
        let total = Int(inches.rounded())
        return "\(total / 12)'\(total % 12)\""
    }

    private func formatNumber(_ value: Double) -> String {
        if value == 0 { return "" }
        if value == value.rounded() {
            return "\(Int(value.rounded()))"
        }
        return String(format: "%.1f", value)
    }

    private func parseDouble(_ text: String) -> Double {
        Double(text.replacingOccurrences(of: ",", with: ".")) ?? 0
    }

    private func suggestBMI() {
        guard let suggested = BMICalculator.bmi(weightLbs: weightLbs, heightInches: heightInches) else { return }
        bmiText = String(format: "%.1f", suggested)
    }

    private func load() {
        let settings = DataStore.settings(in: modelContext)
        if let reading {
            visitDate = reading.date
            proteinGoalText = reading.proteinGoalText
            waterTargetText = reading.waterTargetText
            bodyType = reading.bodyType
            gender = reading.gender
            age = reading.age
            heightInches = reading.heightInches
            weightText = formatNumber(reading.weightLbs)
            bmiText = formatNumber(reading.bmi)
            bmrText = reading.bmrKcal > 0 ? "\(reading.bmrKcal)" : ""
            impedanceText = formatNumber(reading.impedance)
            fatPercentText = formatNumber(reading.fatPercent)
            fatMassText = formatNumber(reading.fatMassLbs)
            ffmText = formatNumber(reading.ffmLbs)
            tbwText = formatNumber(reading.tbwLbs)
            desirableFatPercentLowText = formatNumber(reading.desirableFatPercentLow)
            desirableFatPercentHighText = formatNumber(reading.desirableFatPercentHigh)
            desirableFatMassLowText = formatNumber(reading.desirableFatMassLow)
            desirableFatMassHighText = formatNumber(reading.desirableFatMassHigh)
            notes = reading.notes
        } else {
            visitDate = Date()
            heightInches = settings.heightInches
            age = settings.ageYears
            if let weight = DataStore.weight(for: visitDate, in: modelContext)
                ?? DataStore.recentWeights(limit: 1, in: modelContext).first {
                weightText = formatNumber(weight.weightLbs)
            }
            if let prior = DataStore.latestBodyComposition(in: modelContext) {
                bodyType = prior.bodyType
                gender = prior.gender
            }
            suggestBMI()
        }
    }

    private func persist(applyGoals: Bool) {
        let target = reading ?? BodyCompositionReading()
        if reading == nil {
            modelContext.insert(target)
        }
        target.date = DateHelpers.startOfDay(visitDate)
        target.proteinGoalText = proteinGoalText.trimmingCharacters(in: .whitespacesAndNewlines)
        target.waterTargetText = waterTargetText.trimmingCharacters(in: .whitespacesAndNewlines)
        target.bodyType = bodyType
        target.gender = gender
        target.age = age
        target.heightInches = heightInches
        target.weightLbs = weightLbs
        target.bmi = bmiValue
        target.bmrKcal = Int(parseDouble(bmrText).rounded())
        target.impedance = parseDouble(impedanceText)
        target.fatPercent = parseDouble(fatPercentText)
        target.fatMassLbs = parseDouble(fatMassText)
        target.ffmLbs = parseDouble(ffmText)
        target.tbwLbs = parseDouble(tbwText)
        target.desirableFatPercentLow = parseDouble(desirableFatPercentLowText)
        target.desirableFatPercentHigh = parseDouble(desirableFatPercentHighText)
        target.desirableFatMassLow = parseDouble(desirableFatMassLowText)
        target.desirableFatMassHigh = parseDouble(desirableFatMassHighText)
        target.notes = notes.trimmingCharacters(in: .whitespacesAndNewlines)

        if applyGoals {
            applyGoalsToSettings()
        }

        modelContext.saveAndNotifyJournal()
        dismiss()
    }

    private func applyGoalsToSettings() {
        let settings = DataStore.settings(in: modelContext)
        let protein = proteinGoalText.trimmingCharacters(in: .whitespacesAndNewlines)
        if let goal = parseProteinGoal(protein) {
            settings.defaultProteinGoal = goal
        }
        let water = waterTargetText.trimmingCharacters(in: .whitespacesAndNewlines)
        if let oz = parseWaterTarget(water) {
            settings.hydrationTargetOz = oz
        }
    }

    private func parseProteinGoal(_ text: String) -> Int? {
        let numbers = text.components(separatedBy: CharacterSet.decimalDigits.inverted)
            .compactMap { Int($0) }
            .filter { $0 > 0 }
        return numbers.last
    }

    private func parseWaterTarget(_ text: String) -> Int? {
        let numbers = text.components(separatedBy: CharacterSet.decimalDigits.inverted)
            .compactMap { Int($0) }
            .filter { $0 > 0 }
        return numbers.first
    }
}
