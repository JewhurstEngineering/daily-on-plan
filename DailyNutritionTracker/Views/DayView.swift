import SwiftUI
import SwiftData

struct DayView: View {
    @Binding var selectedDate: Date
    var onOpenSettings: (() -> Void)? = nil
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var healthKit: HealthKitService

    @State private var recentWeights: [WeightEntry] = []
    @State private var didSyncHealth = false
    @State private var scrollTarget: String?
    @State private var scrollToken = UUID()

    private func requestScroll(to anchor: String) {
        scrollTarget = anchor
        scrollToken = UUID()
    }

    var body: some View {
        let settings = DataStore.settings(in: modelContext)
        let log = DataStore.log(for: selectedDate, in: modelContext, defaultGoal: settings.defaultProteinGoal)
        let todayWeight = DataStore.weight(for: selectedDate, in: modelContext)

        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    DayHeaderSection(selectedDate: $selectedDate, log: log, settings: settings)
                        .id("header")
                    WeightBMISection(
                        selectedDate: selectedDate,
                        weight: todayWeight,
                        recentWeights: recentWeights,
                        settings: settings,
                        onSave: { lbs in
                            saveWeight(lbs, existing: todayWeight)
                        },
                        onOpenSettings: onOpenSettings
                    )
                    .id("weight")
                    FeelingsSection(log: log)
                        .id("feelings")
                    ProteinSection(
                        log: log,
                        settings: settings,
                        scrollAnchor: "protein",
                        onWillPresentSheet: { requestScroll(to: $0) }
                    )
                    .id("protein")
                    ChecklistSection(
                        log: log,
                        settings: settings,
                        scrollAnchor: "checklist",
                        onWillPresentSheet: { requestScroll(to: $0) }
                    )
                    .id("checklist")
                    WorkoutSection(log: log)
                        .id("workouts")
                    HydrationSection(log: log, settings: settings, date: selectedDate)
                        .id("hydration")
                    if settings.showSupplementsSection {
                        SupplementsSection(log: log, settings: settings)
                            .id("supplements")
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .onChange(of: scrollToken) { _, _ in
                guard let scrollTarget else { return }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    withAnimation(.easeOut(duration: 0.25)) {
                        proxy.scrollTo(scrollTarget, anchor: .center)
                    }
                }
            }
        }
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
                // Only seed total if we have no per-drink history yet.
                if log.waterDrinks.isEmpty {
                    log.waterDrinks = [Double(hkWater)]
                    try? modelContext.save()
                }
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
