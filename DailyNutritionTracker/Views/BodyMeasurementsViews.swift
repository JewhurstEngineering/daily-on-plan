import SwiftUI
import SwiftData
import Charts

struct BodyMeasurementsListView: View {
    var showsDismissButton: Bool = true

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \BodyMeasurementEntry.date, order: .reverse) private var entries: [BodyMeasurementEntry]
    @State private var settings: AppSettings?
    @State private var showAdd = false
    @State private var editing: BodyMeasurementEntry?

    private var usesMetric: Bool { settings?.usesMetricWeight ?? false }

    var body: some View {
        List {
            Section {
                Text("Track tape measurements (waist/stomach, neck, arms, legs) over time. Units follow Settings (in or cm).")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if entries.count >= 2, let chartRows = waistChartRows, !chartRows.isEmpty {
                Section("Waist trend") {
                    Chart {
                        ForEach(chartRows, id: \.date) { row in
                            LineMark(
                                x: .value("Date", row.date),
                                y: .value("Waist", row.value)
                            )
                            PointMark(
                                x: .value("Date", row.date),
                                y: .value("Waist", row.value)
                            )
                        }
                    }
                    .frame(height: 140)
                    .chartYAxisLabel(usesMetric ? "cm" : "in")
                }
            }

            if entries.isEmpty {
                Section {
                    ContentUnavailableView(
                        "No measurements yet",
                        systemImage: "ruler",
                        description: Text("Log neck, waist, arms, and legs to see progress over time.")
                    )
                }
            } else {
                Section("History") {
                    ForEach(entries, id: \.id) { entry in
                        Button {
                            editing = entry
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(DateHelpers.formattedDay(entry.date))
                                    .font(.headline)
                                    .foregroundStyle(.primary)
                                Text(entry.summaryLine(usesMetric: usesMetric))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .onDelete(perform: delete)
                }
            }
        }
        .navigationTitle("Measurements")
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
                .accessibilityLabel("Add measurements")
            }
        }
        .sheet(isPresented: $showAdd) {
            NavigationStack {
                BodyMeasurementEditView(entry: nil, usesMetric: usesMetric)
            }
        }
        .sheet(item: $editing) { entry in
            NavigationStack {
                BodyMeasurementEditView(entry: entry, usesMetric: usesMetric)
            }
        }
        .onAppear {
            settings = DataStore.settings(in: modelContext)
        }
    }

    private var waistChartRows: [(date: Date, value: Double)]? {
        let rows = entries.compactMap { entry -> (Date, Double)? in
            guard let waist = entry.waistInches else { return nil }
            let value = usesMetric ? waist * 2.54 : waist
            return (entry.date, value)
        }
        .sorted { $0.0 < $1.0 }
        return rows.isEmpty ? nil : rows.map { (date: $0.0, value: $0.1) }
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(entries[index])
        }
        try? modelContext.save()
    }
}

extension BodyMeasurementEntry: Identifiable {}

struct BodyMeasurementEditView: View {
    var entry: BodyMeasurementEntry?
    var usesMetric: Bool

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var measureDate = Date()
    @State private var neckText = ""
    @State private var chestText = ""
    @State private var waistText = ""
    @State private var hipsText = ""
    @State private var leftArmText = ""
    @State private var rightArmText = ""
    @State private var leftThighText = ""
    @State private var rightThighText = ""
    @State private var notes = ""
    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case neck, chest, waist, hips, leftArm, rightArm, leftThigh, rightThigh, notes
    }

    private var unitLabel: String { usesMetric ? "cm" : "in" }

    private var canSave: Bool {
        [
            parse(neckText), parse(chestText), parse(waistText), parse(hipsText),
            parse(leftArmText), parse(rightArmText), parse(leftThighText), parse(rightThighText)
        ].contains { $0 != nil }
    }

    var body: some View {
        Form {
            Section {
                DatePicker("Date", selection: $measureDate, displayedComponents: .date)
            }

            Section {
                measureRow("Neck", text: $neckText, field: .neck)
                measureRow("Chest", text: $chestText, field: .chest)
                measureRow("Waist / stomach", text: $waistText, field: .waist)
                measureRow("Hips", text: $hipsText, field: .hips)
            } header: {
                Text("Torso")
            } footer: {
                Text("Enter values in \(unitLabel). Leave blank to skip.")
            }

            Section("Arms") {
                measureRow("Left arm", text: $leftArmText, field: .leftArm)
                measureRow("Right arm", text: $rightArmText, field: .rightArm)
            }

            Section("Legs") {
                measureRow("Left thigh", text: $leftThighText, field: .leftThigh)
                measureRow("Right thigh", text: $rightThighText, field: .rightThigh)
            }

            Section("Notes") {
                TextField("Optional notes", text: $notes, axis: .vertical)
                    .lineLimit(3...6)
                    .focused($focusedField, equals: .notes)
            }
        }
        .navigationTitle(entry == nil ? "Add measurements" : "Edit measurements")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { save() }
                    .disabled(!canSave)
            }
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { focusedField = nil }
            }
        }
        .onAppear { load() }
    }

    private func measureRow(_ title: String, text: Binding<String>, field: Field) -> some View {
        HStack {
            Text(title)
            Spacer()
            TextField("—", text: text)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .focused($focusedField, equals: field)
                .frame(maxWidth: 100)
            Text(unitLabel)
                .foregroundStyle(.secondary)
        }
    }

    private func load() {
        guard let entry else { return }
        measureDate = entry.date
        neckText = display(entry.neckInches)
        chestText = display(entry.chestInches)
        waistText = display(entry.waistInches)
        hipsText = display(entry.hipsInches)
        leftArmText = display(entry.leftArmInches)
        rightArmText = display(entry.rightArmInches)
        leftThighText = display(entry.leftThighInches)
        rightThighText = display(entry.rightThighInches)
        notes = entry.notes
    }

    private func display(_ inches: Double?) -> String {
        guard let inches else { return "" }
        let value = usesMetric ? inches * 2.54 : inches
        return String(format: "%.1f", value)
    }

    private func parse(_ text: String) -> Double? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: ".")
        guard let value = Double(trimmed), value > 0 else { return nil }
        return usesMetric ? value / 2.54 : value
    }

    private func save() {
        focusedField = nil
        let target = entry ?? BodyMeasurementEntry()
        if entry == nil {
            modelContext.insert(target)
        }
        target.date = DateHelpers.startOfDay(measureDate)
        target.neckInches = parse(neckText)
        target.chestInches = parse(chestText)
        target.waistInches = parse(waistText)
        target.hipsInches = parse(hipsText)
        target.leftArmInches = parse(leftArmText)
        target.rightArmInches = parse(rightArmText)
        target.leftThighInches = parse(leftThighText)
        target.rightThighInches = parse(rightThighText)
        target.notes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        try? modelContext.save()
        dismiss()
    }
}
