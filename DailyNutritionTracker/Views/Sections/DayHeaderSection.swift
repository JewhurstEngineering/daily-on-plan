import SwiftUI
import SwiftData

struct DayHeaderSection: View {
    @Binding var selectedDate: Date
    @Bindable var log: DailyLog
    let settings: AppSettings
    @Environment(\.modelContext) private var modelContext
    @State private var showNotes = false

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
                    Stepper("Goal \(log.proteinGoal)", value: $log.proteinGoal, in: 100...1200, step: 25)
                        .font(.subheadline)

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

            Button {
                showNotes.toggle()
            } label: {
                Label(log.notes.isEmpty ? "Add notes" : "Edit notes", systemImage: "note.text")
            }
            .buttonStyle(.bordered)

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
