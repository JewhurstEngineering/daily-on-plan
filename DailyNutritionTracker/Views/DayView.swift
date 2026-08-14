import SwiftUI
import SwiftData

struct DayView: View {
    @Binding var selectedDate: Date
    var onOpenSettings: (() -> Void)? = nil
    var onOpenBodyComposition: (() -> Void)? = nil
    var onOpenBodyMeasurements: (() -> Void)? = nil
    @Binding var pendingScrollSection: String?
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var healthKit: HealthKitService
    @Environment(\.horizontalSizeClass) private var sizeClass

    @State private var recentWeights: [WeightEntry] = []
    @State private var didSyncHealth = false
    @State private var scrollTarget: String?
    @State private var scrollToken = UUID()

    init(
        selectedDate: Binding<Date>,
        onOpenSettings: (() -> Void)? = nil,
        onOpenBodyComposition: (() -> Void)? = nil,
        onOpenBodyMeasurements: (() -> Void)? = nil,
        pendingScrollSection: Binding<String?> = .constant(nil)
    ) {
        self._selectedDate = selectedDate
        self.onOpenSettings = onOpenSettings
        self.onOpenBodyComposition = onOpenBodyComposition
        self.onOpenBodyMeasurements = onOpenBodyMeasurements
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
        let recentLogs = DataStore.logs(
            from: Calendar.current.date(byAdding: .day, value: -120, to: selectedDate) ?? selectedDate,
            to: selectedDate,
            in: modelContext
        )

        ScrollViewReader { proxy in
            let sections = ForEach(settings.sectionOrder, id: \.self) { section in
                sectionView(
                    section,
                    settings: settings,
                    log: log,
                    todayWeight: todayWeight,
                    recentLogs: recentLogs
                )
            }
            Group {
                if sizeClass == .regular {
                    HStack(alignment: .top, spacing: 16) {
                        ScrollView {
                            DayHeaderSection(selectedDate: $selectedDate, log: log, settings: settings)
                                .id("header")
                                .padding()
                        }
                        .frame(minWidth: 320, maxWidth: 420)
                        ScrollView {
                            VStack(alignment: .leading, spacing: 20) {
                                sections
                            }
                            .padding()
                        }
                    }
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            DayHeaderSection(selectedDate: $selectedDate, log: log, settings: settings)
                                .id("header")
                            sections
                        }
                        .padding()
                    }
                }
            }
            .background(Color.onPlanGroupedBackground)
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

    @ViewBuilder
    private func sectionView(
        _ section: DaySectionID,
        settings: AppSettings,
        log: DailyLog,
        todayWeight: WeightEntry?,
        recentLogs: [DailyLog]
    ) -> some View {
        switch section {
        case .dailyStatus:
            EmptyView()
        case .weight:
            WeightBMISection(
                selectedDate: selectedDate,
                weight: todayWeight,
                recentWeights: recentWeights,
                settings: settings,
                onSave: { lbs in
                    saveWeight(lbs, existing: todayWeight)
                },
                onOpenSettings: onOpenSettings,
                onOpenBodyComposition: onOpenBodyComposition,
                onOpenBodyMeasurements: onOpenBodyMeasurements
            )
            .id("weight")
        case .smoking:
            if settings.smokingMode.showsSection {
                SmokingSection(
                    log: log,
                    settings: settings,
                    recentLogs: recentLogs,
                    onOpenSettings: onOpenSettings
                )
                .id("smoking")
            }
        case .drinking:
            if settings.drinkingMode.showsSection {
                DrinkingSection(
                    log: log,
                    settings: settings,
                    recentLogs: recentLogs,
                    onOpenSettings: onOpenSettings
                )
                .id("drinking")
            }
        case .feelings:
            FeelingsSection(log: log, settings: settings)
                .id("feelings")
        case .protein:
            ProteinSection(
                log: log,
                settings: settings,
                scrollAnchor: "protein",
                onWillPresentSheet: { requestScroll(to: $0) }
            )
            .id("protein")
        case .fasting:
            if settings.fastingEnabled {
                FastingSection(log: log, settings: settings)
                    .id("fasting")
            }
        case .checklist:
            ChecklistSection(
                log: log,
                settings: settings,
                scrollAnchor: "checklist",
                onWillPresentSheet: { requestScroll(to: $0) }
            )
            .id("checklist")
        case .workouts:
            WorkoutSection(log: log, settings: settings)
                .id("workouts")
        case .hydration:
            HydrationSection(
                log: log,
                settings: settings,
                date: selectedDate,
                onOpenSettings: onOpenSettings
            )
            .id("hydration")
        case .bathroom:
            if settings.showBathroomSection {
                BathroomSection(log: log, settings: settings)
                    .id("bathroom")
            }
        case .supplements:
            if settings.showSupplementsSection {
                SupplementsSection(log: log, settings: settings)
                    .id("supplements")
            }
        }
    }

    private func syncHealthIfNeeded(log: DailyLog, todayWeight: WeightEntry?) {
        guard !didSyncHealth else { return }
        didSyncHealth = true
        Task {
            if let hkWater = await healthKit.readWaterOunces(on: selectedDate), hkWater > log.waterOz {
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
            await healthKit.refreshGlances(on: selectedDate)
            if log.drinksLogged == 0,
               let hkDrinks = await healthKit.readAlcoholicDrinks(on: selectedDate),
               hkDrinks > 0 {
                log.addDrinks(hkDrinks, timeLogged: DateHelpers.startOfDay(selectedDate))
                try? modelContext.save()
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
