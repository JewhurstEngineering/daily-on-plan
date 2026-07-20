import SwiftUI
import SwiftData

struct DayHeaderSection: View {
    @Binding var selectedDate: Date
    @Bindable var log: DailyLog
    let settings: AppSettings
    @Environment(\.modelContext) private var modelContext
    @State private var showNotes = false

    private var notesPreview: String {
        let trimmed = log.notes.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }
        if trimmed.count <= 40 { return trimmed }
        return String(trimmed.prefix(40)) + "…"
    }

    var body: some View {
        SectionCard(title: "Daily Status", systemImage: "calendar") {
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
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Protein Goal")
                            .font(.subheadline.weight(.semibold))
                        Stepper(
                            "\(log.proteinGoal) kcal",
                            value: $log.proteinGoal,
                            in: AppLimits.proteinGoalMin...AppLimits.proteinGoalMax,
                            step: AppLimits.proteinGoalStep
                        )
                        .font(.subheadline)
                    }

                    Toggle(isOn: $log.ketosis) {
                        Text("Ketosis")
                            .font(.subheadline.weight(.medium))
                    }
                    .tint(.green)

                    Toggle(isOn: $log.followedPlan) {
                        Text("Followed Plan")
                            .font(.subheadline.weight(.medium))
                    }
                    .tint(.green)
                }
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
        .onChange(of: log.proteinGoal) { _, _ in try? modelContext.save() }
        .onChange(of: log.ketosis) { _, _ in try? modelContext.save() }
        .onChange(of: log.followedPlan) { _, _ in try? modelContext.save() }
        .onChange(of: log.notes) { _, _ in try? modelContext.save() }
    }
}
