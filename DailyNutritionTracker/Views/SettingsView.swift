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
    @State private var packPriceText = ""
    @FocusState private var hydrationTargetFocused: Bool
    @FocusState private var goalWeightFocused: Bool
    @FocusState private var packPriceFocused: Bool
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
                            Text("BMI uses height with each day’s weight. Goal weight shows to-go on the Weight card and Snapshot.")
                        }
                        .onChange(of: heightFeet) { _, _ in persistHeight(settings) }
                        .onChange(of: heightInchesPart) { _, _ in persistHeight(settings) }
                        .onChange(of: goalWeightFocused) { _, focused in
                            if !focused { commitGoalWeight(settings) }
                        }

                        Section {
                            Picker("Mode", selection: Binding(
                                get: { settings.smokingMode },
                                set: {
                                    settings.smokingMode = $0
                                    if $0 == .quit, settings.quitDate == nil {
                                        settings.quitDate = Date()
                                    }
                                    save(settings)
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
                                    "Daily max: \(settings.dailyCigaretteLimit)",
                                    value: Binding(
                                        get: { settings.dailyCigaretteLimit },
                                        set: {
                                            settings.dailyCigaretteLimit = $0
                                            save(settings)
                                        }
                                    ),
                                    in: 0...AppLimits.cigaretteLimitMax,
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
                                Stepper(
                                    "Cigs per pack: \(settings.cigarettesPerPack)",
                                    value: Binding(
                                        get: { settings.cigarettesPerPack },
                                        set: {
                                            settings.cigarettesPerPack = $0
                                            save(settings)
                                        }
                                    ),
                                    in: 1...40,
                                    step: 1
                                )
                                HStack {
                                    TextField("Pack price (optional)", text: $packPriceText)
                                        .keyboardType(.decimalPad)
                                        .focused($packPriceFocused)
                                    Text("$")
                                        .foregroundStyle(.secondary)
                                }
                                Text("Used only to estimate money saved on smoke-free days.")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        } header: {
                            Text("Smoking")
                        } footer: {
                            Text("Off hides the section. Count is a simple tap counter. Reduce adds a daily max. Quit adds smoke-free days and an urge log.")
                        }
                        .onChange(of: packPriceFocused) { _, focused in
                            if !focused { commitPackPrice(settings) }
                        }

                        Section {
                            NavigationLink {
                                NotificationsSettingsView(settings: settings)
                            } label: {
                                Label("Notifications", systemImage: "bell.badge")
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
                        } header: {
                            Text("Reminders & meals")
                        } footer: {
                            Text("Notifications default to evening plan, ketosis check, and daily check-in. Food preferences filter allergies and picky-eater picks.")
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
                        } header: {
                            Text("Hydration defaults")
                        } footer: {
                            Text("Type any whole number (e.g. 180). Bottle size only sets the drink taps, not the goal.")
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

                        Section("Health") {
                            Button("Request Apple Health access") {
                                Task { await HealthKitService.shared.requestAuthorization() }
                            }
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
                        packPriceFocused = false
                        if let settings {
                            commitHydrationTarget(settings)
                            commitGoalWeight(settings)
                            commitPackPrice(settings)
                        }
                        Keyboard.dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        if let settings {
                            commitHydrationTarget(settings)
                            commitGoalWeight(settings)
                            commitPackPrice(settings)
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
                if let price = s.cigarettePackPrice {
                    packPriceText = String(format: "%.2f", price)
                } else {
                    packPriceText = ""
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

    private func commitPackPrice(_ settings: AppSettings) {
        let cleaned = packPriceText.replacingOccurrences(of: ",", with: ".").trimmingCharacters(in: .whitespaces)
        if cleaned.isEmpty {
            settings.cigarettePackPrice = nil
            save(settings)
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
        save(settings)
    }

    private func persistHeight(_ settings: AppSettings) {
        settings.heightInches = Double(heightFeet * 12 + heightInchesPart)
        save(settings)
    }

    private func save(_ settings: AppSettings) {
        try? modelContext.save()
    }
}
