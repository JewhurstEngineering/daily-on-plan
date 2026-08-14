import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var settings: AppSettings?
    @State private var heightFeet = 5
    @State private var heightInchesPart = 8
    @State private var goalWeightText = ""
    @State private var todayWeightText = ""
    @FocusState private var goalWeightFocused: Bool
    @FocusState private var todayWeightFocused: Bool
    @Query(sort: \CustomFoodPreset.name) private var presets: [CustomFoodPreset]

    var body: some View {
        NavigationStack {
            Group {
                if let settings {
                    settingsForm(settings)
                } else {
                    ProgressView()
                }
            }
            .navigationTitle(Self.screenTitle)
            .toolbar {
                #if os(iOS)
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        goalWeightFocused = false
                        todayWeightFocused = false
                        if let settings {
                            commitGoalWeight(settings)
                            commitTodayWeight(settings)
                        }
                        Keyboard.dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        if let settings {
                            commitGoalWeight(settings)
                            commitTodayWeight(settings)
                        }
                        Keyboard.dismiss()
                        dismiss()
                    }
                }
                #endif
            }
            .onAppear {
                let s = DataStore.settings(in: modelContext)
                settings = s
                if let goal = s.goalWeightLbs {
                    let value = s.usesMetricWeight ? goal * 0.453592 : goal
                    goalWeightText = String(format: "%.1f", value)
                } else {
                    goalWeightText = ""
                }
                loadTodayWeight(s)
                let total = Int(s.heightInches)
                if total > 0 {
                    heightFeet = total / 12
                    heightInchesPart = total % 12
                }
            }
        }
    }

    @ViewBuilder
    private func settingsForm(_ settings: AppSettings) -> some View {
        Form {
            #if os(iOS)
            appearanceSection(settings)
            #endif
            programSection(settings)
            bodyMetricsSection(settings)
            trackingLinksSection(settings)
            presetsSection
            hungerScaleSection
            #if os(iOS)
            healthSection
            backupSection
            #endif
        }
    }

    #if os(iOS)
    @ViewBuilder
    private func appearanceSection(_ settings: AppSettings) -> some View {
        Section("Appearance") {
            Text(AppIdentity.tagline)
                .font(.footnote)
                .foregroundStyle(.secondary)

            Picker("Appearance", selection: Binding(
                get: { settings.appearanceMode },
                set: {
                    settings.appearanceMode = $0
                    save(settings)
                }
            )) {
                ForEach(AppearanceMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }

            Text(appearanceFooter(for: settings.appearanceMode))
                .font(.caption2)
                .foregroundStyle(.secondary)

            Text("Color theme")
                .font(.subheadline)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 12) {
                ForEach(AccentTheme.pickerCases) { themeOption in
                    Button {
                        settings.accentTheme = themeOption
                        settings.customAccentHex = nil
                        save(settings)
                    } label: {
                        ZStack {
                            if let secondary = themeOption.pickerSecondary {
                                Circle()
                                    .fill(
                                        AngularGradient(
                                            colors: [themeOption.primary, secondary, themeOption.primary],
                                            center: .center
                                        )
                                    )
                                    .frame(width: 36, height: 36)
                            } else {
                                Circle()
                                    .fill(themeOption.color)
                                    .frame(width: 36, height: 36)
                            }
                            if settings.accentTheme == themeOption {
                                Image(systemName: "checkmark")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(.white)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(themeOption.title)
                }
            }

            ColorPicker(
                "Custom color",
                selection: Binding(
                    get: {
                        settings.accentPrimary
                    },
                    set: { newColor in
                        if let hex = newColor.toHexRGB() {
                            settings.customAccentHex = hex
                            settings.accentTheme = .custom
                            save(settings)
                        }
                    }
                ),
                supportsOpacity: false
            )

            if settings.accentTheme == .custom {
                HStack(spacing: 10) {
                    Circle()
                        .fill(settings.accentPrimary)
                        .frame(width: 22, height: 22)
                        .overlay {
                            Image(systemName: "checkmark")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(.white)
                        }
                    Text("Using custom color")
                        .font(.caption.weight(.semibold))
                    Spacer()
                    Button("Reset") {
                        settings.accentTheme = .onPlan
                        settings.customAccentHex = nil
                        save(settings)
                    }
                    .font(.caption)
                }
            }

            Text(settings.accentTheme.title)
                .font(.caption.weight(.semibold))
            Text(settings.accentTheme.subtitle)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
    #endif

    @ViewBuilder
    private func programSection(_ settings: AppSettings) -> some View {
        Section("Program") {
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
    }

    @ViewBuilder
    private func bodyMetricsSection(_ settings: AppSettings) -> some View {
        Section {
            Toggle("Use kilograms", isOn: Binding(
                get: { settings.usesMetricWeight },
                set: {
                    settings.usesMetricWeight = $0
                    save(settings)
                }
            ))

            HStack {
                Text("Height")
                Spacer()
                Picker("Feet", selection: $heightFeet) {
                    ForEach(4...7, id: \.self) { Text("\($0) ft").tag($0) }
                }
                .labelsHidden()
                .pickerStyle(.menu)

                Picker("Inches", selection: $heightInchesPart) {
                    ForEach(0...11, id: \.self) { Text("\($0) in").tag($0) }
                }
                .labelsHidden()
                .pickerStyle(.menu)
            }

            Text("Saved as \(heightFeet)'\(heightInchesPart)\"")
                .font(.caption)
                .foregroundStyle(.secondary)

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

            HStack {
                TextField("Today’s weight", text: $todayWeightText)
                    .onPlanKeyboard(.decimalPad)
                    .focused($todayWeightFocused)
                    .onChange(of: todayWeightText) { _, newValue in
                        let filtered = newValue.filter { $0.isNumber || $0 == "." || $0 == "," }
                        if filtered != newValue { todayWeightText = filtered }
                    }
                Text(settings.usesMetricWeight ? "kg" : "lb")
                    .foregroundStyle(.secondary)
            }
            if let bmiLine = todayBMILine(settings) {
                Text(bmiLine)
                    .font(.subheadline.weight(.semibold))
            } else if settings.hasHeight {
                Text("Enter today’s weight to see BMI.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack {
                TextField("Goal weight", text: $goalWeightText)
                    .onPlanKeyboard(.decimalPad)
                    .focused($goalWeightFocused)
                    .onChange(of: goalWeightText) { _, newValue in
                        let filtered = newValue.filter { $0.isNumber || $0 == "." || $0 == "," }
                        if filtered != newValue { goalWeightText = filtered }
                    }
                Text(settings.usesMetricWeight ? "kg" : "lb")
                    .foregroundStyle(.secondary)
            }
            if settings.hasGoalWeight {
                Button("Clear goal weight", role: .destructive) {
                    settings.goalWeightLbs = nil
                    goalWeightText = ""
                    save(settings)
                }
            }
        } header: {
            Text("Body metrics")
        } footer: {
            Text("Height and age prefill body composition readings. BMI uses height with today’s weight. Tape measurements live under Body measurements.")
        }
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
        }
    }

    @ViewBuilder
    private func trackingLinksSection(_ settings: AppSettings) -> some View {
        Section {
            NavigationLink {
                BodyCompositionListView(showsDismissButton: false)
            } label: {
                Label("Body composition", systemImage: "list.clipboard")
            }
            NavigationLink {
                BodyMeasurementsListView(showsDismissButton: false)
            } label: {
                Label("Body measurements", systemImage: "ruler")
            }
            NavigationLink {
                FastingSettingsView(settings: settings)
            } label: {
                Label("Fasting", systemImage: "clock")
            }
            NavigationLink {
                NotificationsSettingsView(settings: settings)
            } label: {
                Label("Notifications", systemImage: "bell.badge")
            }
            NavigationLink {
                MotivationQuotesSettingsView(settings: settings)
            } label: {
                Label("Motivational quotes", systemImage: "quote.bubble")
            }
            NavigationLink {
                DayLayoutSettingsView(settings: settings)
            } label: {
                Label("Day layout", systemImage: "list.bullet.rectangle")
            }
            NavigationLink {
                SavedMealsListView(settings: settings)
            } label: {
                Label("Saved meals", systemImage: "fork.knife")
            }
            NavigationLink {
                FoodPreferencesView(settings: settings)
            } label: {
                Label("Food preferences", systemImage: "heart.slash")
            }
            NavigationLink {
                FoodLookupSettingsView(settings: settings)
            } label: {
                Label("Food lookup", systemImage: "barcode.viewfinder")
            }
            NavigationLink {
                SmokingSettingsForm(settings: settings)
            } label: {
                Label("Smoking", systemImage: "smoke")
            }
            NavigationLink {
                DrinkingSettingsForm(settings: settings)
            } label: {
                Label("Drinking", systemImage: "wineglass")
            }
            NavigationLink {
                HydrationSettingsForm(settings: settings)
            } label: {
                Label("Hydration", systemImage: "drop.fill")
            }
            NavigationLink {
                SupplementsSettingsForm(settings: settings)
            } label: {
                Label("Supplements", systemImage: "pills.fill")
            }
            NavigationLink {
                BathroomSettingsForm(settings: settings)
            } label: {
                Label("Bathroom", systemImage: "toilet.fill")
            }
        } header: {
            Text("Tracking & habits")
        } footer: {
            Text("Day-to-day tracking options live here so Settings stays uncluttered.")
        }
    }

    @ViewBuilder
    private var presetsSection: some View {
        Section("My Presets") {
            if presets.isEmpty {
                Text("Save foods as presets when adding protein.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(presets, id: \.id) { preset in
                    HStack {
                        VStack(alignment: .leading) {
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
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var hungerScaleSection: some View {
        Section("Hunger Scale") {
            Text(HungerScale.guidance)
            ForEach(HungerScale.levels, id: \.0) { level in
                Text("\(level.0): \(level.1)")
                    .font(.caption)
            }
        }
    }

    #if os(iOS)
    @ViewBuilder
    private var backupSection: some View {
        Section {
            NavigationLink {
                BackupRestoreView { restored in
                    settings = restored
                }
            } label: {
                Label("Backup & restore", systemImage: "externaldrive.badge.timemachine")
            }
        } footer: {
            Text("Full data backup for reinstalls. Separate from day Export reports.")
        }
    }
    #endif

    private static var screenTitle: String {
        #if os(macOS)
        "Program"
        #else
        "Settings"
        #endif
    }

    private func loadTodayWeight(_ settings: AppSettings) {
        guard let weight = DataStore.weight(for: Date(), in: modelContext) else {
            todayWeightText = ""
            return
        }
        let value = settings.usesMetricWeight ? weight.weightLbs * 0.453592 : weight.weightLbs
        todayWeightText = String(format: "%.1f", value)
    }

    private func commitTodayWeight(_ settings: AppSettings) {
        let cleaned = todayWeightText.replacingOccurrences(of: ",", with: ".")
            .trimmingCharacters(in: .whitespaces)
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

    private func todayBMILine(_ settings: AppSettings) -> String? {
        guard let weight = DataStore.weight(for: Date(), in: modelContext),
              let bmi = BMICalculator.bmi(weightLbs: weight.weightLbs, heightInches: settings.heightInches)
        else { return nil }
        return String(format: "Today’s BMI: %.1f · %@", bmi, BMICalculator.category(for: bmi))
    }

    private func commitGoalWeight(_ settings: AppSettings) {
        let cleaned = goalWeightText.replacingOccurrences(of: ",", with: ".")
        if cleaned.trimmingCharacters(in: .whitespaces).isEmpty {
            return
        }
        guard let value = Double(cleaned), value > 0 else {
            if let goal = settings.goalWeightLbs {
                let display = settings.usesMetricWeight ? goal * 0.453592 : goal
                goalWeightText = String(format: "%.1f", display)
            }
            return
        }
        settings.goalWeightLbs = settings.usesMetricWeight ? value / 0.453592 : value
        goalWeightText = String(format: "%.1f", value)
        save(settings)
    }

    private func persistHeight(_ settings: AppSettings) {
        settings.heightInches = Double(heightFeet * 12 + heightInchesPart)
        save(settings)
    }

    private func save(_ settings: AppSettings) {
        modelContext.saveAndNotifyJournal()
    }

    #if os(iOS)
    private func appearanceFooter(for mode: AppearanceMode) -> String {
        switch mode {
        case .system:
            return "Follows this device’s Light/Dark setting."
        case .light:
            return "Always use Light appearance."
        case .dark:
            return "Always use Dark appearance."
        case .sunriseSunset:
            return "Light from approximate local sunrise to sunset, Dark at night. Uses your time zone (no location permission)."
        }
    }
    #endif

    #if os(iOS)
    private var healthButtonTitle: String {
        switch HealthKitService.shared.authStatus {
        case .unavailable: return "Health unavailable"
        case .notDetermined: return "Request Apple Health access"
        case .sharingDenied: return "Request again / re-check"
        case .sharingAuthorized: return "Re-check Health permissions"
        }
    }

    @ViewBuilder
    private var healthSection: some View {
        Section {
            Text(HealthKitService.shared.authStatus.title)
                .font(.subheadline.weight(.semibold))
            if let message = HealthKitService.shared.lastMessage {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Button(healthButtonTitle) {
                Task {
                    await HealthKitService.shared.requestAuthorization()
                }
            }
            if HealthKitService.shared.authStatus == .sharingDenied
                || HealthKitService.shared.authStatus == .sharingAuthorized {
                Button("Open Health / Settings") {
                    HealthKitService.shared.openHealthOrSystemSettings()
                }
            }
        } header: {
            Text("Health")
        } footer: {
            Text("Syncs water, weight, workouts, and alcoholic drinks to Apple Health. Cigarette counts stay in \(AppIdentity.displayName) only — HealthKit has no public nicotine type.")
        }
        .onAppear {
            HealthKitService.shared.refreshStatus()
        }
    }
    #endif
}

struct SmokingSettingsForm: View {
    @Bindable var settings: AppSettings
    @Environment(\.modelContext) private var modelContext
    @State private var packPriceText = ""
    @FocusState private var packPriceFocused: Bool

    var body: some View {
        Form {
            Section {
                Picker("Mode", selection: Binding(
                    get: { settings.smokingMode },
                    set: {
                        settings.smokingMode = $0
                        if $0 == .quit, settings.quitDate == nil {
                            settings.quitDate = Date()
                        }
                        save()
                    }
                )) {
                    ForEach(SmokingMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                Text(settings.smokingMode.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if settings.smokingMode == .reduce {
                    Stepper(
                        "Daily max: \(CigarettePackMath.packsLabel(cigarettes: settings.dailyCigaretteLimit)) (\(settings.dailyCigaretteLimit) cigs)",
                        value: Binding(
                            get: { Int((settings.dailyCigaretteLimitPacks * 2).rounded()) },
                            set: {
                                settings.dailyCigaretteLimitPacks = Double($0) / 2.0
                                save()
                            }
                        ),
                        in: 0...(AppLimits.cigaretteLimitMax * 2 / CigarettePackMath.perPack),
                        step: 1
                    )
                    Text("Adjusts in ½-pack steps (20 cigs per pack).")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                if settings.smokingMode == .quit {
                    DatePicker(
                        "Quit date",
                        selection: Binding(
                            get: { settings.quitDate ?? Date() },
                            set: {
                                settings.quitDate = $0
                                save()
                            }
                        ),
                        in: ...Date(),
                        displayedComponents: .date
                    )
                    Stepper(
                        "Was smoking: \(CigarettePackMath.packsLabel(cigarettes: settings.dailyCigaretteLimit))/day",
                        value: Binding(
                            get: { Int((settings.dailyCigaretteLimitPacks * 2).rounded()) },
                            set: {
                                settings.dailyCigaretteLimitPacks = max(0.5, Double($0) / 2.0)
                                save()
                            }
                        ),
                        in: 1...(AppLimits.cigaretteLimitMax * 2 / CigarettePackMath.perPack),
                        step: 1
                    )
                    Text("Used for the money-saved estimate (packs are always 20 cigs).")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    HStack {
                        Text("Pack price")
                        Spacer()
                        TextField("optional", text: $packPriceText)
                            .onPlanKeyboard(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .focused($packPriceFocused)
                            .frame(maxWidth: 100)
                        Text("$")
                            .foregroundStyle(.secondary)
                    }
                    Text("Used only to estimate money saved on smoke-free days.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            } footer: {
                Text("Off hides the section. Log by cigarette or pack (½ / 1 / 1½ / 2). Each entry is timestamped.")
            }
        }
        .navigationTitle("Smoking")
        .onPlanInlineNav()
        .onAppear {
            if let price = settings.cigarettePackPrice {
                packPriceText = String(format: "%.2f", price)
            }
        }
        .onChange(of: packPriceFocused) { _, focused in
            if !focused { commitPackPrice() }
        }
        .keyboardDoneToolbar(focus: $packPriceFocused)
    }

    private func commitPackPrice() {
        let cleaned = packPriceText.replacingOccurrences(of: ",", with: ".").trimmingCharacters(in: .whitespaces)
        if cleaned.isEmpty {
            settings.cigarettePackPrice = nil
            save()
            return
        }
        guard let value = Double(cleaned), value > 0 else {
            if let price = settings.cigarettePackPrice {
                packPriceText = String(format: "%.2f", price)
            } else {
                packPriceText = ""
            }
            return
        }
        settings.cigarettePackPrice = value
        packPriceText = String(format: "%.2f", value)
        save()
    }

    private func save() {
        modelContext.saveAndNotifyJournal()
    }
}

struct DrinkingSettingsForm: View {
    @Bindable var settings: AppSettings
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        Form {
            Section {
                Picker("Mode", selection: Binding(
                    get: { settings.drinkingMode },
                    set: {
                        settings.drinkingMode = $0
                        if $0 == .quit, settings.alcoholQuitDate == nil {
                            settings.alcoholQuitDate = Date()
                        }
                        save()
                    }
                )) {
                    ForEach(DrinkingMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                Text(settings.drinkingMode.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if settings.drinkingMode == .reduce {
                    Stepper(
                        "Daily max: \(settings.dailyDrinkLimit) drinks",
                        value: Binding(
                            get: { settings.dailyDrinkLimit },
                            set: {
                                settings.dailyDrinkLimit = $0
                                save()
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
                                save()
                            }
                        ),
                        in: ...Date(),
                        displayedComponents: .date
                    )
                }
            } footer: {
                Text("Same idea as smoking: count, reduce toward a max, or quit with urges. Each drink is timestamped.")
            }
        }
        .navigationTitle("Drinking")
        .onPlanInlineNav()
    }

    private func save() {
        modelContext.saveAndNotifyJournal()
    }
}

struct HydrationSettingsForm: View {
    @Bindable var settings: AppSettings
    @Environment(\.modelContext) private var modelContext
    @State private var hydrationTargetText = ""
    @FocusState private var hydrationTargetFocused: Bool

    var body: some View {
        Form {
            Section {
                Picker("Default bottle", selection: Binding(
                    get: { settings.defaultBottleOz },
                    set: {
                        settings.defaultBottleOz = $0
                        save()
                    }
                )) {
                    Text("8 oz").tag(8.0)
                    Text("12 oz").tag(12.0)
                    Text("16.9 oz").tag(16.9)
                    Text("20 oz").tag(20.0)
                    Text("24 oz").tag(24.0)
                }
                HStack {
                    Text("Daily target")
                    Spacer()
                    TextField("oz", text: $hydrationTargetText)
                        .onPlanKeyboard(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .focused($hydrationTargetFocused)
                        .frame(maxWidth: 100)
                    Text("oz")
                        .foregroundStyle(.secondary)
                }
                Stepper(
                    "Adjust: \(settings.hydrationTargetOz) oz",
                    value: Binding(
                        get: { settings.hydrationTargetOz },
                        set: {
                            settings.hydrationTargetOz = $0
                            hydrationTargetText = "\($0)"
                            save()
                        }
                    ),
                    in: 16...400,
                    step: 1
                )
                Toggle("Protein drinks count toward hydration", isOn: Binding(
                    get: { settings.proteinDrinksCountTowardHydration },
                    set: {
                        settings.proteinDrinksCountTowardHydration = $0
                        save()
                    }
                ))
                if settings.proteinDrinksCountTowardHydration {
                    Stepper(
                        "Default shake size: \(Int(settings.defaultShakeHydrationOz)) oz",
                        value: Binding(
                            get: { Int(settings.defaultShakeHydrationOz) },
                            set: {
                                settings.defaultShakeHydrationOz = Double($0)
                                save()
                            }
                        ),
                        in: 4...32,
                        step: 1
                    )
                }
            } footer: {
                Text("Type any whole number (e.g. 180). Bottle size only sets the drink taps, not the goal. Long-press a bottle on the day view to mark it as electrolyte.")
            }
        }
        .navigationTitle("Hydration")
        .onPlanInlineNav()
        .keyboardDoneToolbar(focus: $hydrationTargetFocused)
        .onAppear { hydrationTargetText = "\(settings.hydrationTargetOz)" }
        .onChange(of: hydrationTargetFocused) { _, focused in
            if !focused { commitHydrationTarget() }
        }
    }

    private func commitHydrationTarget() {
        if let value = Int(hydrationTargetText.filter(\.isNumber)) {
            settings.hydrationTargetOz = min(max(value, 16), 400)
            hydrationTargetText = "\(settings.hydrationTargetOz)"
            save()
        } else {
            hydrationTargetText = "\(settings.hydrationTargetOz)"
        }
    }

    private func save() {
        modelContext.saveAndNotifyJournal()
    }
}

struct BathroomSettingsForm: View {
    @Bindable var settings: AppSettings
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        Form {
            Section {
                Toggle("Show Bathroom section", isOn: Binding(
                    get: { settings.showBathroomSection },
                    set: {
                        settings.showBathroomSection = $0
                        save()
                    }
                ))
            } footer: {
                Text("Log urination and bowel movements with optional notes. The section stays collapsed by default for privacy.")
            }
        }
        .navigationTitle("Bathroom")
        .onPlanInlineNav()
    }

    private func save() {
        modelContext.saveAndNotifyJournal()
    }
}

struct SupplementsSettingsForm: View {
    @Bindable var settings: AppSettings
    @Environment(\.modelContext) private var modelContext

    @State private var newName = ""
    @State private var newDoses = 1
    @FocusState private var nameFocused: Bool

    private var defaultIDs: Set<String> {
        Set(SupplementDefinition.defaults.map(\.id))
    }

    var body: some View {
        Form {
            Section {
                Toggle("Show supplements section", isOn: Binding(
                    get: { settings.showSupplementsSection },
                    set: {
                        settings.showSupplementsSection = $0
                        save()
                    }
                ))
            } footer: {
                Text("Or hide individual items below. Dose reminders are per supplement — turn them on and set a time for each dose.")
            }

            if settings.showSupplementsSection {
                Section("Items") {
                    Button("Disable all items") {
                        var list = settings.supplements
                        for i in list.indices { list[i].isEnabled = false }
                        settings.supplements = list
                        save()
                    }
                    ForEach(Array(settings.supplements.enumerated()), id: \.element.id) { index, _ in
                        SupplementSettingsRow(
                            supplement: Binding(
                                get: { settings.supplements[index] },
                                set: { newValue in
                                    var list = settings.supplements
                                    list[index] = newValue
                                    settings.supplements = list
                                    save()
                                }
                            ),
                            canDelete: !defaultIDs.contains(settings.supplements[index].id),
                            onDelete: {
                                var list = settings.supplements
                                list.removeAll { $0.id == settings.supplements[index].id }
                                settings.supplements = list
                                save()
                            }
                        )
                    }
                }

                Section {
                    TextField("Supplement name", text: $newName)
                        .focused($nameFocused)
                    Stepper("Doses per day: \(newDoses)", value: $newDoses, in: 1...8)
                    Button("Add supplement") {
                        addCustom()
                    }
                    .disabled(newName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                } header: {
                    Text("Add your own")
                } footer: {
                    Text("Custom supplements show on the day card with the built-in list. You can set reminders after adding.")
                }
            }
        }
        .navigationTitle("Supplements")
        .onPlanInlineNav()
        .keyboardDoneToolbar(focus: $nameFocused)
    }

    private func addCustom() {
        let name = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        let slug = name
            .lowercased()
            .replacingOccurrences(of: " ", with: "-")
            .filter { $0.isLetter || $0.isNumber || $0 == "-" }
        let id = "custom-\(slug.isEmpty ? UUID().uuidString : slug)-\(UUID().uuidString.prefix(6))"
        var list = settings.supplements
        list.append(SupplementDefinition(id: id, name: name, dosesPerDay: newDoses, isEnabled: true))
        settings.supplements = list
        newName = ""
        newDoses = 1
        save()
    }

    private func save() {
        modelContext.saveAndNotifyJournal()
        Task { await NotificationService.shared.reschedule(using: settings) }
    }
}

private struct SupplementSettingsRow: View {
    @Binding var supplement: SupplementDefinition
    var canDelete: Bool
    var onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Toggle(isOn: $supplement.isEnabled) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(supplement.name)
                        Text("\(supplement.dosesPerDay) dose\(supplement.dosesPerDay == 1 ? "" : "s")/day")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                if canDelete {
                    Button(role: .destructive, action: onDelete) {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.borderless)
                }
            }

            if supplement.isEnabled {
                Stepper(
                    "Doses: \(supplement.dosesPerDay)",
                    value: Binding(
                        get: { supplement.dosesPerDay },
                        set: { newValue in
                            supplement.dosesPerDay = newValue
                            supplement.syncReminderTimes()
                        }
                    ),
                    in: 1...8
                )

                Toggle("Reminders", isOn: $supplement.reminderEnabled)

                if supplement.reminderEnabled {
                    ForEach(0..<supplement.dosesPerDay, id: \.self) { doseIndex in
                        DatePicker(
                            "Dose \(doseIndex + 1)",
                            selection: Binding(
                                get: {
                                    let time = supplement.reminderTimes[doseIndex]
                                    return Calendar.current.date(
                                        bySettingHour: time.hour,
                                        minute: time.minute,
                                        second: 0,
                                        of: Date()
                                    ) ?? Date()
                                },
                                set: { date in
                                    let comps = Calendar.current.dateComponents([.hour, .minute], from: date)
                                    supplement.syncReminderTimes()
                                    guard supplement.reminderTimes.indices.contains(doseIndex) else { return }
                                    supplement.reminderTimes[doseIndex] = SupplementReminderTime(
                                        hour: comps.hour ?? 8,
                                        minute: comps.minute ?? 0
                                    )
                                }
                            ),
                            displayedComponents: .hourAndMinute
                        )
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}

struct FoodLookupSettingsView: View {
    @Bindable var settings: AppSettings
    @Environment(\.modelContext) private var modelContext
    @FocusState private var keyFocused: Bool

    @State private var keyVisible = false
    @State private var isTesting = false
    @State private var testResult: USDAFoodDataClient.KeyTestResult?
    @State private var lastTestedKey = ""

    private var keyBinding: Binding<String> {
        Binding(
            get: { settings.usdaAPIKey },
            set: {
                settings.usdaAPIKey = $0
                modelContext.saveAndNotifyJournal()
                if $0.trimmingCharacters(in: .whitespacesAndNewlines) != lastTestedKey {
                    testResult = nil
                }
            }
        )
    }

    var body: some View {
        Form {
            Section {
                HStack(alignment: .center, spacing: 8) {
                    Group {
                        if keyVisible {
                            TextField("USDA API key", text: keyBinding)
                        } else {
                            SecureField("USDA API key", text: keyBinding)
                        }
                    }
                    .onPlanNeverAutocapitalize()
                    .autocorrectionDisabled()
                    .focused($keyFocused)
                    .textContentType(.password)
                    .font(.body.monospaced())

                    Button(keyVisible ? "Hide" : "View") {
                        keyVisible.toggle()
                    }
                    .font(.subheadline.weight(.semibold))
                    .buttonStyle(.borderless)
                }

                Button {
                    Task { await runKeyTest() }
                } label: {
                    if isTesting {
                        HStack {
                            ProgressView()
                            Text("Testing key…")
                        }
                    } else {
                        Label("Test API key", systemImage: "antenna.radiowaves.left.and.right")
                    }
                }
                .disabled(settings.usdaAPIKey.isEmpty || isTesting)

                if let testResult {
                    Label(testResult.message, systemImage: testResult.succeeded ? "checkmark.circle.fill" : "xmark.octagon.fill")
                        .font(.footnote)
                        .foregroundStyle(testResult.succeeded ? Color.green : Color.red)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if !settings.usdaAPIKey.isEmpty {
                    Button("Clear key", role: .destructive) {
                        settings.usdaAPIKey = ""
                        testResult = nil
                        lastTestedKey = ""
                        keyVisible = false
                        modelContext.saveAndNotifyJournal()
                    }
                }
            } header: {
                Text("USDA FoodData Central")
            } footer: {
                Text("Optional. Free key from api.data.gov. Stored in Keychain on this device — not iCloud or backups. Used when local catalog and Open Food Facts are thin. Testing runs a tiny “egg” search.")
            }

            Section {
                Label("No API key required", systemImage: "checkmark.seal")
                    .foregroundStyle(.secondary)
                Text("Barcode scans use Open Food Facts with a custom User-Agent. Read-only lookups only.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } header: {
                Text("Open Food Facts")
            }

            Section("Attribution") {
                Text("Product data © Open Food Facts contributors (ODbL). Nutrition search data from USDA FoodData Central.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Link("Get a USDA API key", destination: URL(string: "https://api.data.gov/signup/")!)
                Link("Open Food Facts API", destination: URL(string: "https://world.openfoodfacts.org/data")!)
            }
        }
        .navigationTitle("Food lookup")
        .onPlanInlineNav()
        .keyboardDoneToolbar(focus: $keyFocused)
        .onChange(of: keyFocused) { _, focused in
            // Auto-test once when you leave the key field after pasting/typing.
            if !focused,
               !settings.usdaAPIKey.isEmpty,
               settings.usdaAPIKey != lastTestedKey,
               !isTesting {
                Task { await runKeyTest() }
            }
        }
    }

    @MainActor
    private func runKeyTest() async {
        let key = settings.usdaAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else {
            testResult = USDAFoodDataClient.KeyTestResult(
                succeeded: false,
                message: "Paste a USDA API key first.",
                sampleFoodName: nil
            )
            return
        }
        isTesting = true
        testResult = nil
        let result = await USDAFoodDataClient.testAPIKey(key)
        testResult = result
        lastTestedKey = key
        isTesting = false
    }
}

