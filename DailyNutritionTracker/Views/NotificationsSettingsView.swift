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

    private func persist() {
        try? modelContext.save()
        Task { await NotificationService.shared.reschedule(using: settings) }
    }
}
