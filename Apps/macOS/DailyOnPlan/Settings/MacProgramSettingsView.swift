import SwiftUI
import SwiftData
import Charts
import OnPlanCore

struct MacProgramSettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var allSettings: [AppSettings]
    @Query(sort: \WeightEntry.date) private var allWeights: [WeightEntry]
    @State private var heightFeet = 5
    @State private var heightInchesPart = 8
    @State private var goalWeightText = ""
    @State private var todayWeightText = ""
    @FocusState private var goalWeightFocused: Bool
    @FocusState private var todayWeightFocused: Bool
    @State private var editor: ProgramEditor?

    var body: some View {
        Group {
            if let settings = allSettings.first {
                content(settings)
            } else {
                ProgressView("Waiting for journal…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .onAppear { _ = DataStore.settings(in: modelContext) }
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private func content(_ settings: AppSettings) -> some View {
        MacSettingsScroll {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 320), spacing: 12)], spacing: 12) {
                programPanel(settings)
                bodyPanel(settings)
            }
            hydrationPanel(settings)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 240), spacing: 12)], spacing: 12) {
                smokingPanel(settings)
                drinkingPanel(settings)
                bathroomPanel(settings)
            }
            morePanel(settings)
            hungerPanel
        }
        .onAppear { load(settings) }
        .onChange(of: heightFeet) { _, _ in persistHeight(settings) }
        .onChange(of: heightInchesPart) { _, _ in persistHeight(settings) }
        .onChange(of: goalWeightFocused) { _, focused in
            if !focused { commitGoalWeight(settings) }
        }
        .onChange(of: todayWeightFocused) { _, focused in
            if !focused { commitTodayWeight(settings) }
        }
        .onChange(of: settings.usesMetricWeight) { _, _ in
            loadTodayWeight(settings)
            loadGoalWeight(settings)
        }
        .sheet(item: $editor) { item in
            NavigationStack {
                editorView(item, settings: settings)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Done") { editor = nil }
                        }
                    }
            }
            .frame(minWidth: 540, idealWidth: 620, minHeight: 440, idealHeight: 560)
        }
    }

    private func programPanel(_ settings: AppSettings) -> some View {
        SettingsPanel(
            title: "Program",
            systemImage: "flag.checkered",
            subtitle: "Phase and default protein goal. Syncs with iPhone."
        ) {
            Picker("Phase", selection: Binding(
                get: { settings.phase },
                set: {
                    settings.phase = $0
                    save(settings)
                }
            )) {
                ForEach(ProgramPhase.allCases) { phase in
                    Text(phase.title).tag(phase)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            Text(settings.phase == .week1 ? "Week 1 holds fats and fruit." : "Week 2+ allows fats and fruit.")
                .appFont(.caption2)
                .foregroundStyle(.secondary)

            Stepper(
                "Protein goal: \(settings.defaultProteinGoal) kcal",
                value: Binding(
                    get: { settings.defaultProteinGoal },
                    set: {
                        settings.defaultProteinGoal = $0
                        save(settings)
                    }
                ),
                in: AppLimits.proteinGoalMin...AppLimits.proteinGoalMax,
                step: 1
            )
        }
        .frame(maxWidth: .infinity, alignment: .top)
    }

    private func bodyPanel(_ settings: AppSettings) -> some View {
        SettingsPanel(
            title: "Body",
            systemImage: "figure.stand",
            subtitle: "Height drives BMI. Today’s weight is the journal, not a chrome pref."
        ) {
            Toggle("Use kilograms", isOn: Binding(
                get: { settings.usesMetricWeight },
                set: {
                    settings.usesMetricWeight = $0
                    save(settings)
                }
            ))
            .toggleStyle(.checkbox)

            HStack {
                Text("Height")
                    .appFont(.subheadline)
                Spacer()
                Picker("Feet", selection: $heightFeet) {
                    ForEach(4...7, id: \.self) { Text("\($0) ft").tag($0) }
                }
                .labelsHidden()
                .frame(width: 72)
                Picker("Inches", selection: $heightInchesPart) {
                    ForEach(0...11, id: \.self) { Text("\($0) in").tag($0) }
                }
                .labelsHidden()
                .frame(width: 72)
            }

            Stepper(
                settings.hasAge ? "Age: \(settings.ageYears)" : "Age: not set",
                value: Binding(
                    get: { settings.ageYears > 0 ? settings.ageYears : 30 },
                    set: {
                        settings.ageYears = $0
                        save(settings)
                    }
                ),
                in: 10...120
            )

            labeledField("Today", text: $todayWeightText, unit: settings, focus: $todayWeightFocused)
            if let bmiLine = todayBMILine(settings) {
                Text(bmiLine)
                    .appFont(.subheadline, weight: .semibold)
            } else if settings.hasHeight {
                Text("Enter today’s weight to see BMI.")
                    .appFont(.caption2)
                    .foregroundStyle(.secondary)
            }

            labeledField("Goal", text: $goalWeightText, unit: settings, focus: $goalWeightFocused)
            if settings.hasGoalWeight {
                Button("Clear goal", role: .destructive) {
                    settings.goalWeightLbs = nil
                    goalWeightText = ""
                    save(settings)
                }
                .controlSize(.small)
            }

            if !allWeights.isEmpty {
                macWeightTrend(settings)
            }
            if bmiChartRows(settings).count >= 2 {
                macBMITrend(settings)
            }
        }
        .frame(maxWidth: .infinity, alignment: .top)
    }

    private func hydrationPanel(_ settings: AppSettings) -> some View {
        SettingsPanel(
            title: "Hydration",
            systemImage: "drop.fill",
            subtitle: "Bottle size is the popover tap. Target is the daily goal."
        ) {
            HStack(alignment: .firstTextBaseline, spacing: 16) {
                Picker("Default bottle", selection: Binding(
                    get: { settings.defaultBottleOz },
                    set: {
                        settings.defaultBottleOz = $0
                        save(settings)
                    }
                )) {
                    Text("8 oz").tag(8.0)
                    Text("12 oz").tag(12.0)
                    Text("16.9 oz").tag(16.9)
                    Text("20 oz").tag(20.0)
                    Text("24 oz").tag(24.0)
                }
                .frame(maxWidth: 280)

                Stepper(
                    "Daily target: \(settings.hydrationTargetOz) oz",
                    value: Binding(
                        get: { settings.hydrationTargetOz },
                        set: {
                            settings.hydrationTargetOz = $0
                            save(settings)
                        }
                    ),
                    in: 16...400,
                    step: 8
                )
            }

            Toggle("Protein drinks count toward water", isOn: Binding(
                get: { settings.proteinDrinksCountTowardHydration },
                set: {
                    settings.proteinDrinksCountTowardHydration = $0
                    save(settings)
                }
            ))
            .toggleStyle(.checkbox)

            if settings.proteinDrinksCountTowardHydration {
                Stepper(
                    "Shake size: \(Int(settings.defaultShakeHydrationOz)) oz",
                    value: Binding(
                        get: { Int(settings.defaultShakeHydrationOz) },
                        set: {
                            settings.defaultShakeHydrationOz = Double($0)
                            save(settings)
                        }
                    ),
                    in: 4...32,
                    step: 1
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .top)
    }

    private func bathroomPanel(_ settings: AppSettings) -> some View {
        SettingsPanel(
            title: "Bathroom",
            systemImage: "toilet.fill",
            subtitle: "Quick-add urine and stool in the popover when this is on."
        ) {
            Toggle("Show bathroom on the day sheet", isOn: Binding(
                get: { settings.showBathroomSection },
                set: {
                    settings.showBathroomSection = $0
                    save(settings)
                }
            ))
            .toggleStyle(.checkbox)
            Text("Adds urine and stool taps in the popover. On iPhone it stays collapsed until you expand it.")
                .appFont(.caption2)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .top)
    }

    private func smokingPanel(_ settings: AppSettings) -> some View {
        SettingsPanel(
            title: "Smoking",
            systemImage: "smoke",
            subtitle: settings.smokingMode.subtitle
        ) {
            Picker("Mode", selection: Binding(
                get: { settings.smokingMode },
                set: {
                    settings.smokingMode = $0
                    if $0 == .quit, settings.quitDate == nil { settings.quitDate = Date() }
                    save(settings)
                }
            )) {
                ForEach(SmokingMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            if settings.smokingMode == .reduce {
                Stepper(
                    "Daily max: \(CigarettePackMath.packsLabel(cigarettes: settings.dailyCigaretteLimit))",
                    value: Binding(
                        get: { Int((settings.dailyCigaretteLimitPacks * 2).rounded()) },
                        set: {
                            settings.dailyCigaretteLimitPacks = Double($0) / 2.0
                            save(settings)
                        }
                    ),
                    in: 0...(AppLimits.cigaretteLimitMax * 2 / CigarettePackMath.perPack),
                    step: 1
                )
            }
            if settings.smokingMode == .quit {
                DatePicker(
                    "Quit date",
                    selection: Binding(
                        get: { settings.quitDate ?? Date() },
                        set: {
                            settings.quitDate = $0
                            save(settings)
                        }
                    ),
                    in: ...Date(),
                    displayedComponents: .date
                )
                .controlSize(.small)
            }
        }
        .frame(maxWidth: .infinity, alignment: .top)
    }

    private func drinkingPanel(_ settings: AppSettings) -> some View {
        SettingsPanel(
            title: "Drinking",
            systemImage: "wineglass",
            subtitle: settings.drinkingMode.subtitle
        ) {
            Picker("Mode", selection: Binding(
                get: { settings.drinkingMode },
                set: {
                    settings.drinkingMode = $0
                    if $0 == .quit, settings.alcoholQuitDate == nil { settings.alcoholQuitDate = Date() }
                    save(settings)
                }
            )) {
                ForEach(DrinkingMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            if settings.drinkingMode == .reduce {
                Stepper(
                    "Daily max: \(settings.dailyDrinkLimit) drinks",
                    value: Binding(
                        get: { settings.dailyDrinkLimit },
                        set: {
                            settings.dailyDrinkLimit = $0
                            save(settings)
                        }
                    ),
                    in: 0...AppLimits.drinkLimitMax,
                    step: 1
                )
            }
            if settings.drinkingMode == .quit {
                DatePicker(
                    "Quit date",
                    selection: Binding(
                        get: { settings.alcoholQuitDate ?? Date() },
                        set: {
                            settings.alcoholQuitDate = $0
                            save(settings)
                        }
                    ),
                    in: ...Date(),
                    displayedComponents: .date
                )
                .controlSize(.small)
            }
        }
        .frame(maxWidth: .infinity, alignment: .top)
    }

    private func morePanel(_ settings: AppSettings) -> some View {
        SettingsPanel(
            title: "Journal extras",
            systemImage: "square.grid.2x2",
            subtitle: "Lists and catalogs. Opens a panel — they still sync with iPhone."
        ) {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 200), spacing: 10)], spacing: 10) {
                ForEach(ProgramEditor.allCases) { item in
                    Button {
                        editor = item
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Label(item.title, systemImage: item.systemImage)
                                .appFont(.subheadline, weight: .semibold)
                            Text(item.blurb)
                                .appFont(.caption2)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(10)
                        .frame(maxWidth: .infinity, minHeight: 68, alignment: .topLeading)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(Color(nsColor: .windowBackgroundColor))
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var hungerPanel: some View {
        SettingsPanel(
            title: "Hunger scale",
            systemImage: "fork.knife.circle",
            subtitle: HungerScale.guidance
        ) {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
                ForEach(HungerScale.levels, id: \.0) { level in
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text("\(level.0)")
                            .appFont(.caption, weight: .semibold, mono: true)
                            .frame(width: 16, alignment: .trailing)
                        Text(level.1)
                            .appFont(.caption2)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func editorView(_ item: ProgramEditor, settings: AppSettings) -> some View {
        switch item {
        case .bodyComp: BodyCompositionListView(showsDismissButton: false)
        case .measurements: BodyMeasurementsListView(showsDismissButton: false)
        case .quotes: MotivationQuotesSettingsView(settings: settings)
        case .dayLayout: DayLayoutSettingsView(settings: settings)
        case .meals: SavedMealsListView(settings: settings)
        case .foodPrefs: FoodPreferencesView(settings: settings)
        case .foodLookup: FoodLookupSettingsView(settings: settings)
        case .supplements: SupplementsSettingsForm(settings: settings)
        case .presets: MacFoodPresetsEditor()
        }
    }

    private func displayWeight(_ lbs: Double, settings: AppSettings) -> Double {
        settings.usesMetricWeight ? lbs * 0.453592 : lbs
    }

    private func bmiChartRows(_ settings: AppSettings) -> [(date: Date, value: Double)] {
        guard settings.hasHeight else { return [] }
        return allWeights.compactMap { entry in
            guard let bmi = BMICalculator.bmi(weightLbs: entry.weightLbs, heightInches: settings.heightInches) else {
                return nil
            }
            return (entry.date, bmi)
        }
    }

    private func macWeightTrend(_ settings: AppSettings) -> some View {
        let values = allWeights.map { displayWeight($0.weightLbs, settings: settings) }
        let goal = settings.goalWeightLbs.map { displayWeight($0, settings: settings) }
        return VStack(alignment: .leading, spacing: 6) {
            Text("Weight trend")
                .appFont(.caption, weight: .semibold)
                .foregroundStyle(.secondary)
            Chart {
                ForEach(allWeights) { entry in
                    LineMark(
                        x: .value("Date", entry.date),
                        y: .value("Weight", displayWeight(entry.weightLbs, settings: settings))
                    )
                    PointMark(
                        x: .value("Date", entry.date),
                        y: .value("Weight", displayWeight(entry.weightLbs, settings: settings))
                    )
                }
                if let goal {
                    RuleMark(y: .value("Goal", goal))
                        .foregroundStyle(.orange)
                        .lineStyle(StrokeStyle(dash: [4, 3]))
                }
            }
            .frame(height: 120)
            .chartYAxisLabel(settings.usesMetricWeight ? "kg" : "lb")
            .chartPaddedYScale(
                values: values,
                goal: goal,
                pad: ChartValueScale.weightPad(usesMetric: settings.usesMetricWeight)
            )
        }
    }

    private func macBMITrend(_ settings: AppSettings) -> some View {
        let rows = bmiChartRows(settings)
        let goal = settings.goalWeightLbs.flatMap {
            BMICalculator.bmi(weightLbs: $0, heightInches: settings.heightInches)
        }
        return VStack(alignment: .leading, spacing: 6) {
            Text("BMI trend")
                .appFont(.caption, weight: .semibold)
                .foregroundStyle(.secondary)
            Chart {
                ForEach(rows, id: \.date) { row in
                    LineMark(
                        x: .value("Date", row.date),
                        y: .value("BMI", row.value)
                    )
                    PointMark(
                        x: .value("Date", row.date),
                        y: .value("BMI", row.value)
                    )
                }
                if let goal {
                    RuleMark(y: .value("Goal BMI", goal))
                        .foregroundStyle(.orange)
                        .lineStyle(StrokeStyle(dash: [4, 3]))
                }
            }
            .frame(height: 120)
            .chartPaddedYScale(
                values: rows.map(\.value),
                goal: goal,
                pad: ChartValueScale.bmiPad(heightInches: settings.heightInches)
            )
        }
    }

    private func labeledField(
        _ title: String,
        text: Binding<String>,
        unit settings: AppSettings,
        focus: FocusState<Bool>.Binding
    ) -> some View {
        HStack {
            Text(title)
                .appFont(.subheadline)
            TextField(title, text: text)
                .textFieldStyle(.roundedBorder)
                .focused(focus)
                .onChange(of: text.wrappedValue) { _, newValue in
                    let filtered = newValue.filter { $0.isNumber || $0 == "." || $0 == "," }
                    if filtered != newValue { text.wrappedValue = filtered }
                }
            Text(settings.usesMetricWeight ? "kg" : "lb")
                .foregroundStyle(.secondary)
                .frame(width: 24, alignment: .leading)
        }
    }

    private func load(_ settings: AppSettings) {
        loadGoalWeight(settings)
        loadTodayWeight(settings)
        let total = Int(settings.heightInches)
        if total > 0 {
            heightFeet = total / 12
            heightInchesPart = total % 12
        }
    }

    private func loadGoalWeight(_ settings: AppSettings) {
        if let goal = settings.goalWeightLbs {
            let value = settings.usesMetricWeight ? goal * 0.453592 : goal
            goalWeightText = String(format: "%.1f", value)
        } else {
            goalWeightText = ""
        }
    }

    private func loadTodayWeight(_ settings: AppSettings) {
        guard let weight = DataStore.weight(for: Date(), in: modelContext) else {
            todayWeightText = ""
            return
        }
        let value = settings.usesMetricWeight ? weight.weightLbs * 0.453592 : weight.weightLbs
        todayWeightText = String(format: "%.1f", value)
    }

    private func persistHeight(_ settings: AppSettings) {
        settings.heightInches = Double(heightFeet * 12 + heightInchesPart)
        save(settings)
    }

    private func commitTodayWeight(_ settings: AppSettings) {
        let cleaned = todayWeightText.replacingOccurrences(of: ",", with: ".").trimmingCharacters(in: .whitespaces)
        if cleaned.isEmpty { return }
        guard let value = Double(cleaned), value > 0 else {
            loadTodayWeight(settings)
            return
        }
        let lbs = settings.usesMetricWeight ? value / 0.453592 : value
        if let existing = DataStore.weight(for: Date(), in: modelContext) {
            existing.weightLbs = lbs
            existing.timeLogged = Date()
        } else {
            modelContext.insert(WeightEntry(date: Date(), weightLbs: lbs))
        }
        todayWeightText = String(format: "%.1f", value)
        save(settings)
    }

    private func commitGoalWeight(_ settings: AppSettings) {
        let cleaned = goalWeightText.replacingOccurrences(of: ",", with: ".").trimmingCharacters(in: .whitespaces)
        if cleaned.isEmpty { return }
        guard let value = Double(cleaned), value > 0 else {
            loadGoalWeight(settings)
            return
        }
        settings.goalWeightLbs = settings.usesMetricWeight ? value / 0.453592 : value
        goalWeightText = String(format: "%.1f", value)
        save(settings)
    }

    private func todayBMILine(_ settings: AppSettings) -> String? {
        guard let weight = DataStore.weight(for: Date(), in: modelContext),
              let bmi = BMICalculator.bmi(weightLbs: weight.weightLbs, heightInches: settings.heightInches)
        else { return nil }
        return String(format: "Today’s BMI: %.1f · %@", bmi, BMICalculator.category(for: bmi))
    }

    private func save(_ settings: AppSettings) {
        modelContext.saveAndNotifyJournal()
    }
}

private enum ProgramEditor: String, Identifiable, CaseIterable {
    case bodyComp
    case measurements
    case supplements
    case meals
    case presets
    case foodPrefs
    case foodLookup
    case dayLayout
    case quotes

    var id: String { rawValue }

    var title: String {
        switch self {
        case .bodyComp: return "Body composition"
        case .measurements: return "Tape measurements"
        case .supplements: return "Supplements"
        case .meals: return "Saved meals"
        case .presets: return "Food presets"
        case .foodPrefs: return "Food preferences"
        case .foodLookup: return "Food lookup"
        case .dayLayout: return "iPhone day layout"
        case .quotes: return "Quotes"
        }
    }

    var blurb: String {
        switch self {
        case .bodyComp: return "Clinic receipts and history."
        case .measurements: return "Waist, hips, and the rest of the tape."
        case .supplements: return "Names, doses, and reminder times."
        case .meals: return "Reuse a plate instead of rebuilding it."
        case .presets: return "Foods you save while logging protein."
        case .foodPrefs: return "Foods to avoid or keep off Suggest."
        case .foodLookup: return "USDA key and barcode lookup."
        case .dayLayout: return "Section order on the iPhone day sheet."
        case .quotes: return "The stay-on-plan reminder list."
        }
    }

    var systemImage: String {
        switch self {
        case .bodyComp: return "list.clipboard"
        case .measurements: return "ruler"
        case .supplements: return "pills.fill"
        case .meals: return "fork.knife"
        case .presets: return "star"
        case .foodPrefs: return "heart.slash"
        case .foodLookup: return "barcode.viewfinder"
        case .dayLayout: return "list.bullet.rectangle"
        case .quotes: return "quote.bubble"
        }
    }
}

private struct MacFoodPresetsEditor: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \CustomFoodPreset.name) private var presets: [CustomFoodPreset]

    var body: some View {
        List {
            if presets.isEmpty {
                Text("Save foods as presets when adding protein.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(presets) { preset in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(preset.name)
                            Text("\(preset.servingLabel) · \(preset.calories) kcal")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button(role: .destructive) {
                            modelContext.delete(preset)
                            modelContext.saveAndNotifyJournal()
                        } label: {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(.borderless)
                    }
                }
            }
        }
        .navigationTitle("Food presets")
    }
}
