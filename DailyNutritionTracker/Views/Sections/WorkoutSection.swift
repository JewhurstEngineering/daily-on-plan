import SwiftUI
import SwiftData

struct WorkoutSection: View {
    @Bindable var log: DailyLog
    let settings: AppSettings
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accentPrimary) private var accentPrimary
    @EnvironmentObject private var healthKit: HealthKitService
    @State private var showAdd = false
    @State private var chips: [SuggestionItem] = []
    @State private var pendingName = "Brisk walking"
    @State private var editTimeWorkout: WorkoutEntry?

    var body: some View {
        SectionCard(
            title: "Workouts",
            systemImage: "figure.run",
            isCollapsed: settings.sectionCollapsedBinding(.workouts, context: modelContext),
            collapsedMessage: DaySectionID.workouts.collapsedMessage
        ) {
            if !chips.isEmpty {
                Text(hasHistory ? "Popular & recent" : "Suggestions")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                SuggestionChipRow(items: chips) { item in
                    pendingName = item.name
                    showAdd = true
                }
            }

            Button {
                pendingName = "Brisk walking"
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
                            Button(DateHelpers.formattedTime(workout.timeLogged)) {
                                editTimeWorkout = workout
                            }
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(accentPrimary)
                            .buttonStyle(.plain)
                        }
                        Spacer()
                        Text("\(workout.durationMinutes) min")
                            .font(.subheadline.monospacedDigit())
                        Button(role: .destructive) {
                            log.workoutEntries.removeAll { $0.id == workout.id }
                            modelContext.delete(workout)
                            try? modelContext.save()
                            refreshChips()
                        } label: {
                            Image(systemName: "trash")
                        }
                    }
                    Divider()
                }
            }
        }
        .sheet(isPresented: $showAdd) {
            AddWorkoutSheet(log: log, initialName: pendingName) {
                refreshChips()
            }
        }
        .sheet(item: $editTimeWorkout) { workout in
            EditTimestampSheet(
                title: workout.activityName,
                initialDate: workout.timeLogged,
                includesDate: true
            ) { newDate in
                moveWorkout(workout, to: newDate)
            }
        }
        .onAppear { refreshChips() }
    }

    private var hasHistory: Bool {
        !((try? modelContext.fetch(FetchDescriptor<DailyLog>())) ?? []).flatMap(\.workoutEntries).isEmpty
    }

    private func refreshChips() {
        chips = UsageSuggestions.workoutChips(in: modelContext)
    }

    private func moveWorkout(_ workout: WorkoutEntry, to newDate: Date) {
        let targetDay = DateHelpers.startOfDay(newDate)
        let sourceDay = DateHelpers.startOfDay(log.date)
        workout.timeLogged = newDate
        if targetDay != sourceDay {
            log.workoutEntries.removeAll { $0.id == workout.id }
            let targetLog = DataStore.log(for: targetDay, in: modelContext, defaultGoal: settings.defaultProteinGoal)
            targetLog.workoutEntries.append(workout)
        }
        try? modelContext.save()
        refreshChips()
    }
}

extension WorkoutEntry: Identifiable {}

struct AddWorkoutSheet: View {
    @Bindable var log: DailyLog
    var initialName: String = "Brisk walking"
    var onSaved: (() -> Void)? = nil
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var healthKit: HealthKitService

    @State private var name = ""
    @State private var minutes = 30

    private let suggestions = [
        "Interactive Exercise", "Brisk walking", "Strength training", "Cycling", "Yoga",
        "Swimming", "Running", "Cardio", "Calisthenics"
    ]

    var body: some View {
        NavigationStack {
            Form {
                Section("Activity") {
                    TextField("Activity name", text: $name)
                    Picker("Suggestions", selection: $name) {
                        ForEach(suggestions, id: \.self) { suggestion in
                            Text(suggestion).tag(suggestion)
                        }
                    }
                    .pickerStyle(.menu)
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
                        Keyboard.dismiss()
                        let entry = WorkoutEntry(activityName: name, durationMinutes: minutes)
                        modelContext.insert(entry)
                        log.workoutEntries.append(entry)
                        try? modelContext.save()
                        Task {
                            await healthKit.writeWorkout(name: name, durationMinutes: minutes, on: Date())
                        }
                        onSaved?()
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear {
                if name.isEmpty { name = initialName }
            }
        }
    }
}
