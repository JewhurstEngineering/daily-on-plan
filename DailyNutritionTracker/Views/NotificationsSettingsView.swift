import SwiftUI
import SwiftData
import UserNotifications

struct NotificationsSettingsView: View {
    @Bindable var settings: AppSettings
    @Environment(\.modelContext) private var modelContext
    @State private var authStatus: UNAuthorizationStatus = .notDetermined

    var body: some View {
        Form {
            Section {
                Text("Evening plan, ketosis check, and daily check-in are on by default. Everything else is optional — turn on what helps, leave the rest off.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if authStatus == .denied {
                Section {
                    Text("Notifications are turned off in iOS Settings. Enable them to receive reminders.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Button("Open System Settings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }
                }
            }

            Section {
                Toggle("Pause all reminders", isOn: Binding(
                    get: { settings.notificationsPaused },
                    set: {
                        settings.notificationsPaused = $0
                        persist()
                    }
                ))
            } footer: {
                Text("Temporarily silences every reminder without changing your individual toggles.")
            }

            reminderRow(
                title: "Evening plan",
                explanation: "Asks “Did you follow the plan today?” Press and hold (or swipe down) the notification to reveal Yes / No — iOS hides those buttons on the compact banner.",
                enabled: Binding(
                    get: { settings.eveningCheckInEnabled },
                    set: {
                        settings.eveningCheckInEnabled = $0
                        persist()
                    }
                ),
                time: Binding(
                    get: { date(hour: settings.eveningCheckInHour, minute: settings.eveningCheckInMinute) },
                    set: { d in
                        let c = Calendar.current.dateComponents([.hour, .minute], from: d)
                        settings.eveningCheckInHour = c.hour ?? 20
                        settings.eveningCheckInMinute = c.minute ?? 0
                        persist()
                    }
                ),
                showTime: settings.eveningCheckInEnabled
            )

            reminderRow(
                title: "Ketosis check",
                explanation: "Asks “Are you in ketosis today?” with Yes / No (press and hold). People usually know via urine strips, a blood ketone meter, breath acetone, or a best-guess self-report — the app doesn’t measure it.",
                enabled: Binding(
                    get: { settings.ketosisCheckInEnabled },
                    set: {
                        settings.ketosisCheckInEnabled = $0
                        persist()
                    }
                ),
                time: Binding(
                    get: { date(hour: settings.ketosisCheckInHour, minute: settings.ketosisCheckInMinute) },
                    set: { d in
                        let c = Calendar.current.dateComponents([.hour, .minute], from: d)
                        settings.ketosisCheckInHour = c.hour ?? 20
                        settings.ketosisCheckInMinute = c.minute ?? 5
                        persist()
                    }
                ),
                showTime: settings.ketosisCheckInEnabled
            )

            reminderRow(
                title: "Daily check-in",
                explanation: "A gentle nudge to finish logging protein, feelings, and the rest of your day before it ends.",
                enabled: Binding(
                    get: { settings.genericCheckInEnabled },
                    set: {
                        settings.genericCheckInEnabled = $0
                        persist()
                    }
                ),
                time: Binding(
                    get: { date(hour: settings.genericCheckInHour, minute: settings.genericCheckInMinute) },
                    set: { d in
                        let c = Calendar.current.dateComponents([.hour, .minute], from: d)
                        settings.genericCheckInHour = c.hour ?? 19
                        settings.genericCheckInMinute = c.minute ?? 30
                        persist()
                    }
                ),
                showTime: settings.genericCheckInEnabled
            )

            Section {
                Toggle("Water reminders", isOn: Binding(
                    get: { settings.waterReminderEnabled },
                    set: {
                        settings.waterReminderEnabled = $0
                        persist()
                    }
                ))
                Text("Periodic daytime nudges to drink. Off by default so it doesn’t feel spammy. Press and hold the notification for “Logged a drink.”")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                if settings.waterReminderEnabled {
                    Stepper(
                        "About every \(settings.waterReminderIntervalHours) hours (9am–6pm)",
                        value: Binding(
                            get: { settings.waterReminderIntervalHours },
                            set: {
                                settings.waterReminderIntervalHours = $0
                                persist()
                            }
                        ),
                        in: 2...6
                    )
                }
            }

            reminderRow(
                title: "Meal reminder",
                explanation: "Reminds you to eat or log a meal at a time you choose. Off by default.",
                enabled: Binding(
                    get: { settings.mealReminderEnabled },
                    set: {
                        settings.mealReminderEnabled = $0
                        persist()
                    }
                ),
                time: Binding(
                    get: { date(hour: settings.mealReminderHour, minute: settings.mealReminderMinute) },
                    set: { d in
                        let c = Calendar.current.dateComponents([.hour, .minute], from: d)
                        settings.mealReminderHour = c.hour ?? 12
                        settings.mealReminderMinute = c.minute ?? 0
                        persist()
                    }
                ),
                showTime: settings.mealReminderEnabled
            )

            reminderRow(
                title: "Weigh-in",
                explanation: "Morning (or anytime) reminder to weigh yourself and log it. Off by default.",
                enabled: Binding(
                    get: { settings.weighReminderEnabled },
                    set: {
                        settings.weighReminderEnabled = $0
                        persist()
                    }
                ),
                time: Binding(
                    get: { date(hour: settings.weighReminderHour, minute: settings.weighReminderMinute) },
                    set: { d in
                        let c = Calendar.current.dateComponents([.hour, .minute], from: d)
                        settings.weighReminderHour = c.hour ?? 7
                        settings.weighReminderMinute = c.minute ?? 0
                        persist()
                    }
                ),
                showTime: settings.weighReminderEnabled
            )

            reminderRow(
                title: "Smoking check-in",
                explanation: settings.smokingMode.showsSection
                    ? "Soft nudge to log cigarettes / urges. Off by default. Only fires while Smoking mode is on."
                    : "Turn on Smoking in Settings (mode ≠ Off) to enable this reminder.",
                enabled: Binding(
                    get: { settings.smokingCheckInEnabled },
                    set: {
                        settings.smokingCheckInEnabled = $0
                        persist()
                    }
                ),
                time: Binding(
                    get: { date(hour: settings.smokingCheckInHour, minute: settings.smokingCheckInMinute) },
                    set: { d in
                        let c = Calendar.current.dateComponents([.hour, .minute], from: d)
                        settings.smokingCheckInHour = c.hour ?? 16
                        settings.smokingCheckInMinute = c.minute ?? 0
                        persist()
                    }
                ),
                showTime: settings.smokingCheckInEnabled
            )

            reminderRow(
                title: "Drinking check-in",
                explanation: settings.drinkingMode.showsSection
                    ? "Soft nudge to log drinks / urges. Off by default. Only fires while Drinking mode is on."
                    : "Turn on Drinking in Settings (mode ≠ Off) to enable this reminder.",
                enabled: Binding(
                    get: { settings.drinkingCheckInEnabled },
                    set: {
                        settings.drinkingCheckInEnabled = $0
                        persist()
                    }
                ),
                time: Binding(
                    get: { date(hour: settings.drinkingCheckInHour, minute: settings.drinkingCheckInMinute) },
                    set: { d in
                        let c = Calendar.current.dateComponents([.hour, .minute], from: d)
                        settings.drinkingCheckInHour = c.hour ?? 17
                        settings.drinkingCheckInMinute = c.minute ?? 0
                        persist()
                    }
                ),
                showTime: settings.drinkingCheckInEnabled
            )

            reminderRow(
                title: "Daily motivation",
                explanation: "A short quote each day. Manage the quote list under Settings → Motivational quotes. Off by default.",
                enabled: Binding(
                    get: { settings.motivationReminderEnabled },
                    set: {
                        settings.motivationReminderEnabled = $0
                        persist()
                    }
                ),
                time: Binding(
                    get: { date(hour: settings.motivationReminderHour, minute: settings.motivationReminderMinute) },
                    set: { d in
                        let c = Calendar.current.dateComponents([.hour, .minute], from: d)
                        settings.motivationReminderHour = c.hour ?? 8
                        settings.motivationReminderMinute = c.minute ?? 0
                        persist()
                    }
                ),
                showTime: settings.motivationReminderEnabled
            )

            Section {
                Toggle("Body composition", isOn: Binding(
                    get: { settings.bodyCompReminderEnabled },
                    set: {
                        settings.bodyCompReminderEnabled = $0
                        persist()
                    }
                ))
                Text("Reminder to log a clinic receipt. Off by default. Opens Body composition when tapped.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                if settings.bodyCompReminderEnabled {
                    Picker("Cadence", selection: Binding(
                        get: { settings.bodyCompReminderCadence },
                        set: {
                            settings.bodyCompReminderCadence = $0
                            persist()
                        }
                    )) {
                        ForEach(BodyCompReminderCadence.allCases) { cadence in
                            Text(cadence.rawValue).tag(cadence)
                        }
                    }
                    .pickerStyle(.segmented)

                    DatePicker(
                        "Time",
                        selection: Binding(
                            get: { date(hour: settings.bodyCompReminderHour, minute: settings.bodyCompReminderMinute) },
                            set: { d in
                                let c = Calendar.current.dateComponents([.hour, .minute], from: d)
                                settings.bodyCompReminderHour = c.hour ?? 9
                                settings.bodyCompReminderMinute = c.minute ?? 0
                                persist()
                            }
                        ),
                        displayedComponents: .hourAndMinute
                    )

                    if settings.bodyCompReminderCadence == .weekly {
                        Picker("Weekday", selection: Binding(
                            get: { settings.bodyCompReminderWeekday },
                            set: {
                                settings.bodyCompReminderWeekday = $0
                                persist()
                            }
                        )) {
                            ForEach(1...7, id: \.self) { weekday in
                                Text(weekdayName(weekday)).tag(weekday)
                            }
                        }
                    } else {
                        Text("Day of month")
                            .font(.subheadline.weight(.semibold))
                        Text("Short months use the last day when your preferred day doesn’t exist (e.g. 31 → Feb 28/29).")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        DayOfMonthPicker(selectedDay: Binding(
                            get: { settings.bodyCompReminderDayOfMonth },
                            set: {
                                settings.bodyCompReminderDayOfMonth = $0
                                persist()
                            }
                        ))
                    }
                }
            }

            Section {
                let active = settings.supplements.filter { $0.isEnabled && $0.reminderEnabled }
                if active.isEmpty {
                    Text("No supplement dose reminders are on.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(active) { supplement in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(supplement.name)
                                .font(.subheadline.weight(.semibold))
                            Text(supplement.reminderTimes.prefix(supplement.dosesPerDay).map { timeLabel($0) }.joined(separator: " · "))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                NavigationLink("Manage in Supplements") {
                    SupplementsSettingsForm(settings: settings)
                }
            } header: {
                Text("Supplement doses")
            } footer: {
                Text("Each enabled dose gets its own daily notification. Press and hold to Mark taken without opening the app. Configure times under Settings → Supplements or the gear on the Supplements card.")
            }
        }
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            authStatus = await NotificationService.shared.authorizationStatus()
            _ = await NotificationService.shared.requestPermission()
            authStatus = await NotificationService.shared.authorizationStatus()
        }
    }

    @ViewBuilder
    private func reminderRow(
        title: String,
        explanation: String,
        enabled: Binding<Bool>,
        time: Binding<Date>,
        showTime: Bool
    ) -> some View {
        Section {
            Toggle(title, isOn: enabled)
            Text(explanation)
                .font(.footnote)
                .foregroundStyle(.secondary)
            if showTime {
                DatePicker("Time", selection: time, displayedComponents: .hourAndMinute)
            }
        }
    }

    private func date(hour: Int, minute: Int) -> Date {
        Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: Date()) ?? Date()
    }

    private func timeLabel(_ time: SupplementReminderTime) -> String {
        let date = date(hour: time.hour, minute: time.minute)
        return date.formatted(date: .omitted, time: .shortened)
    }

    private func weekdayName(_ weekday: Int) -> String {
        let symbols = Calendar.current.weekdaySymbols
        let index = weekday - 1
        guard symbols.indices.contains(index) else { return "Day \(weekday)" }
        return symbols[index]
    }

    private func persist() {
        try? modelContext.save()
        Task { await NotificationService.shared.reschedule(using: settings) }
    }
}

/// Month-grid picker for day-of-month (1–31), not a specific calendar date.
struct DayOfMonthPicker: View {
    @Binding var selectedDay: Int

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)

