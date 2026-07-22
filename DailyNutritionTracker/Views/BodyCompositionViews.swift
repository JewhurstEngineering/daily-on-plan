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
    @State private var heightFeet = 5
    @State private var heightInchesPart = 8
    @State private var weightLbs = 0.0
    @State private var bmi = 0.0
    @State private var bmrKcal = 0
    @State private var impedance = 0.0
    @State private var fatPercent = 0.0
    @State private var fatMassLbs = 0.0
    @State private var ffmLbs = 0.0
    @State private var tbwLbs = 0.0
    @State private var desirableFatPercentLow = 0.0
    @State private var desirableFatPercentHigh = 0.0
    @State private var desirableFatMassLow = 0.0
    @State private var desirableFatMassHigh = 0.0
    @State private var notes = ""
    @State private var showApplyGoalsAlert = false

    private var heightInches: Double {
        Double(heightFeet * 12 + heightInchesPart)
    }

    var body: some View {
        Form {
            Section("Visit") {
                DatePicker("Date", selection: $visitDate, displayedComponents: .date)
            }

            Section("Goals") {
                TextField("Protein goal (e.g. 130-236)", text: $proteinGoalText)
                TextField("Water target (e.g. 180+1 OZ)", text: $waterTargetText)
            }

            Section("Subject") {
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
                Stepper("Age: \(age)", value: $age, in: 10...120)
                HStack {
                    Picker("Feet", selection: $heightFeet) {
                        ForEach(4...7, id: \.self) { Text("\($0) ft").tag($0) }
                    }
                    Picker("Inches", selection: $heightInchesPart) {
                        ForEach(0...11, id: \.self) { Text("\($0) in").tag($0) }
                    }
                }
                HStack {
                    Text("Weight")
                    Spacer()
                    TextField("lb", value: $weightLbs, format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: 100)
                    Text("lb")
                        .foregroundStyle(.secondary)
                }
                Button("Suggest BMI from height & weight") {
                    if let suggested = BMICalculator.bmi(weightLbs: weightLbs, heightInches: heightInches) {
                        bmi = suggested
                    }
                }
                .disabled(weightLbs <= 0 || heightInches <= 0)
            }

            Section("Composition") {
                numericRow("BMI", value: $bmi)
                Stepper("BMR: \(bmrKcal) kcal", value: $bmrKcal, in: 0...5000, step: 5)
                numericRow("Impedance", value: $impedance)
                numericRow("Fat %", value: $fatPercent)
                numericRow("Fat mass (lb)", value: $fatMassLbs)
                numericRow("FFM (lb)", value: $ffmLbs)
                numericRow("TBW (lb)", value: $tbwLbs)
            }

            Section("Desirable range") {
                numericRow("Fat % low", value: $desirableFatPercentLow)
                numericRow("Fat % high", value: $desirableFatPercentHigh)
                numericRow("Fat mass low (lb)", value: $desirableFatMassLow)
                numericRow("Fat mass high (lb)", value: $desirableFatMassHigh)
            }

            Section("Notes") {
                TextField("Optional notes", text: $notes, axis: .vertical)
                    .lineLimit(2...4)
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
    }

    private var hasGoalText: Bool {
        !proteinGoalText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !waterTargetText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func numericRow(_ title: String, value: Binding<Double>) -> some View {
        HStack {
            Text(title)
            Spacer()
            TextField("0", value: value, format: .number)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: 120)
        }
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
            let totalInches = Int(reading.heightInches.rounded())
            heightFeet = max(totalInches / 12, 4)
            heightInchesPart = totalInches % 12
            weightLbs = reading.weightLbs
            bmi = reading.bmi
            bmrKcal = reading.bmrKcal
            impedance = reading.impedance
            fatPercent = reading.fatPercent
            fatMassLbs = reading.fatMassLbs
            ffmLbs = reading.ffmLbs
            tbwLbs = reading.tbwLbs
            desirableFatPercentLow = reading.desirableFatPercentLow
            desirableFatPercentHigh = reading.desirableFatPercentHigh
            desirableFatMassLow = reading.desirableFatMassLow
            desirableFatMassHigh = reading.desirableFatMassHigh
            notes = reading.notes
        } else {
            visitDate = Date()
            if settings.hasHeight {
                let total = Int(settings.heightInches.rounded())
                heightFeet = max(total / 12, 4)
                heightInchesPart = total % 12
            }
            if let weight = DataStore.weight(for: visitDate, in: modelContext)
                ?? DataStore.recentWeights(limit: 1, in: modelContext).first {
                weightLbs = weight.weightLbs
                if let suggested = BMICalculator.bmi(weightLbs: weightLbs, heightInches: heightInches) {
                    bmi = suggested
                }
            }
            if let prior = DataStore.latestBodyComposition(in: modelContext) {
                bodyType = prior.bodyType
                gender = prior.gender
                age = prior.age
            }
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
        target.bmi = bmi
        target.bmrKcal = bmrKcal
        target.impedance = impedance
        target.fatPercent = fatPercent
        target.fatMassLbs = fatMassLbs
        target.ffmLbs = ffmLbs
        target.tbwLbs = tbwLbs
        target.desirableFatPercentLow = desirableFatPercentLow
        target.desirableFatPercentHigh = desirableFatPercentHigh
        target.desirableFatMassLow = desirableFatMassLow
        target.desirableFatMassHigh = desirableFatMassHigh
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

    /// Prefer the upper bound of a range like `130-236`, else the first integer.
    private func parseProteinGoal(_ text: String) -> Int? {
        let numbers = text.components(separatedBy: CharacterSet.decimalDigits.inverted)
            .compactMap { Int($0) }
            .filter { $0 > 0 }
        return numbers.last
    }

    /// Prefer the first integer in strings like `180+1 OZ`.
    private func parseWaterTarget(_ text: String) -> Int? {
        let numbers = text.components(separatedBy: CharacterSet.decimalDigits.inverted)
            .compactMap { Int($0) }
            .filter { $0 > 0 }
        return numbers.first
    }
}
