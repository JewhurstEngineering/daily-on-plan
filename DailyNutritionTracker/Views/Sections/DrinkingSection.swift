import SwiftUI
import SwiftData

struct DrinkingSection: View {
    @Bindable var log: DailyLog
    @Bindable var settings: AppSettings
    let recentLogs: [DailyLog]
    var onOpenSettings: (() -> Void)? = nil

    @Environment(\.modelContext) private var modelContext
    @Environment(\.accentPrimary) private var accentPrimary
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
        Self.trailingAlcoholFreeDays(from: log.date, logs: recentLogs, quitDate: settings.alcoholQuitDate)
    }

    private var reduceStreak: Int {
        guard let limit else { return 0 }
        return Self.trailingUnderLimitDays(from: log.date, logs: recentLogs, limit: limit)
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
                VStack(alignment: .leading, spacing: 4) {
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
                    } else {
                        Text(log.drinksLogged == 1 ? "1 drink" : "\(log.drinksLogged) drinks")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 8)
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
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(Color(.tertiarySystemFill))
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }

            if !log.drinkEvents.isEmpty {
                DisclosureGroup("Log (\(log.drinkEvents.count))", isExpanded: $showEventList) {
                    ForEach(log.drinkEvents.reversed()) { event in
                        HStack {
                            Button(DateHelpers.formattedTime(event.timeLogged)) {
                                editDrinkID = event.id
                            }
                            .font(.caption.weight(.semibold).monospacedDigit())
                            .foregroundStyle(accentPrimary)
                            .buttonStyle(.plain)
                            Text(event.label)
                                .font(.caption)
                            Spacer()
                            Button(role: .destructive) {
                                log.removeDrinkEvent(id: event.id)
                                persistDrinks()
                            } label: {
                                Image(systemName: "trash")
                                    .font(.caption)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .font(.caption)
            }

            if settings.drinkingMode == .reduce {
                Text(reduceStreak == 1
                     ? "1 day at or under max"
                     : "\(reduceStreak) days at or under max")
                    .font(.caption)
                    .foregroundStyle(.secondary)
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
                                HStack {
                                    Button(DateHelpers.formattedTime(urge.timeLogged)) {
                                        editUrgeID = urge.id
                                    }
                                    .font(.caption.weight(.semibold).monospacedDigit())
                                    .foregroundStyle(accentPrimary)
                                    .buttonStyle(.plain)
                                    Text(urge.note.isEmpty ? "Urge logged" : urge.note)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                    Spacer()
                                    Button(role: .destructive) {
                                        log.removeDrinkUrge(id: urge.id)
                                        try? modelContext.save()
                                    } label: {
                                        Image(systemName: "trash")
                                            .font(.caption)
                                    }
                                    .buttonStyle(.plain)
                                }
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

    private var modeBlurb: String {
        switch settings.drinkingMode {
        case .off: return ""
        case .count: return "Tap the glass to pour one — each drink gets a timestamp."
        case .reduce: return "Stay at or under your daily drink max. Tap the glass to log."
        case .quit: return "Target is zero. Tap for slips and log urges when cravings hit."
        }
    }

    private var countColor: Color {
        guard let limit else { return .primary }
        return underLimit ? .primary : .orange
    }

    static func trailingAlcoholFreeDays(from day: Date, logs: [DailyLog], quitDate: Date?) -> Int {
        let startBound = quitDate.map { DateHelpers.startOfDay($0) }
        let byDay = Dictionary(uniqueKeysWithValues: logs.map { (DateHelpers.startOfDay($0.date), $0) })
        var cursor = DateHelpers.startOfDay(day)
        var streak = 0
        while true {
            if let startBound, cursor < startBound { break }
            if (byDay[cursor]?.drinksLogged ?? 0) > 0 { break }
            streak += 1
            guard let previous = Calendar.current.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
            if startBound == nil, byDay[cursor] == nil, streak > 0 {
                let hasAnyEarlier = byDay.keys.contains { $0 < cursor }
                if !hasAnyEarlier { break }
            }
        }
        return streak
    }

    static func trailingUnderLimitDays(from day: Date, logs: [DailyLog], limit: Int) -> Int {
        let byDay = Dictionary(uniqueKeysWithValues: logs.map { (DateHelpers.startOfDay($0.date), $0) })
        var cursor = DateHelpers.startOfDay(day)
        var streak = 0
        while let entry = byDay[cursor] {
            if entry.drinksLogged > limit { break }
            streak += 1
            guard let previous = Calendar.current.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }
        if streak == 0, (byDay[DateHelpers.startOfDay(day)]?.drinksLogged ?? 0) <= limit {
            return 1
        }
        return streak
    }
}
