import SwiftUI
import SwiftData
import UserNotifications
import OnPlanCore

struct MacNotificationsSettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var store: OnPlanStore
    @Query private var allSettings: [AppSettings]
    @State private var authStatus: UNAuthorizationStatus = .notDetermined
    @State private var showSupplements = false

    private let columns = [GridItem(.adaptive(minimum: 280), spacing: 12)]

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
        .task { await refreshPermission() }
        .sheet(isPresented: $showSupplements) {
            if let settings = allSettings.first {
                NavigationStack {
                    SupplementsSettingsForm(settings: settings)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Done") { showSupplements = false }
                            }
                        }
                }
                .frame(minWidth: 520, minHeight: 420)
            }
        }
    }

    private func content(_ settings: AppSettings) -> some View {
        MacSettingsScroll {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 280), spacing: 12)], spacing: 12) {
                thisMacPanel
                pausePanel(settings)
            }
            LazyVGrid(columns: columns, spacing: 12) {
                reminderCard(
                    title: "Evening plan",
                    systemImage: "checkmark.seal",
                    subtitle: "Yes / No on the banner.",
                    enabled: boolBinding(settings, \.eveningCheckInEnabled),
                    time: timeBinding(settings, hour: \.eveningCheckInHour, minute: \.eveningCheckInMinute, fallback: (20, 0))
                )
                reminderCard(
                    title: "Ketosis",
                    systemImage: "flame",
                    subtitle: "Yes / No. Strips, meter, or a guess.",
                    enabled: boolBinding(settings, \.ketosisCheckInEnabled),
                    time: timeBinding(settings, hour: \.ketosisCheckInHour, minute: \.ketosisCheckInMinute, fallback: (20, 5))
                )
                reminderCard(
                    title: "Daily check-in",
                    systemImage: "list.clipboard",
                    subtitle: "Finish the rest of today’s sheet.",
                    enabled: boolBinding(settings, \.genericCheckInEnabled),
                    time: timeBinding(settings, hour: \.genericCheckInHour, minute: \.genericCheckInMinute, fallback: (19, 30))
                )
                waterCard(settings)
                reminderCard(
                    title: "Meal",
                    systemImage: "fork.knife",
                    subtitle: "Eat or log a meal.",
                    enabled: boolBinding(settings, \.mealReminderEnabled),
                    time: timeBinding(settings, hour: \.mealReminderHour, minute: \.mealReminderMinute, fallback: (12, 0))
                )
                reminderCard(
                    title: "Weigh-in",
                    systemImage: "scalemass",
                    subtitle: "Log weight when you’re ready.",
                    enabled: boolBinding(settings, \.weighReminderEnabled),
                    time: timeBinding(settings, hour: \.weighReminderHour, minute: \.weighReminderMinute, fallback: (7, 0))
                )
                reminderCard(
                    title: "Smoking",
                    systemImage: "smoke",
                    subtitle: settings.smokingMode.showsSection
                        ? "Only fires while smoking is on."
                        : "Turn smoking on in Program first.",
                    enabled: boolBinding(settings, \.smokingCheckInEnabled),
                    time: timeBinding(settings, hour: \.smokingCheckInHour, minute: \.smokingCheckInMinute, fallback: (16, 0))
                )
                reminderCard(
                    title: "Drinking",
                    systemImage: "wineglass",
                    subtitle: settings.drinkingMode.showsSection
                        ? "Only fires while drinking is on."
                        : "Turn drinking on in Program first.",
                    enabled: boolBinding(settings, \.drinkingCheckInEnabled),
                    time: timeBinding(settings, hour: \.drinkingCheckInHour, minute: \.drinkingCheckInMinute, fallback: (17, 0))
                )
                reminderCard(
                    title: "Stay on plan",
                    systemImage: "quote.closing",
                    subtitle: "Daily quote. Edit the list in Program.",
                    enabled: boolBinding(settings, \.motivationReminderEnabled),
                    time: timeBinding(settings, hour: \.motivationReminderHour, minute: \.motivationReminderMinute, fallback: (8, 0))
                )
                bodyCompCard(settings)
            }
            supplementsPanel(settings)
        }
    }

    private var thisMacPanel: some View {
        SettingsPanel(
            title: "This Mac",
            systemImage: "laptopcomputer",
            subtitle: "Banners here are independent of iPhone."
        ) {
            Toggle("Reminders on this Mac", isOn: Binding(
                get: { store.preferences.notifyOnThisMac },
                set: { value in
                    var prefs = store.preferences
                    prefs.notifyOnThisMac = value
                    store.applyPreferences(prefs)
                    MacNotifications.sync(requestIfNeeded: value)
                }
            ))
            .toggleStyle(.checkbox)

            Text(permissionCopy)
                .appFont(.caption2)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                if authStatus == .notDetermined {
                    Button("Allow notifications") {
                        Task { await enableNotifications() }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .disabled(!store.preferences.notifyOnThisMac)
                }
                if authStatus == .denied {
                    Button("Open System Settings") {
                        MacNotifications.openSystemSettings()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                } else if authStatus == .authorized || authStatus == .provisional {
                    Button("Notification settings…") {
                        MacNotifications.openSystemSettings()
                    }
                    .controlSize(.small)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .top)
    }

    private func pausePanel(_ settings: AppSettings) -> some View {
        SettingsPanel(
            title: "All devices",
            systemImage: "pause.circle",
            subtitle: "This toggle lives in the journal, so iPhone pauses too."
        ) {
            Toggle("Pause every reminder", isOn: Binding(
                get: { settings.notificationsPaused },
                set: {
                    settings.notificationsPaused = $0
                    persist(settings)
                }
            ))
            .toggleStyle(.checkbox)
            Text("Leaves the individual times alone. Turn it off when you want them back.")
                .appFont(.caption2)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .top)
    }

    private func reminderCard(
        title: String,
        systemImage: String,
        subtitle: String,
        enabled: Binding<Bool>,
        time: Binding<Date>
    ) -> some View {
        SettingsPanel(title: title, systemImage: systemImage, subtitle: subtitle, compact: true) {
            Toggle("On", isOn: enabled)
                .toggleStyle(.checkbox)
            if enabled.wrappedValue {
                DatePicker("Time", selection: time, displayedComponents: .hourAndMinute)
                    .controlSize(.small)
            }
        }
    }

    private func waterCard(_ settings: AppSettings) -> some View {
        SettingsPanel(
            title: "Water",
            systemImage: "drop.fill",
            subtitle: "Daytime nudges, 9 AM–6 PM.",
            compact: true
        ) {
            Toggle("On", isOn: boolBinding(settings, \.waterReminderEnabled))
                .toggleStyle(.checkbox)
            if settings.waterReminderEnabled {
                Stepper(
                    "Every \(max(settings.waterReminderIntervalHours, 2)) hours",
                    value: Binding(
                        get: { settings.waterReminderIntervalHours },
                        set: {
                            settings.waterReminderIntervalHours = $0
                            persist(settings)
                        }
                    ),
                    in: 2...6
                )
            }
        }
    }

    private func bodyCompCard(_ settings: AppSettings) -> some View {
        SettingsPanel(
            title: "Body composition",
            systemImage: "list.clipboard",
            subtitle: "Clinic receipt reminder.",
            compact: true
        ) {
            Toggle("On", isOn: boolBinding(settings, \.bodyCompReminderEnabled))
                .toggleStyle(.checkbox)
            if settings.bodyCompReminderEnabled {
                Picker("Cadence", selection: Binding(
                    get: { settings.bodyCompReminderCadence },
                    set: {
                        settings.bodyCompReminderCadence = $0
                        persist(settings)
                    }
                )) {
                    ForEach(BodyCompReminderCadence.allCases) { cadence in
                        Text(cadence.rawValue).tag(cadence)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                DatePicker(
                    "Time",
                    selection: timeBinding(
                        settings,
                        hour: \.bodyCompReminderHour,
                        minute: \.bodyCompReminderMinute,
                        fallback: (9, 0)
                    ),
                    displayedComponents: .hourAndMinute
                )
                if settings.bodyCompReminderCadence == .weekly {
                    Picker("Weekday", selection: Binding(
                        get: { settings.bodyCompReminderWeekday },
                        set: {
                            settings.bodyCompReminderWeekday = $0
                            persist(settings)
                        }
                    )) {
                        ForEach(1...7, id: \.self) { weekday in
                            Text(weekdayName(weekday)).tag(weekday)
                        }
                    }
                } else {
                    Stepper(
                        "Day of month: \(settings.bodyCompReminderDayOfMonth)",
                        value: Binding(
                            get: { settings.bodyCompReminderDayOfMonth },
                            set: {
                                settings.bodyCompReminderDayOfMonth = $0
                                persist(settings)
                            }
                        ),
                        in: 1...31
                    )
                }
            }
        }
    }

    private func supplementsPanel(_ settings: AppSettings) -> some View {
        let active = settings.supplements.filter { $0.isEnabled && $0.reminderEnabled }
        return SettingsPanel(
            title: "Supplement doses",
            systemImage: "pills.fill",
            subtitle: "Times are set per supplement."
        ) {
            if active.isEmpty {
                Text("No dose reminders are on.")
                    .appFont(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(active) { supplement in
                    HStack {
                        Text(supplement.name)
                            .appFont(.subheadline, weight: .semibold)
                        Spacer()
                        Text(
                            supplement.reminderTimes
                                .prefix(supplement.dosesPerDay)
                                .map { timeLabel($0) }
                                .joined(separator: " · ")
                        )
                        .appFont(.caption)
                        .foregroundStyle(.secondary)
                    }
                }
            }
            Button("Manage supplements…") { showSupplements = true }
                .controlSize(.small)
        }
    }

    private var permissionCopy: String {
        switch authStatus {
        case .authorized, .provisional:
            return store.preferences.notifyOnThisMac
                ? "macOS will show banners for the reminders that are on below."
                : "Off on this Mac. iPhone is unchanged."
        case .denied:
            return "Notifications are off in System Settings → Notifications → Daily On Plan."
        default:
            return "Allow once so this Mac can remind you."
        }
    }

    private func boolBinding(_ settings: AppSettings, _ keyPath: ReferenceWritableKeyPath<AppSettings, Bool>) -> Binding<Bool> {
        Binding(
            get: { settings[keyPath: keyPath] },
            set: {
                settings[keyPath: keyPath] = $0
                persist(settings)
            }
        )
    }

    private func timeBinding(
        _ settings: AppSettings,
        hour: ReferenceWritableKeyPath<AppSettings, Int>,
        minute: ReferenceWritableKeyPath<AppSettings, Int>,
        fallback: (Int, Int)
    ) -> Binding<Date> {
        Binding(
            get: { date(hour: settings[keyPath: hour], minute: settings[keyPath: minute]) },
            set: { newValue in
                let c = Calendar.current.dateComponents([.hour, .minute], from: newValue)
                settings[keyPath: hour] = c.hour ?? fallback.0
                settings[keyPath: minute] = c.minute ?? fallback.1
                persist(settings)
            }
        )
    }

    private func date(hour: Int, minute: Int) -> Date {
        Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: Date()) ?? Date()
    }

    private func timeLabel(_ time: SupplementReminderTime) -> String {
        date(hour: time.hour, minute: time.minute).formatted(date: .omitted, time: .shortened)
    }

    private func weekdayName(_ weekday: Int) -> String {
        let symbols = Calendar.current.weekdaySymbols
        let index = weekday - 1
        guard symbols.indices.contains(index) else { return "Day \(weekday)" }
        return symbols[index]
    }

    private func persist(_ settings: AppSettings) {
        modelContext.saveAndNotifyJournal()
        Task { await NotificationService.shared.reschedule(using: settings) }
    }

    private func refreshPermission() async {
        authStatus = await NotificationService.shared.authorizationStatus()
    }

    private func enableNotifications() async {
        _ = await NotificationService.shared.requestPermission()
        await refreshPermission()
        await MacNotifications.syncNow(requestIfNeeded: false)
    }
}
