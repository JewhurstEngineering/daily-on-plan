import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var settings: AppSettings?
    @State private var heightFeet = 5
    @State private var heightInchesPart = 8
    @State private var hydrationTargetText = ""
    @State private var goalWeightText = ""
    @FocusState private var hydrationTargetFocused: Bool
    @FocusState private var goalWeightFocused: Bool
    @Query(sort: \CustomFoodPreset.name) private var presets: [CustomFoodPreset]

    var body: some View {
        NavigationStack {
            Group {
                if let settings {
                    Form {
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
                            .pickerStyle(.segmented)

                            Text("System follows your iPhone’s Light/Dark setting.")
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
                                TextField("Goal weight", text: $goalWeightText)
                                    .keyboardType(.decimalPad)
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
                            Text("Height and age prefill body composition receipts. BMI uses height with each day’s weight.")
                        }
                        .onChange(of: heightFeet) { _, _ in persistHeight(settings) }
                        .onChange(of: heightInchesPart) { _, _ in persistHeight(settings) }
                        .onChange(of: goalWeightFocused) { _, focused in
                            if !focused { commitGoalWeight(settings) }
                        }

                        Section {
                            NavigationLink {
                                BodyCompositionListView(showsDismissButton: false)
                            } label: {
                                Label("Body composition", systemImage: "list.clipboard")
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
                                SmokingSettingsForm(settings: settings)
                            } label: {
                                Label("Smoking", systemImage: "smoke")
                            }
                            NavigationLink {
                                DrinkingSettingsForm(settings: settings)
                            } label: {
                                Label("Drinking", systemImage: "wineglass")
                            }
                        } header: {
                            Text("Reminders & meals")
                        } footer: {
                            Text("Smoking and drinking live here so the main settings stay light. Body composition receipts are under Body composition.")
                        }

                        Section {
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
                            HStack {
                                TextField("Daily target", text: $hydrationTargetText)
                                    .keyboardType(.numberPad)
                                    .focused($hydrationTargetFocused)
                                    .onChange(of: hydrationTargetText) { _, newValue in
                                        let digits = newValue.filter(\.isNumber)
                                        if digits != newValue { hydrationTargetText = digits }
                                    }
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
                                        save(settings)
                                    }
                                ),
                                in: 16...400,
                                step: 1
                            )
                            Toggle("Protein drinks count toward hydration", isOn: Binding(
                                get: { settings.proteinDrinksCountTowardHydration },
                                set: {
                                    settings.proteinDrinksCountTowardHydration = $0
                                    save(settings)
                                }
                            ))
                            if settings.proteinDrinksCountTowardHydration {
                                Stepper(
                                    "Default shake size: \(Int(settings.defaultShakeHydrationOz)) oz",
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
                        } header: {
                            Text("Hydration defaults")
                        } footer: {
                            Text("Type any whole number (e.g. 180). Bottle size only sets the drink taps, not the goal. Long-press a bottle on the day view to mark it as electrolyte. Shakes can also add ounces when the toggle is on.")
                        }

                        Section("Supplements") {
                            Toggle("Show supplements section", isOn: Binding(
                                get: { settings.showSupplementsSection },
                                set: {
                                    settings.showSupplementsSection = $0
                                    save(settings)
                                }
                            ))
                            Text("Or hide individual items from the gear on the Supplements card.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                            if settings.showSupplementsSection {
                                Button("Disable all items") {
                                    var list = settings.supplements
                                    for i in list.indices { list[i].isEnabled = false }
                                    settings.supplements = list
                                    save(settings)
                                }
                                ForEach(Array(settings.supplements.enumerated()), id: \.element.id) { index, supplement in
                                    Toggle(isOn: Binding(
                                        get: { settings.supplements[index].isEnabled },
                                        set: { newValue in
                                            var list = settings.supplements
                                            list[index].isEnabled = newValue
                                            settings.supplements = list
                                            save(settings)
                                        }
                                    )) {
                                        Text(supplement.name)
                                    }
                                }
                            }
                        }

                        Section {
                            Toggle("Show Bathroom section", isOn: Binding(
                                get: { settings.showBathroomSection },
                                set: {
                                    settings.showBathroomSection = $0
                                    save(settings)
                                }
                            ))
                        } header: {
                            Text("Bathroom")
                        } footer: {
                            Text("Log urination and bowel movements with optional notes. The section stays collapsed by default for privacy.")
                        }

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
                                            try? modelContext.save()
                                        } label: {
                                            Image(systemName: "trash")
                                        }
                                    }
                                }
                            }
                        }

                        Section("Hunger Scale") {
                            Text(HungerScale.guidance)
                            ForEach(HungerScale.levels, id: \.0) { level in
                                Text("\(level.0): \(level.1)")
                                    .font(.caption)
                            }
                        }

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
                } else {
                    ProgressView()
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        hydrationTargetFocused = false
                        goalWeightFocused = false
                        if let settings {
                            commitHydrationTarget(settings)
                            commitGoalWeight(settings)
                        }
                        Keyboard.dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        if let settings {
                            commitHydrationTarget(settings)
                            commitGoalWeight(settings)
                        }
                        Keyboard.dismiss()
                        dismiss()
                    }
                }
            }
            .onAppear {
                let s = DataStore.settings(in: modelContext)
                settings = s
                hydrationTargetText = "\(s.hydrationTargetOz)"
                if let goal = s.goalWeightLbs {
                    let value = s.usesMetricWeight ? goal * 0.453592 : goal
                    goalWeightText = String(format: "%.1f", value)
                } else {
                    goalWeightText = ""
                }
                let total = Int(s.heightInches)
                if total > 0 {
                    heightFeet = total / 12
                    heightInchesPart = total % 12
                }
            }
            .onChange(of: hydrationTargetFocused) { _, focused in
                if !focused, let settings {
                    commitHydrationTarget(settings)
                }
            }
        }
    }

    private func commitHydrationTarget(_ settings: AppSettings) {
        if let value = Int(hydrationTargetText.filter(\.isNumber)) {
            settings.hydrationTargetOz = min(max(value, 16), 400)
            hydrationTargetText = "\(settings.hydrationTargetOz)"
            save(settings)
        } else {
            hydrationTargetText = "\(settings.hydrationTargetOz)"
        }
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
        try? modelContext.save()
    }

    private var healthButtonTitle: String {
        switch HealthKitService.shared.authStatus {
        case .unavailable: return "Health unavailable"
        case .notDetermined: return "Request Apple Health access"
        case .sharingDenied: return "Request again / re-check"
        case .sharingAuthorized: return "Re-check Health permissions"
        }
    }
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
                            .keyboardType(.decimalPad)
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
        .navigationBarTitleDisplayMode(.inline)
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
        try? modelContext.save()
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
        .navigationBarTitleDisplayMode(.inline)
    }

    private func save() {
        try? modelContext.save()
    }
}
