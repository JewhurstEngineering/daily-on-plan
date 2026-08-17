import SwiftUI
import SwiftData

struct DrinkingSection: View {
    @Bindable var log: DailyLog
    @Bindable var settings: AppSettings
    let recentLogs: [DailyLog]
    var onOpenSettings: (() -> Void)? = nil

    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var healthKit: HealthKitService
    @State private var showUrgeSheet = false
    @State private var urgeNote = ""
    @State private var showEventList = false
    @State private var editDrinkID: UUID?
    @State private var editUrgeID: UUID?

    private var limit: Int? { settings.effectiveDailyDrinkLimit }

    private var underLimit: Bool {
        guard let limit else { return true }
        return log.drinksLogged <= limit
    }

    private var alcoholFreeStreak: Int {
        HabitStreakMath.trailingZeroDays(
            from: log.date,
            logs: recentLogs,
            since: settings.alcoholQuitDate,
            count: { $0.drinksLogged }
        )
    }

    private var reduceStreak: Int {
        guard let limit else { return 0 }
        return HabitStreakMath.trailingUnderLimitDays(
            from: log.date,
            logs: recentLogs,
            limit: limit,
            count: { $0.drinksLogged }
        )
    }

    private var overLimit: Bool { !underLimit }

    var body: some View {
        SectionCard(
            title: "Drinking",
            systemImage: "wineglass",
            isCollapsed: settings.sectionCollapsedBinding(.drinking, context: modelContext),
            collapsedMessage: DaySectionID.drinking.collapsedMessage,
            emphasis: overLimit ? .caution : .none
        ) {
            Text(modeBlurb)
                .font(.footnote)
                .foregroundStyle(.secondary)

            HStack(alignment: .center, spacing: 16) {
                HabitTapButton(
                    caption: "Pour to add",
                    isCaution: overLimit,
                    accessibilityLabel: "Log one drink"
                ) {
                    log.addDrinks(1)
                    persistDrinks()
                } icon: {
                    Image(systemName: "wineglass.fill")
                        .font(.system(size: 30, weight: .semibold))
                        .symbolRenderingMode(.hierarchical)
                }
                Button {
                    log.removeLastDrinkEvent()
                    persistDrinks()
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.title)
                        .foregroundStyle(.secondary)
                }
                .disabled(log.drinkEvents.isEmpty)
                .accessibilityLabel("Undo last drink")
                .buttonStyle(.plain)

                Spacer(minLength: 8)

                VStack(alignment: .trailing, spacing: 4) {
                    Text("Today")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(log.drinksLogged)")
                        .font(.largeTitle.bold().monospacedDigit())
                        .foregroundStyle(countColor)
                    if let limit {
                        Text(limit == 0 ? "Target: 0" : "\(log.drinksLogged) / \(limit) drinks")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.trailing)
                    } else {
                        Text(log.drinksLogged == 1 ? "1 drink" : "\(log.drinksLogged) drinks")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Text("Quick add")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            HStack(spacing: 8) {
                ForEach([2, 3, 4], id: \.self) { count in
                    Button {
                        log.addDrinks(count)
                        persistDrinks()
                    } label: {
                        Text("+\(count)")
                            .font(.caption.weight(.semibold))
                            .chipStyle(fullWidth: true)
                    }
                    .buttonStyle(.plain)
                }
            }

            HabitEventLogDisclosure(
                rows: log.drinkEvents.reversed().map { HabitEventRow(id: $0.id, time: $0.timeLogged, label: $0.label) },
                isExpanded: $showEventList,
                onEdit: { editDrinkID = $0 },
                onDelete: { id in
                    log.removeDrinkEvent(id: id)
                    persistDrinks()
                }
            )

            if settings.drinkingMode == .reduce {
                reduceBudgetBlock
            }

            if settings.drinkingMode == .quit {
                VStack(alignment: .leading, spacing: 6) {
                    if let quit = settings.alcoholQuitDate {
                        Text("Quit date \(DateHelpers.formattedDay(quit))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Text(alcoholFreeStreak == 1
                         ? "1 alcohol-free day in a row"
                         : "\(alcoholFreeStreak) alcohol-free days in a row")
                        .font(.subheadline.weight(.semibold))

                    Button {
                        urgeNote = ""
                        showUrgeSheet = true
                    } label: {
                        Label("Log urge", systemImage: "waveform.path.ecg")
                    }
                    .buttonStyle(.bordered)

                    if !log.drinkUrges.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Urges today")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                            ForEach(log.drinkUrges) { urge in
                                HabitLogRow(
                                    time: urge.timeLogged,
                                    label: urge.note.isEmpty ? "Urge logged" : urge.note,
                                    labelIsSecondary: true,
                                    lineLimit: 2,
                                    onEditTime: { editUrgeID = urge.id },
                                    onDelete: {
                                        log.removeDrinkUrge(id: urge.id)
                                        try? modelContext.save()
                                    }
                                )
                            }
                        }
                    }
                }
            }

            if onOpenSettings != nil {
                Button("Drinking settings…") {
                    onOpenSettings?()
                }
                .font(.caption)
            }
        }
        .sheet(isPresented: $showUrgeSheet) {
            NavigationStack {
                Form {
                    Section {
                        TextField("Optional note", text: $urgeNote, axis: .vertical)
                            .lineLimit(2...4)
                    } footer: {
                        Text("Log the urge even if you didn’t drink.")
                    }
                }
                .navigationTitle("Log urge")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { showUrgeSheet = false }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            log.addDrinkUrge(note: urgeNote.trimmingCharacters(in: .whitespacesAndNewlines))
                            try? modelContext.save()
                            showUrgeSheet = false
                        }
                    }
                }
            }
            .presentationDetents([.medium])
        }
        .sheet(item: drinkEditBinding) { event in
            EditTimestampSheet(
                title: event.label,
                initialDate: event.timeLogged,
                includesDate: true
            ) { newDate in
                moveDrinkEvent(id: event.id, to: newDate)
                editDrinkID = nil
            }
        }
        .sheet(item: urgeEditBinding) { urge in
            EditTimestampSheet(
                title: urge.note.isEmpty ? "Urge" : urge.note,
                initialDate: urge.timeLogged,
                includesDate: true
            ) { newDate in
                moveDrinkUrge(id: urge.id, to: newDate)
                editUrgeID = nil
            }
        }
    }

    private var drinkEditBinding: Binding<DrinkEventRecord?> {
        Binding(
            get: {
                guard let id = editDrinkID else { return nil }
                return log.drinkEvents.first { $0.id == id }
            },
            set: { if $0 == nil { editDrinkID = nil } }
        )
    }

    private var urgeEditBinding: Binding<DrinkUrgeRecord?> {
        Binding(
            get: {
                guard let id = editUrgeID else { return nil }
                return log.drinkUrges.first { $0.id == id }
            },
            set: { if $0 == nil { editUrgeID = nil } }
        )
    }

    private func moveDrinkEvent(id: UUID, to newDate: Date) {
        let targetDay = DateHelpers.startOfDay(newDate)
        let sourceDay = DateHelpers.startOfDay(log.date)
        if targetDay == sourceDay {
            log.updateDrinkEventTime(id: id, timeLogged: newDate)
        } else if var event = log.takeDrinkEvent(id: id) {
            event.timeLogged = newDate
            let targetLog = DataStore.log(for: targetDay, in: modelContext, defaultGoal: settings.defaultProteinGoal)
            targetLog.insertDrinkEvent(event)
        }
        persistDrinks()
    }

    private func moveDrinkUrge(id: UUID, to newDate: Date) {
        let targetDay = DateHelpers.startOfDay(newDate)
        let sourceDay = DateHelpers.startOfDay(log.date)
        if targetDay == sourceDay {
            log.updateDrinkUrgeTime(id: id, timeLogged: newDate)
        } else if var urge = log.takeDrinkUrge(id: id) {
            urge.timeLogged = newDate
            let targetLog = DataStore.log(for: targetDay, in: modelContext, defaultGoal: settings.defaultProteinGoal)
            targetLog.insertDrinkUrge(urge)
        }
        try? modelContext.save()
    }

    private func persistDrinks() {
        try? modelContext.save()
        Task {
            await healthKit.writeAlcoholicDrinks(count: log.drinksLogged, on: log.date)
        }
    }

    @ViewBuilder
    private var reduceBudgetBlock: some View {
        let streakText = reduceStreak == 1
            ? "1 day at or under max"
            : "\(reduceStreak) days at or under max"
        if let limit, limit > 0 {
            let remaining = max(0, limit - log.drinksLogged)
            let reference = HabitStreakMath.paceReferenceDate(for: log.date)
            HabitBudgetBlock(
                remaining: remaining,
                limit: limit,
                remainingFraction: min(1, Double(remaining) / Double(limit)),
                overLimit: overLimit,
                lastHourCount: HabitStreakMath.countInLastHour(
                    times: log.drinkEvents.map(\.timeLogged),
                    counts: log.drinkEvents.map(\.count),
                    referenceDate: reference
                ),
                dayAveragePerHour: HabitStreakMath.dayAveragePerHour(
                    totalCount: log.drinksLogged,
                    firstEventTime: log.drinkEvents.first?.timeLogged,
                    referenceDate: reference
                ),
                streakText: streakText
            )
        } else {
            Text(streakText)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var modeBlurb: String {
        switch settings.drinkingMode {
        case .off: return ""
        case .count: return "Tap the glass to pour one — each drink gets a timestamp."
        case .reduce: return "Stay at or under your daily drink max. Tap the glass to log."
        case .quit: return "Target is zero. Tap for slips and log urges when cravings hit."
        }
    }

    private var countColor: Color {
        underLimit ? .primary : .orange
    }
}
