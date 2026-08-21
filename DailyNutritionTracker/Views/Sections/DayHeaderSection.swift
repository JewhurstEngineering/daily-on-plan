import SwiftUI
import SwiftData

struct DayHeaderSection: View {
    @Binding var selectedDate: Date
    @Bindable var log: DailyLog
    @Bindable var settings: AppSettings
    @Environment(\.modelContext) private var modelContext
    @Environment(\.appTheme) private var appTheme
    @Environment(\.accentPrimary) private var accentPrimary
    @State private var showNotes = false
    @State private var customReason = ""
    @State private var showCustomReason = false
    @State private var ketoneText = ""
    @State private var extraCarbText = ""
    @State private var extraFatText = ""
    @State private var extraKcalText = ""

    private var notesPreview: String {
        let trimmed = log.notes.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }
        if trimmed.count <= 40 { return trimmed }
        return String(trimmed.prefix(40)) + "…"
    }

    @Environment(\.sectionChrome) private var chrome

    var body: some View {
        SectionCard(
            title: "Daily Status",
            systemImage: "calendar",
            isCollapsed: settings.sectionCollapsedBinding(.dailyStatus, context: modelContext),
            collapsedMessage: DaySectionID.dailyStatus.collapsedMessage
        ) {
            // Today owns the date stepper now. On a pushed detail screen the binding is a
            // constant, so showing arrows here would be dead controls.
            if chrome == .card {
                HStack {
                    Button {
                        selectedDate = Calendar.current.date(byAdding: .day, value: -1, to: selectedDate) ?? selectedDate
                    } label: {
                        Image(systemName: "chevron.left.circle.fill")
                            .font(.title2)
                    }
                    Spacer()
                    VStack(spacing: 4) {
                        Text(DateHelpers.formattedDay(selectedDate))
                            .font(.title3.bold())
                        if Calendar.current.isDateInToday(selectedDate) {
                            Text("Today")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    Button {
                        selectedDate = Calendar.current.date(byAdding: .day, value: 1, to: selectedDate) ?? selectedDate
                    } label: {
                        Image(systemName: "chevron.right.circle.fill")
                            .font(.title2)
                    }
                    .disabled(Calendar.current.isDateInToday(selectedDate) || selectedDate > Date())
                }
            }

            VStack(alignment: .leading, spacing: 12) {
                Toggle(isOn: $log.ketosis) {
                    Text("Ketosis")
                        .font(.subheadline.weight(.medium))
                }
                .tint(accentPrimary)

                HStack {
                    Text("Reading")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("mmol/L", text: $ketoneText)
                        .textFieldStyle(.roundedBorder)
                        .onPlanKeyboard(.decimalPad)
                        .frame(maxWidth: 100)
                    Text("mmol/L")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Toggle(isOn: $log.followedPlan) {
                    Text("Followed Plan")
                        .font(.subheadline.weight(.medium))
                }
                .tint(appTheme.ok)
            }

            if !settings.fastingEnabled {
                eatingWindowBlock
            }

            Text("Ketosis is usually checked with urine strips, a blood ketone meter, or breath — or logged as your best guess if you don’t test. This app doesn’t measure it for you.")
                .font(.caption2)
                .foregroundStyle(.secondary)

            if !log.followedPlan {
                offPlanReasonsBlock
                offPlanExtrasBlock
            }

            HStack(alignment: .center, spacing: 12) {
                Button {
                    showNotes.toggle()
                } label: {
                    Label(log.notes.isEmpty ? "Add notes" : "Edit notes", systemImage: "note.text")
                }
                .buttonStyle(.bordered)

                if !log.notes.isEmpty {
                    HStack(spacing: 6) {
                        Image(systemName: "text.quote")
                            .foregroundStyle(Color.accentColor)
                        Text(notesPreview)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            if showNotes {
                TextField("Daily observations…", text: $log.notes, axis: .vertical)
                    .lineLimit(3...6)
                    .textFieldStyle(.roundedBorder)
            }
        }
        .onChange(of: log.ketosis) { _, _ in try? modelContext.save() }
        .onChange(of: log.followedPlan) { _, followed in
            if followed {
                log.offPlanReasons = []
            }
            try? modelContext.save()
        }
        .onChange(of: log.notes) { _, _ in try? modelContext.save() }
        .onAppear {
            syncProteinGoalFromSettings()
            ketoneText = log.ketoneMmol.map { String(format: $0 == $0.rounded() ? "%.0f" : "%.1f", $0) } ?? ""
            extraCarbText = log.offPlanExtraCarbGrams > 0 ? String(format: "%.0f", log.offPlanExtraCarbGrams) : ""
            extraFatText = log.offPlanExtraFatGrams > 0 ? String(format: "%.0f", log.offPlanExtraFatGrams) : ""
            extraKcalText = log.offPlanExtraKcal > 0 ? "\(log.offPlanExtraKcal)" : ""
        }
        .onChange(of: ketoneText) { _, value in
            let parsed = Double(value.replacingOccurrences(of: ",", with: "."))
            log.ketoneMmol = parsed
            try? modelContext.save()
        }
        .onChange(of: selectedDate) { _, _ in
            syncProteinGoalFromSettings()
        }
        .onChange(of: settings.defaultProteinGoal) { _, _ in
            syncProteinGoalFromSettings()
        }
    }

    private var eatingWindowBlock: some View {
        HStack {
            if let start = log.eatingWindowStart {
                Label("Eating since \(DateHelpers.formattedTime(start))", systemImage: "clock")
                    .font(.caption)
                Spacer()
                if log.eatingWindowEnd == nil {
                    Button("End window") {
                        log.eatingWindowEnd = Date()
                        modelContext.saveAndNotifyJournal()
                    }
                    .font(.caption.weight(.semibold))
                } else if let end = log.eatingWindowEnd {
                    Text("to \(DateHelpers.formattedTime(end))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Button("Clear") {
                        log.eatingWindowStart = nil
                        log.eatingWindowEnd = nil
                        modelContext.saveAndNotifyJournal()
                    }
                    .font(.caption)
                }
            } else {
                Button("Start eating") {
                    log.eatingWindowStart = Date()
                    log.eatingWindowEnd = nil
                    modelContext.saveAndNotifyJournal()
                }
                .font(.caption.weight(.semibold))
            }
        }
    }

    private var offPlanExtrasBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Extras (optional)")
                .font(.subheadline.weight(.semibold))
            Text("Carb/fat grams and extra kcal for off-plan food. Not a second calorie ring.")
                .font(.caption2)
                .foregroundStyle(.secondary)
            HStack {
                extraField("Carb g", text: $extraCarbText) {
                    log.offPlanExtraCarbGrams = Double(extraCarbText.replacingOccurrences(of: ",", with: ".")) ?? 0
                    try? modelContext.save()
                }
                extraField("Fat g", text: $extraFatText) {
                    log.offPlanExtraFatGrams = Double(extraFatText.replacingOccurrences(of: ",", with: ".")) ?? 0
                    try? modelContext.save()
                }
                extraField("Kcal", text: $extraKcalText) {
                    log.offPlanExtraKcal = Int(extraKcalText) ?? 0
                    try? modelContext.save()
                }
            }
            let rolled = FoodCatalog.checklistCalories(for: log, phase: settings.phase)
            Text("Checked servings ≈ veg \(rolled.vegetable) · fat \(rolled.fat) · fruit \(rolled.fruit) · misc \(rolled.misc) kcal")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 4)
    }

    private func extraField(_ title: String, text: Binding<String>, save: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            TextField("0", text: text)
                .textFieldStyle(.roundedBorder)
                .onPlanKeyboard(.decimalPad)
                .onChange(of: text.wrappedValue) { _, _ in save() }
        }
    }

    private func syncProteinGoalFromSettings() {
        guard Calendar.current.isDateInToday(selectedDate) else { return }
        guard log.proteinGoal != settings.defaultProteinGoal else { return }
        log.proteinGoal = settings.defaultProteinGoal
        try? modelContext.save()
    }

    private var offPlanReasonsBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("What threw you off?")
                .font(.subheadline.weight(.semibold))
            Text("Tap one or more. These are counted in reports (e.g. how often pizza vs beer).")
                .font(.caption2)
                .foregroundStyle(.secondary)

            FlowReasonChips(
                options: settings.allOffPlanReasonOptions,
                selected: log.offPlanReasons
            ) { reason in
                log.toggleOffPlanReason(reason)
                try? modelContext.save()
            }

            if showCustomReason {
                HStack {
                    TextField("Custom reason", text: $customReason)
                        .textFieldStyle(.roundedBorder)
                        .onChange(of: customReason) { _, newValue in
                            if newValue.count > OffPlanReasonCatalog.maxCustomLength {
                                customReason = String(newValue.prefix(OffPlanReasonCatalog.maxCustomLength))
                            }
                        }
                    Button("Add") {
                        addCustomReason()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(customReason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            } else {
                Button("Add custom…") {
                    showCustomReason = true
                }
                .font(.caption.weight(.semibold))
            }
        }
        .padding(.top, 4)
    }

    private func addCustomReason() {
        guard let reason = settings.addCustomOffPlanReason(customReason) else { return }
        if !log.offPlanReasons.contains(where: { $0.caseInsensitiveCompare(reason) == .orderedSame }) {
            log.toggleOffPlanReason(reason)
        }
        customReason = ""
        showCustomReason = false
        try? modelContext.save()
    }
}

/// Wraps chips to fit the available width (via `FlowLayout`) instead of a fixed rows-of-3 split,
/// so it adapts on wider devices instead of under/over-filling rows.
private struct FlowReasonChips: View {
    let options: [String]
    let selected: [String]
    let onToggle: (String) -> Void
    @Environment(\.accentPrimary) private var accentPrimary

    var body: some View {
        FlowLayout(spacing: Spacing.s, rowSpacing: Spacing.s) {
            ForEach(options, id: \.self) { option in
                let isOn = selected.contains(where: { $0.caseInsensitiveCompare(option) == .orderedSame })
                Button(option) {
                    onToggle(option)
                }
                .font(.caption.weight(.semibold))
                .chipStyle(fill: isOn ? .solid(accentPrimary) : .neutral, shape: .capsule)
                .buttonStyle(.plain)
            }
        }
    }
}
