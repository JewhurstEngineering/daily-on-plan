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
                Text("Log clinic receipts (visit date, goals, body composition). Accessible from Settings and Weight.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if readings.isEmpty {
                Section {
                    ContentUnavailableView(
                        "No readings yet",
                        systemImage: "list.clipboard",
                        description: Text("Add a body composition receipt after your clinic visit.")
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
        .navigationBarTitleDisplayMode(.inline)
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
        try? modelContext.save()
    }
}

extension BodyCompositionReading: @retroactive Identifiable {}

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
    @State private var bmrKcal = 0
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
        case protein, water, weight, bmi, impedance, fatPercent, fatMass, ffm, tbw
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
                Text("Age and height come from Settings → Body metrics. Change them there so every receipt starts prefilled.")
            }

            Section("Composition") {
                stepperField("BMI", text: $bmiText, field: .bmi, step: 0.1)
                Stepper("BMR: \(bmrKcal) kcal", value: $bmrKcal, in: 0...5000, step: 5)
                stepperField("Impedance", text: $impedanceText, field: .impedance, step: 1)
                stepperField("Fat %", text: $fatPercentText, field: .fatPercent, step: 0.1)
                stepperField("Fat mass (lb)", text: $fatMassText, field: .fatMass, step: 0.1)
                stepperField("FFM (lb)", text: $ffmText, field: .ffm, step: 0.1)
                stepperField("TBW (lb)", text: $tbwText, field: .tbw, step: 0.1)
            }

            Section("Desirable range") {
                stepperField("Fat % low", text: $desirableFatPercentLowText, field: .desFatLow, step: 0.1)
                stepperField("Fat % high", text: $desirableFatPercentHighText, field: .desFatHigh, step: 0.1)
                stepperField("Fat mass low (lb)", text: $desirableFatMassLowText, field: .desMassLow, step: 0.1)
                stepperField("Fat mass high (lb)", text: $desirableFatMassHighText, field: .desMassHigh, step: 0.1)
            }

            Section("Notes") {
                TextField("Optional notes", text: $notes, axis: .vertical)
                    .lineLimit(2...4)
                    .focused($focusedField, equals: .notes)
            }
        }
        .navigationTitle(reading == nil ? "Add reading" : "Edit reading")
        .navigationBarTitleDisplayMode(.inline)
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
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    focusedField = nil
                    Keyboard.dismiss()
                }
            }
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
            Text("Clinic protein and water goals can update your default protein goal and hydration target.")
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
        keyboard: UIKeyboardType = .default
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.subheadline.weight(.semibold))
            TextField(placeholder, text: text)
                .keyboardType(keyboard)
                .padding(.horizontal, 12)
                .padding(.vertical, 12)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .focused($focusedField, equals: field)
        }
        .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))
    }

    private func stepperField(_ title: String, text: Binding<String>, field: BodyCompField, step: Double) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline.weight(.semibold))
            HStack(spacing: 12) {
                Button {
                    adjust(text, by: -step)
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.title2)
                        .foregroundStyle(Color.accentColor)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)

                TextField("0", text: text)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.center)
                    .font(.title3.monospacedDigit())
                    .padding(.vertical, 10)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .focused($focusedField, equals: field)

                Button {
                    adjust(text, by: step)
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundStyle(Color.accentColor)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
            }
        }
        .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))
    }

    private func adjust(_ text: Binding<String>, by delta: Double) {
        let current = Double(text.wrappedValue.replacingOccurrences(of: ",", with: ".")) ?? 0
        let next = max(0, current + delta)
        if abs(delta) < 1 {
            text.wrappedValue = String(format: "%.1f", next)
        } else if next == next.rounded() {
            text.wrappedValue = "\(Int(next.rounded()))"
        } else {
            text.wrappedValue = String(format: "%.1f", next)
        }
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
            bmrKcal = reading.bmrKcal
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
        target.bmrKcal = bmrKcal
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

        try? modelContext.save()
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
