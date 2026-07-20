import SwiftUI
import SwiftData

struct WorkoutSection: View {
    @Bindable var log: DailyLog
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var healthKit: HealthKitService
    @State private var showAdd = false

    var body: some View {
        SectionCard(title: "Workouts", systemImage: "figure.run") {
            Button {
                showAdd = true
            } label: {
                Label("Add workout", systemImage: "plus.circle.fill")
            }
            .buttonStyle(.bordered)

            if log.sortedWorkouts.isEmpty {
                Text("Log multiple sessions per day.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(log.sortedWorkouts, id: \.id) { workout in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(workout.activityName)
                                .font(.subheadline.weight(.semibold))
                            Text(DateHelpers.formattedTime(workout.timeLogged))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text("\(workout.durationMinutes) min")
                            .font(.subheadline.monospacedDigit())
                        Button(role: .destructive) {
                            log.workoutEntries.removeAll { $0.id == workout.id }
                            modelContext.delete(workout)
                            try? modelContext.save()
                        } label: {
                            Image(systemName: "trash")
                        }
                    }
                    Divider()
                }
            }
        }
        .sheet(isPresented: $showAdd) {
            AddWorkoutSheet(log: log)
        }
    }
}

struct AddWorkoutSheet: View {
    @Bindable var log: DailyLog
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var healthKit: HealthKitService

    @State private var name = "Brisk walking"
    @State private var minutes = 30

    private let suggestions = ["Interactive Exercise", "Brisk walking", "Strength training", "Cycling", "Yoga"]

    var body: some View {
        NavigationStack {
            Form {
                Section("Activity") {
                    TextField("Activity name", text: $name)
                    Picker("Suggestions", selection: $name) {
                        ForEach(suggestions, id: \.self) { Text($0).tag($0) }
                    }
                }
                Section("Duration") {
                    Stepper("\(minutes) minutes", value: $minutes, in: 5...300, step: 5)
                }
            }
            .navigationTitle("Add Workout")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let entry = WorkoutEntry(activityName: name, durationMinutes: minutes)
                        modelContext.insert(entry)
                        log.workoutEntries.append(entry)
                        try? modelContext.save()
                        Task {
                            await healthKit.writeWorkout(name: name, durationMinutes: minutes, on: Date())
                        }
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}
