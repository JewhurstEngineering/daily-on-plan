import SwiftUI
import SwiftData
import OnPlanCore

/// Today: the three things that get logged every day, each pairing its number with the
/// button that changes it, and everything optional folded into one "Also today" card.
///
/// Replaces the old stack of twelve reorderable section cards — see the redesign canvas.
/// The section views themselves are unchanged; they now live one push away
/// (`SectionDetailScreen`) instead of all being stacked on this screen.
struct DayView: View {
    @Binding var selectedDate: Date
    @Binding var path: [TodayDestination]
    var onOpenSettings: (() -> Void)? = nil
    var onOpenBodyComposition: (() -> Void)? = nil
    var onOpenBodyMeasurements: (() -> Void)? = nil
    @Binding var pendingScrollSection: String?

    @Environment(\.modelContext) private var modelContext
    @Environment(\.appTheme) private var appTheme
    @EnvironmentObject private var healthKit: HealthKitService
    @EnvironmentObject private var store: OnPlanStore
    @EnvironmentObject private var weightReveal: WeightRevealState

    @State private var recentWeights: [WeightEntry] = []
    @State private var didSyncHealth = false

    init(
        selectedDate: Binding<Date>,
        path: Binding<[TodayDestination]>,
        onOpenSettings: (() -> Void)? = nil,
        onOpenBodyComposition: (() -> Void)? = nil,
        onOpenBodyMeasurements: (() -> Void)? = nil,
        pendingScrollSection: Binding<String?> = .constant(nil)
    ) {
        self._selectedDate = selectedDate
        self._path = path
        self.onOpenSettings = onOpenSettings
        self.onOpenBodyComposition = onOpenBodyComposition
        self.onOpenBodyMeasurements = onOpenBodyMeasurements
        self._pendingScrollSection = pendingScrollSection
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
        let masking = WeightMasking(preferences: store.preferences, state: weightReveal)

        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.s) {
                TodayDateBar(selectedDate: $selectedDate)

                TodayWeightCard(
                    weight: todayWeight,
                    recentWeights: recentWeights,
                    settings: settings,
                    masking: masking,
                    onOpen: { path.append(.weight) },
                    onLog: { path.append(.weight) }
                )

                proteinCard(log: log, settings: settings)

                hydrationCard(log: log, settings: settings)

                TodayRitualCard(log: log) {
                    path.append(.section(.dailyStatus))
                }

                AlsoTodayCard(
                    settings: settings,
                    log: log,
                    onSelect: { path.append(.section($0)) },
                    onSeeAll: { path.append(.alsoToday) }
                )

                glances
            }
            .padding()
        }
        .background(Color.onPlanGroupedBackground)
        .navigationDestination(for: TodayDestination.self) { destination in
            destinationView(destination, settings: settings, log: log, recentLogs: recentLogs, todayWeight: todayWeight)
        }
        .onAppear {
            recentWeights = DataStore.recentWeights(limit: 30, in: modelContext)
            syncHealthIfNeeded(log: log, todayWeight: todayWeight)
            consumePendingSection()
        }
        .onChange(of: pendingScrollSection) { _, _ in
            consumePendingSection()
        }
        .onChange(of: selectedDate) { _, _ in
            didSyncHealth = false
            recentWeights = DataStore.recentWeights(limit: 30, in: modelContext)
            let settings = DataStore.settings(in: modelContext)
            let log = DataStore.log(for: selectedDate, in: modelContext, defaultGoal: settings.defaultProteinGoal)
            let todayWeight = DataStore.weight(for: selectedDate, in: modelContext)
            syncHealthIfNeeded(log: log, todayWeight: todayWeight)
        }
    }

    // MARK: - Cards

    private func proteinCard(log: DailyLog, settings: AppSettings) -> some View {
        let total = log.totalProteinCalories
        let goal = log.proteinGoal
        let remaining = max(0, goal - total)
        let meals = log.proteinEntries?.count ?? 0
        let subtitle = total > goal
            ? "\(total - goal) kcal over · \(meals) logged"
            : "\(remaining) kcal left · \(meals) logged"

        return TodayGoalCard(
            title: "Protein",
            current: total,
            goal: goal,
            unit: "kcal",
            subtitle: subtitle,
            ringCaption: "KCAL",
            tint: appTheme.protein,
            metTint: appTheme.ok,
            // The protein goal is a ceiling here, so passing it reads as a warning, not a win.
            overTint: appTheme.warn,
            badge: total > goal ? "OVER" : nil,
            actionTitle: "Log",
            actionIsProminent: true,
            weekValues: weekSeries { Double($0.totalProteinCalories) },
            weekOverTint: appTheme.warn,
            onAction: { path.append(.protein) },
            onOpen: { path.append(.protein) },
            actionMenu: {
                // Long press: log something already eaten before, without leaving Today.
                ForEach(proteinQuickAdds, id: \.id) { item in
                    Button {
                        addProtein(item, to: log)
                    } label: {
                        Label(quickAddLabel(item), systemImage: "plus.circle")
                    }
                }
                Divider()
                Button {
                    path.append(.protein)
                } label: {
                    Label("Add something else…", systemImage: "square.and.pencil")
                }
            }
        )
    }

    private var proteinQuickAdds: [SuggestionItem] {
        UsageSuggestions.proteinChips(in: modelContext, limit: 6)
    }

    private func quickAddLabel(_ item: SuggestionItem) -> String {
        guard let calories = item.calories else { return item.name }
        return "\(item.name) · \(calories) kcal"
    }

    private func addProtein(_ item: SuggestionItem, to log: DailyLog) {
        let category = item.proteinCategory ?? ProteinCategory.other.rawValue
        let entry = ProteinEntry(
            name: item.name,
            servingSize: item.subtitle ?? item.amount ?? "1 serving",
            calories: item.calories ?? 0,
            proteinCategory: category,
            servings: item.servings,
            hydrationOz: settings(for: log).suggestedHydrationOz(
                forProteinCategory: category,
                servings: item.servings
            )
        )
        modelContext.insert(entry)
        log.proteins.append(entry)
        try? modelContext.save()
        WidgetReloader.reloadAll()
    }

    private func settings(for _: DailyLog) -> AppSettings {
        DataStore.settings(in: modelContext)
    }

    private func hydrationCard(log: DailyLog, settings: AppSettings) -> some View {
        let total = log.totalHydrationOz(settings: settings)
        let goal = settings.hydrationTargetOz
        let remaining = max(0, goal - total)
        let subtitle = remaining == 0
            ? (log.hasElectrolyteDrink ? "Electrolytes logged" : "Target reached")
            : "\(remaining) oz left"

        return TodayGoalCard(
            title: "Hydration",
            current: total,
            goal: goal,
            unit: "oz",
            subtitle: subtitle,
            ringCaption: "OZ",
            tint: appTheme.water,
            metTint: appTheme.ok,
            badge: total >= goal ? "GOAL HIT" : nil,
            electrolyteSegments: HydrationRingSegments.electrolyteSegments(
                slots: log.waterSlots,
                goalOz: goal
            ),
            actionTitle: "\(formatOz(settings.defaultBottleOz))oz",
            actionIsProminent: false,
            weekValues: weekSeries { Double($0.totalHydrationOz(settings: settings)) },
            weekShortTint: appTheme.water.opacity(0.28),
            // Tap logs the usual bottle outright — the common case should not cost a screen.
            onAction: { logWater(settings.defaultBottleOz, kind: .water, log: log, settings: settings) },
            onOpen: { path.append(.hydration) },
            actionMenu: {
                HydrationQuickAddMenu(onFill: { oz, kind, subtype in
                    logWater(oz, kind: kind, otherSubtype: subtype, log: log, settings: settings)
                })
            }
        )
    }

    private func formatOz(_ oz: Double) -> String {
        oz.rounded() == oz ? String(Int(oz)) : String(format: "%.1f", oz)
    }

    private func logWater(
        _ oz: Double,
        kind: HydrationDrinkKind,
        otherSubtype: HydrationOtherSubtype? = nil,
        log: DailyLog,
        settings: AppSettings
    ) {
        let bottle = max(settings.defaultBottleOz, 1)
        let slots = max(1, Int(ceil(Double(settings.hydrationTargetOz) / bottle)))
        log.fillNextWaterSlot(oz: oz, ensuringMinimumSlots: slots, kind: kind, otherSubtype: otherSubtype)
        try? modelContext.save()
        WidgetReloader.reloadAll()
        Task { await healthKit.writeWater(ounces: Int(oz.rounded()), on: selectedDate) }
    }

    /// The last fortnight ending on `selectedDate`, oldest first. Days with no log come
    /// back as 0 so the strip shows the gap rather than silently compressing the run.
    private func weekSeries(_ days: Int = 14, _ value: (DailyLog) -> Double) -> [Double] {
        let calendar = Calendar.current
        let end = DateHelpers.startOfDay(selectedDate)
        guard let start = calendar.date(byAdding: .day, value: -(days - 1), to: end) else { return [] }
        let logs = DataStore.logs(from: start, to: end, in: modelContext)
        let byDay = Dictionary(
            logs.map { (DateHelpers.startOfDay($0.date), $0) },
            uniquingKeysWith: { first, _ in first }
        )
        return (0..<days).compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: offset, to: start) else { return nil }
            return byDay[day].map(value) ?? 0
        }
    }

    @ViewBuilder
    private var glances: some View {
        let steps = healthKit.todayStepCount
        let sleep = healthKit.lastNightSleepHours
        if steps != nil || sleep != nil {
            HStack(spacing: Spacing.l) {
                if let steps {
                    Label("\(steps) steps", systemImage: "figure.walk")
                }
                if let sleep {
                    Label(String(format: "%.1f h sleep", sleep), systemImage: "moon.zzz")
                }
            }
            .font(.caption)
            .foregroundStyle(.tertiary)
            .padding(.horizontal, Spacing.xs)
        }
    }

    // MARK: - Navigation

    @ViewBuilder
    private func destinationView(
        _ destination: TodayDestination,
        settings: AppSettings,
        log: DailyLog,
        recentLogs: [DailyLog],
        todayWeight: WeightEntry?
    ) -> some View {
        switch destination {
        case .alsoToday:
            AlsoTodayScreen(settings: settings, log: log) { section in
                path.append(.section(section))
            }
        case .weight:
            sectionScreen(.weight, settings: settings, log: log, recentLogs: recentLogs, todayWeight: todayWeight)
        case .protein:
            sectionScreen(.protein, settings: settings, log: log, recentLogs: recentLogs, todayWeight: todayWeight)
        case .hydration:
            sectionScreen(.hydration, settings: settings, log: log, recentLogs: recentLogs, todayWeight: todayWeight)
        case .section(let section):
            sectionScreen(section, settings: settings, log: log, recentLogs: recentLogs, todayWeight: todayWeight)
        }
    }

    private func sectionScreen(
        _ section: DaySectionID,
        settings: AppSettings,
        log: DailyLog,
        recentLogs: [DailyLog],
        todayWeight: WeightEntry?
    ) -> some View {
        SectionDetailScreen(
            section: section,
            selectedDate: selectedDate,
            settings: settings,
            log: log,
            recentLogs: recentLogs,
            recentWeights: recentWeights,
            todayWeight: todayWeight,
            onSaveWeight: { lbs in saveWeight(lbs, existing: todayWeight) },
            onOpenSettings: { onOpenSettings?() },
            onOpenBodyComposition: { onOpenBodyComposition?() },
            onOpenBodyMeasurements: { onOpenBodyMeasurements?() }
        )
    }

    /// Widget and notification deep links used to scroll Today to a section; now they push it.
    private func consumePendingSection() {
        guard let raw = pendingScrollSection else { return }
        pendingScrollSection = nil
        guard let section = DaySectionID(rawValue: raw) else { return }
        path.append(.section(section))
    }

    // MARK: - Data

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
        recentWeights = DataStore.recentWeights(limit: 30, in: modelContext)
        Task {
            await healthKit.writeBodyMass(pounds: lbs, on: selectedDate)
        }
    }
}
