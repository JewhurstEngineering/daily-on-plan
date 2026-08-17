import SwiftUI
import SwiftData
import OnPlanCore

struct MacTodayView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.appTheme) private var appTheme
    @EnvironmentObject private var store: OnPlanStore
    @State private var selectedDate = Date()
    @State private var weightText = ""
    @State private var extraCarb = ""
    @State private var extraFat = ""
    @State private var extraKcal = ""
    @State private var fastingStreak = 0

    var body: some View {
        let settings = DataStore.settings(in: modelContext)
        let log = DataStore.log(for: selectedDate, in: modelContext, defaultGoal: settings.defaultProteinGoal)
        let weight = DataStore.weight(for: selectedDate, in: modelContext)
        let checklist = FoodCatalog.checklistCalories(for: log, phase: settings.phase)
        let _ = store.snapshot.generatedAt

        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header(log: log, settings: settings)
                flags(log: log)
                if settings.fastingEnabled || log.eatingWindowStart != nil || log.eatingWindowEnd != nil {
                    fasting(log: log, settings: settings)
                }
                protein(log: log)
                hydration(log: log, settings: settings)
                checklistBlock(log: log, calories: checklist, settings: settings)
                if !log.followedPlan {
                    extras(log: log)
                }
                weightBlock(weight: weight, settings: settings)
            }
            .padding(20)
        }
        .background(Color.onPlanGroupedBackground)
        .appThemed(store.preferences)
        .frame(minWidth: 420, minHeight: 520)
        .onAppear {
            MacDaySync.refresh(store: store, context: modelContext)
            refreshFastingStreak(settings: settings)
            if let weight {
                weightText = String(format: "%.1f", settings.usesMetricWeight ? weight.weightLbs * 0.453592 : weight.weightLbs)
            }
            extraCarb = log.offPlanExtraCarbGrams > 0 ? String(format: "%.0f", log.offPlanExtraCarbGrams) : ""
            extraFat = log.offPlanExtraFatGrams > 0 ? String(format: "%.0f", log.offPlanExtraFatGrams) : ""
            extraKcal = log.offPlanExtraKcal > 0 ? "\(log.offPlanExtraKcal)" : ""
        }
        .onChange(of: log.followedPlan) { _, _ in MacDaySync.refresh(store: store, context: modelContext) }
        .onChange(of: log.ketosis) { _, _ in MacDaySync.refresh(store: store, context: modelContext) }
        .onChange(of: selectedDate) { _, _ in refreshFastingStreak(settings: settings) }
    }

    private func header(log: DailyLog, settings: AppSettings) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(AppIdentity.displayName)
                    .font(.title2.weight(.semibold))
                Text(DateHelpers.formattedDay(selectedDate))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(log.totalProteinCalories) / \(log.proteinGoal) kcal")
                    .font(.headline.monospacedDigit())
                Text("\(log.totalHydrationOz(settings: settings)) / \(settings.hydrationTargetOz) oz")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func flags(log: DailyLog) -> some View {
        HStack {
            Toggle("Followed plan", isOn: Binding(
                get: { log.followedPlan },
                set: {
                    log.followedPlan = $0
                    if $0 { log.offPlanReasons = [] }
                    save()
                }
            ))
            Toggle("Ketosis", isOn: Binding(
                get: { log.ketosis },
                set: {
                    log.ketosis = $0
                    save()
                }
            ))
        }
        .toggleStyle(.checkbox)
    }

    private func fasting(log: DailyLog, settings: AppSettings) -> some View {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: selectedDate) ?? selectedDate
        let previous = DataStore.existingLog(for: yesterday, in: modelContext)
        return GroupBox {
            FastingTrackerCard(
                log: log,
                previous: previous,
                settings: settings,
                streak: fastingStreak,
                onChange: {
                    save()
                    refreshFastingStreak(settings: settings)
                }
            )
            .environment(\.accentPrimary, appTheme.tint)
        }
    }

    private func protein(log: DailyLog) -> some View {
        GroupBox("Protein") {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(log.sortedProteins, id: \.id) { entry in
                    HStack {
                        Text(entry.name)
                        Spacer()
                        Text("\(entry.calories) kcal")
                            .foregroundStyle(.secondary)
                    }
                }
                if log.proteins.isEmpty {
                    Text("Nothing logged yet.")
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Button("+50 kcal") { apply(QuickAddService.addProteinCalories(50)); refresh() }
                    Button("+100 kcal") { apply(QuickAddService.addProteinCalories(100)); refresh() }
                    ForEach(FoodCatalog.quickProteinPresets.prefix(3), id: \.name) { food in
                        Button(food.name) {
                            addCatalogProtein(food, log: log)
                        }
                    }
                }
                .controlSize(.small)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func hydration(log: DailyLog, settings: AppSettings) -> some View {
        GroupBox("Hydration") {
            HStack {
                Text("\(log.totalHydrationOz(settings: settings)) oz")
                Spacer()
                Button("Add bottle") {
                    apply(QuickAddService.addWaterBottle())
                    refresh()
                }
                .controlSize(.small)
            }
        }
    }

    private func checklistBlock(
        log: DailyLog,
        calories: (vegetable: Int, fat: Int, fruit: Int, misc: Int),
        settings: AppSettings
    ) -> some View {
        GroupBox("Checklist kcal") {
            Text("Veg \(calories.vegetable) · Fat \(calories.fat) · Fruit \(calories.fruit) · Misc \(calories.misc)")
                .foregroundStyle(.secondary)
            Text("Protein kcal stays the ring. This is just the checked servings.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func extras(log: DailyLog) -> some View {
        GroupBox("Off-plan extras") {
            HStack {
                labeledField("Carb g", text: $extraCarb) {
                    log.offPlanExtraCarbGrams = Double(extraCarb) ?? 0
                    save()
                }
                labeledField("Fat g", text: $extraFat) {
                    log.offPlanExtraFatGrams = Double(extraFat) ?? 0
                    save()
                }
                labeledField("Kcal", text: $extraKcal) {
                    log.offPlanExtraKcal = Int(extraKcal) ?? 0
                    save()
                }
            }
        }
    }

    private func weightBlock(weight: WeightEntry?, settings: AppSettings) -> some View {
        GroupBox("Weight") {
            HStack {
                TextField(settings.usesMetricWeight ? "kg" : "lb", text: $weightText)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 90)
                Button("Save") {
                    let value = Double(weightText.replacingOccurrences(of: ",", with: ".")) ?? 0
                    guard value > 0 else { return }
                    let lbs = settings.usesMetricWeight ? value / 0.453592 : value
                    if let weight {
                        weight.weightLbs = lbs
                        weight.timeLogged = Date()
                    } else {
                        modelContext.insert(WeightEntry(date: selectedDate, weightLbs: lbs))
                    }
                    save()
                }
                .controlSize(.small)
            }
        }
    }

    private func labeledField(_ title: String, text: Binding<String>, onCommit: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            TextField(title, text: text, onCommit: onCommit)
                .textFieldStyle(.roundedBorder)
                .frame(width: 80)
        }
    }

    private func addCatalogProtein(_ food: CatalogFood, log: DailyLog) {
        let entry = ProteinEntry(
            name: food.name,
            servingSize: food.servingLabel,
            calories: food.calories,
            proteinCategory: food.proteinCategory?.rawValue ?? "other",
            servings: 1
        )
        entry.log = log
        modelContext.insert(entry)
        save()
        refresh()
    }

    private func apply(_ result: QuickAddService.Result) {
        _ = result
    }

    private func save() {
        modelContext.saveAndNotifyJournal()
        refresh()
    }

    private func refresh() {
        MacDaySync.refresh(store: store, context: modelContext)
    }

    private func refreshFastingStreak(settings: AppSettings) {
        let recent = DataStore.logs(
            from: Calendar.current.date(byAdding: .day, value: -60, to: selectedDate) ?? selectedDate,
            to: selectedDate,
            in: modelContext
        )
        fastingStreak = FastingMath.streak(logs: recent, settings: settings)
    }
}
