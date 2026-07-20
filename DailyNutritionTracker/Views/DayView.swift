import SwiftUI
import SwiftData

struct DayView: View {
    @Binding var selectedDate: Date
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var healthKit: HealthKitService

    @State private var recentWeights: [WeightEntry] = []
    @State private var didSyncHealth = false

    var body: some View {
        let settings = DataStore.settings(in: modelContext)
        let log = DataStore.log(for: selectedDate, in: modelContext, defaultGoal: settings.defaultProteinGoal)
        let todayWeight = DataStore.weight(for: selectedDate, in: modelContext)

        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                DayHeaderSection(selectedDate: $selectedDate, log: log, settings: settings)
                WeightBMISection(
                    selectedDate: selectedDate,
                    weight: todayWeight,
                    recentWeights: recentWeights,
                    settings: settings,
                    onSave: { lbs in
                        saveWeight(lbs, existing: todayWeight)
                    }
                )
                FeelingsSection(log: log)
                ProteinSection(log: log, settings: settings)
                ChecklistSection(log: log, settings: settings)
                WorkoutSection(log: log)
                HydrationSection(log: log, date: selectedDate)
                SupplementsSection(log: log, settings: settings)
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .onAppear {
            recentWeights = DataStore.recentWeights(in: modelContext)
            syncHealthIfNeeded(log: log, todayWeight: todayWeight)
        }
        .onChange(of: selectedDate) { _, _ in
            didSyncHealth = false
            recentWeights = DataStore.recentWeights(in: modelContext)
            let settings = DataStore.settings(in: modelContext)
            let log = DataStore.log(for: selectedDate, in: modelContext, defaultGoal: settings.defaultProteinGoal)
            let todayWeight = DataStore.weight(for: selectedDate, in: modelContext)
            syncHealthIfNeeded(log: log, todayWeight: todayWeight)
        }
    }

    private func syncHealthIfNeeded(log: DailyLog, todayWeight: WeightEntry?) {
        guard !didSyncHealth else { return }
        didSyncHealth = true
        Task {
            if let hkWater = await healthKit.readWaterOunces(on: selectedDate), hkWater > log.waterOz {
                log.waterOz = hkWater
                try? modelContext.save()
            }
            if todayWeight == nil, let hkWeight = await healthKit.readBodyMassPounds(on: selectedDate) {
                saveWeight(hkWeight, existing: nil)
            }
        }
    }

    private func saveWeight(_ lbs: Double, existing: WeightEntry?) {
        if let existing {
            existing.weightLbs = lbs
            existing.timeLogged = Date()
        } else {
            let entry = WeightEntry(date: selectedDate, weightLbs: lbs)
            modelContext.insert(entry)
        }
        try? modelContext.save()
        recentWeights = DataStore.recentWeights(in: modelContext)
        Task {
            await healthKit.writeBodyMass(pounds: lbs, on: selectedDate)
        }
    }
}
