import SwiftUI
import SwiftData

struct DayHeaderSection: View {
    @Binding var selectedDate: Date
    @Bindable var log: DailyLog
    @Bindable var settings: AppSettings
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accentTheme) private var theme
    @Environment(\.accentPrimary) private var accentPrimary
    @State private var showNotes = false
    @State private var customReason = ""
    @State private var showCustomReason = false

    private var notesPreview: String {
        let trimmed = log.notes.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }
        if trimmed.count <= 40 { return trimmed }
        return String(trimmed.prefix(40)) + "…"
    }

    var body: some View {
        SectionCard(
            title: "Daily Status",
            systemImage: "calendar",
            isCollapsed: settings.sectionCollapsedBinding(.dailyStatus, context: modelContext),
            collapsedMessage: DaySectionID.dailyStatus.collapsedMessage
        ) {
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

            HStack(alignment: .center, spacing: 20) {
                CalorieRingView(current: log.totalProteinCalories, goal: log.proteinGoal)
                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Protein Goal")
                            .font(.subheadline.weight(.semibold))
                        Text("\(log.proteinGoal) kcal")
                            .font(.title3.monospacedDigit().weight(.semibold))
                        Text("Change in Settings")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    Toggle(isOn: $log.ketosis) {
                        Text("Ketosis")
                            .font(.subheadline.weight(.medium))
                    }
                    .tint(accentPrimary)

                    Toggle(isOn: $log.followedPlan) {
                        Text("Followed Plan")
                            .font(.subheadline.weight(.medium))
                    }
                    .tint(theme.success)
                }
            }

            Text("Ketosis is usually checked with urine strips, a blood ketone meter, or breath — or logged as your best guess if you don’t test. This app doesn’t measure it for you.")
                .font(.caption2)
                .foregroundStyle(.secondary)

            if !log.followedPlan {
                offPlanReasonsBlock
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
        }
        .onChange(of: selectedDate) { _, _ in
            syncProteinGoalFromSettings()
        }
        .onChange(of: settings.defaultProteinGoal) { _, _ in
            syncProteinGoalFromSettings()
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

/// Simple wrapping chip row without a FlowLayout dependency.
private struct FlowReasonChips: View {
    let options: [String]
    let selected: [String]
    let onToggle: (String) -> Void

    var body: some View {
        FlexibleChipWrap(options: options, selected: selected, onToggle: onToggle)
    }
}

private struct FlexibleChipWrap: View {
    let options: [String]
    let selected: [String]
    let onToggle: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(rows, id: \.self) { row in
                HStack(spacing: 8) {
                    ForEach(row, id: \.self) { option in
                        let isOn = selected.contains(where: { $0.caseInsensitiveCompare(option) == .orderedSame })
                        Button(option) {
                            onToggle(option)
                        }
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(isOn ? Color.accentColor : Color(.tertiarySystemFill))
                        .foregroundStyle(isOn ? Color.white : Color.primary)
                        .clipShape(Capsule())
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    /// Rough wrap into rows of ~3 chips for readability.
    private var rows: [[String]] {
        stride(from: 0, to: options.count, by: 3).map { start in
            Array(options[start..<min(start + 3, options.count)])
        }
    }
}