    /// Fixed 31-day template month so every day number is always available.
    private var templateMonth: Date {
        Calendar.current.date(from: DateComponents(year: 2024, month: 1, day: 1)) ?? Date()
    }

    private var cells: [Int?] {
        let calendar = Calendar.current
        guard let interval = calendar.dateInterval(of: .month, for: templateMonth) else { return [] }
        let firstWeekday = calendar.component(.weekday, from: interval.start)
        let leading = (firstWeekday - calendar.firstWeekday + 7) % 7
        var result: [Int?] = Array(repeating: nil, count: leading)
        for day in 1...31 {
            result.append(day)
        }
        while result.count % 7 != 0 {
            result.append(nil)
        }
        return result
    }

    private var weekdaySymbols: [String] {
        let symbols = Calendar.current.veryShortWeekdaySymbols
        let first = Calendar.current.firstWeekday - 1
        return Array(symbols[first...]) + Array(symbols[..<first])
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(weekdaySymbols, id: \.self) { symbol in
                    Text(symbol)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(Array(cells.enumerated()), id: \.offset) { _, day in
                    if let day {
                        Button {
                            selectedDay = day
                        } label: {
                            Text("\(day)")
                                .font(.caption.weight(.semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(selectedDay == day ? Color.accentColor.opacity(0.2) : Color(.tertiarySystemFill))
                                .foregroundStyle(selectedDay == day ? Color.accentColor : .primary)
                                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    } else {
                        Color.clear
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                    }
                }
            }
            Text("Selected: day \(selectedDay)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
