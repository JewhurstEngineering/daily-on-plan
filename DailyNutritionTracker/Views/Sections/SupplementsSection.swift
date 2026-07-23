import SwiftUI
import SwiftData

struct SupplementsSection: View {
    @Bindable var log: DailyLog
    @Bindable var settings: AppSettings
    @Environment(\.modelContext) private var modelContext
    @State private var showConfig = false

    var body: some View {
        SectionCard(
            title: "Supplements",
            systemImage: "pills",
            isCollapsed: settings.sectionCollapsedBinding(.supplements, context: modelContext),
            collapsedMessage: DaySectionID.supplements.collapsedMessage,
            trailing: {
                Button {
                    showConfig = true
                } label: {
                    Image(systemName: "gearshape.fill")
                }
                .accessibilityLabel("Configure supplements")
            }
        ) {
            let visible = settings.visibleSupplements
            if visible.isEmpty {
                Text("No supplements visible. Tap the gear to enable some, or turn the section off in Settings.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(visible) { supplement in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 6) {
                            Text(supplement.name)
                                .font(.subheadline.weight(.semibold))
                            if supplement.reminderEnabled {
                                Image(systemName: "bell.fill")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        HStack(spacing: 8) {
                            ForEach(0..<supplement.dosesPerDay, id: \.self) { index in
                                let key = supplement.doseKey(index)
                                Button {
                                    toggle(key)
                                } label: {
                                    Image(systemName: log.completedSupplements.contains(key) ? "checkmark.square.fill" : "square")
                                        .font(.title3)
                                        .foregroundStyle(Color.accentColor)
                                }
                                .buttonStyle(.plain)
                            }
                            Spacer()
                            Text("\(completedCount(supplement))/\(supplement.dosesPerDay)")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                    Divider()
                }
            }
            Text("Consult your healthcare provider for individualized supplement schedules.")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .sheet(isPresented: $showConfig) {
            SupplementConfigSheet(settings: settings)
        }
    }

    private func completedCount(_ supplement: SupplementDefinition) -> Int {
        (0..<supplement.dosesPerDay).filter { log.completedSupplements.contains(supplement.doseKey($0)) }.count
    }

    private func toggle(_ key: String) {
        if log.completedSupplements.contains(key) {
            log.completedSupplements.removeAll { $0 == key }
        } else {
            log.completedSupplements.append(key)
        }
        try? modelContext.save()
    }
}

struct SupplementConfigSheet: View {
    @Bindable var settings: AppSettings
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Show or hide items, set doses, and optionally schedule a reminder for each dose. Press and hold a notification to Mark taken.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Button("Disable all") {
                        var list = settings.supplements
                        for i in list.indices { list[i].isEnabled = false }
                        settings.supplements = list
                        persist()
                    }
                    Button("Enable all") {
                        var list = settings.supplements
                        for i in list.indices { list[i].isEnabled = true }
                        settings.supplements = list
                        persist()
                    }
                }

                ForEach(Array(settings.supplements.enumerated()), id: \.element.id) { index, supplement in
                    Section {
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(supplement.name)
                                    .font(.body.weight(.semibold))
                                Text(settings.supplements[index].isEnabled
                                     ? "\(settings.supplements[index].dosesPerDay) doses/day"
                                     : "Hidden")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer(minLength: 8)
                            if settings.supplements[index].isEnabled {
                                Stepper(
                                    "",
                                    value: Binding(
                                        get: { settings.supplements[index].dosesPerDay },
                                        set: { newValue in
                                            updateSupplement(at: index) { item in
                                                item.dosesPerDay = newValue
                                                item.syncReminderTimes()
                                            }
                                        }
                                    ),
                                    in: 1...6
                                )
                                .labelsHidden()
                                .fixedSize()
                            }
                            Toggle(
                                "",
                                isOn: Binding(
                                    get: { settings.supplements[index].isEnabled },
                                    set: { newValue in
                                        updateSupplement(at: index) { $0.isEnabled = newValue }
                                    }
                                )
                            )
                            .labelsHidden()
                            .toggleStyle(.switch)
                            .scaleEffect(0.85)
                            .fixedSize()
                        }

                        if settings.supplements[index].isEnabled {
                            Toggle(
                                "Reminders",
                                isOn: Binding(
                                    get: { settings.supplements[index].reminderEnabled },
                                    set: { newValue in
                                        updateSupplement(at: index) { $0.reminderEnabled = newValue }
                                    }
                                )
                            )

                            if settings.supplements[index].reminderEnabled {
                                ForEach(0..<settings.supplements[index].dosesPerDay, id: \.self) { doseIndex in
                                    DatePicker(
                                        "Dose \(doseIndex + 1)",
                                        selection: Binding(
                                            get: {
                                                reminderDate(
                                                    for: settings.supplements[index].reminderTimes[doseIndex]
                                                )
                                            },
                                            set: { date in
                                                let comps = Calendar.current.dateComponents([.hour, .minute], from: date)
                                                updateSupplement(at: index) { item in
                                                    item.syncReminderTimes()
                                                    guard item.reminderTimes.indices.contains(doseIndex) else { return }
                                                    item.reminderTimes[doseIndex] = SupplementReminderTime(
                                                        hour: comps.hour ?? 8,
                                                        minute: comps.minute ?? 0
                                                    )
                                                }
                                            }
                                        ),
                                        displayedComponents: .hourAndMinute
                                    )
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Configure Supplements")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func updateSupplement(at index: Int, mutate: (inout SupplementDefinition) -> Void) {
        var list = settings.supplements
        guard list.indices.contains(index) else { return }
        mutate(&list[index])
        settings.supplements = list
        persist()
    }

    private func reminderDate(for time: SupplementReminderTime) -> Date {
        Calendar.current.date(bySettingHour: time.hour, minute: time.minute, second: 0, of: Date()) ?? Date()
    }

    private func persist() {
        try? modelContext.save()
        Task { await NotificationService.shared.reschedule(using: settings) }
    }
}
