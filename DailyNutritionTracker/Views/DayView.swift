import SwiftUI
import SwiftData

struct DayView: View {
    @Binding var selectedDate: Date
    var onOpenSettings: (() -> Void)? = nil
    @Binding var pendingScrollSection: String?
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var healthKit: HealthKitService

    @State private var recentWeights: [WeightEntry] = []
    @State private var didSyncHealth = false
    @State private var scrollTarget: String?
    @State private var scrollToken = UUID()

    init(
        selectedDate: Binding<Date>,
        onOpenSettings: (() -> Void)? = nil,
        pendingScrollSection: Binding<String?> = .constant(nil)
    ) {
        self._selectedDate = selectedDate
        self.onOpenSettings = onOpenSettings
        self._pendingScrollSection = pendingScrollSection
    }

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
                    if settings.smokingMode.showsSection {
                        SmokingSection(
                            log: log,
                            settings: settings,
                            recentLogs: DataStore.logs(
                                from: Calendar.current.date(byAdding: .day, value: -120, to: selectedDate) ?? selectedDate,
                                to: selectedDate,
                                in: modelContext
                            ),
                            onOpenSettings: onOpenSettings
                        )
                        .id("smoking")
                    }
                    if settings.drinkingMode.showsSection {
                        DrinkingSection(
                            log: log,
                            settings: settings,
                            recentLogs: DataStore.logs(
                                from: Calendar.current.date(byAdding: .day, value: -120, to: selectedDate) ?? selectedDate,
                                to: selectedDate,
                                in: modelContext
                            ),
                            onOpenSettings: onOpenSettings
                        )
                        .id("drinking")
                    }
                    FeelingsSection(log: log, settings: settings)
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
                    WorkoutSection(log: log, settings: settings)
                        .id("workouts")
                    HydrationSection(
                        log: log,
                        settings: settings,
                        date: selectedDate,
                        onOpenSettings: onOpenSettings
                    )
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
            .onChange(of: pendingScrollSection) { _, section in
                guard let section else { return }
                requestScroll(to: section)
                pendingScrollSection = nil
            }
        }
        .onAppear {
            recentWeights = DataStore.recentWeights(in: modelContext)
            syncHealthIfNeeded(log: log, todayWeight: todayWeight)
            if let section = pendingScrollSection {
                requestScroll(to: section)
                pendingScrollSection = nil
            }
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
                if log.waterSlots.allSatisfy({ $0 == nil }) && log.waterOz == 0 && hkWater > 0 {
                    let settings = DataStore.settings(in: modelContext)
                    let bottle = max(settings.defaultBottleOz, 1)
                    let slots = max(1, Int(ceil(Double(settings.hydrationTargetOz) / bottle)))
                    log.ensureWaterSlotCount(slots)
                    log.toggleWaterSlot(at: 0, fillOz: Double(hkWater))
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
