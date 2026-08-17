import SwiftUI
import SwiftData

struct SmokingSection: View {
    @Bindable var log: DailyLog
    @Bindable var settings: AppSettings
    let recentLogs: [DailyLog]
    var onOpenSettings: (() -> Void)? = nil

    @Environment(\.modelContext) private var modelContext
    @State private var showUrgeSheet = false
    @State private var urgeNote = ""
    @State private var showEventList = false
    @State private var editCigaretteID: UUID?
    @State private var editUrgeID: UUID?

    private var limit: Int? { settings.effectiveDailyCigaretteLimit }

    private var underLimit: Bool {
        guard let limit else { return true }
        return log.cigarettesSmoked <= limit
    }

    private var smokeFreeStreak: Int {
        HabitStreakMath.trailingZeroDays(
            from: log.date,
            logs: recentLogs,
            since: settings.quitDate,
            count: { $0.cigarettesSmoked }
        )
    }

    private var reduceStreak: Int {
        guard let limit else { return 0 }
        return HabitStreakMath.trailingUnderLimitDays(
            from: log.date,
            logs: recentLogs,
            limit: limit,
            count: { $0.cigarettesSmoked }
        )
    }

    private var moneySavedText: String? {
        guard settings.smokingMode == .quit,
              let quit = settings.quitDate,
              settings.cigarettePackPrice != nil else { return nil }
        let avoided = Self.cigarettesAvoidedSinceQuit(
            quitDate: quit,
            through: log.date,
            logs: recentLogs,
            baselinePerDay: max(settings.dailyCigaretteLimit, CigarettePackMath.perPack)
        )
        guard let saved = settings.estimatedMoneySaved(cigarettesAvoided: avoided), saved > 0 else { return nil }
        return String(format: "Est. $%.2f saved", saved)
    }

    private var overLimit: Bool { !underLimit }

    var body: some View {
        SectionCard(
            title: "Smoking",
            systemImage: "smoke",
            isCollapsed: settings.sectionCollapsedBinding(.smoking, context: modelContext),
            collapsedMessage: DaySectionID.smoking.collapsedMessage,
            emphasis: overLimit ? .caution : .none
        ) {
            Text(modeBlurb)
                .font(.footnote)
                .foregroundStyle(.secondary)

            HStack(alignment: .center, spacing: 16) {
                HabitTapButton(
                    caption: "Ash to add",
                    isCaution: overLimit,
                    accessibilityLabel: "Log one cigarette"
                ) {
                    log.addCigarette()
                    try? modelContext.save()
                } icon: {
                    CigaretteGlyph()
                }
                Button {
                    log.removeLastCigaretteEvent()
                    try? modelContext.save()
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.title)
                        .foregroundStyle(.secondary)
                }
                .disabled(log.cigaretteEvents.isEmpty)
                .accessibilityLabel("Undo last smoke log")
                .buttonStyle(.plain)

                Spacer(minLength: 8)

                VStack(alignment: .trailing, spacing: 4) {
                    Text("Today")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(log.cigarettesSmoked)")
                        .font(.largeTitle.bold().monospacedDigit())
                        .foregroundStyle(countColor)
                    Text(CigarettePackMath.packsLabel(cigarettes: log.cigarettesSmoked))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if let limit {
                        Text(
                            limit == 0
                            ? "Target: 0"
                            : "\(log.cigarettesSmoked) / \(limit) cigs · max \(CigarettePackMath.packsLabel(cigarettes: limit))"
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.trailing)
                    }
                }
            }

            Text("Quick add packs")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            HStack(spacing: 8) {
                ForEach(CigarettePackMath.quickPackOptions, id: \.self) { packs in
                    Button {
                        log.addCigarettes(CigarettePackMath.cigarettes(forPacks: packs))
                        try? modelContext.save()
                    } label: {
                        Text(packChipLabel(packs))
                            .font(.caption.weight(.semibold))
                            .chipStyle(fullWidth: true)
                    }
                    .buttonStyle(.plain)
                }
            }

            HabitEventLogDisclosure(
                rows: log.cigaretteEvents.reversed().map { HabitEventRow(id: $0.id, time: $0.timeLogged, label: $0.label) },
                isExpanded: $showEventList,
                onEdit: { editCigaretteID = $0 },
                onDelete: { id in
                    log.removeCigaretteEvent(id: id)
                    try? modelContext.save()
                }
            )

            if settings.smokingMode == .reduce {
                reduceBudgetBlock
            }

            if settings.smokingMode == .quit {
                VStack(alignment: .leading, spacing: 6) {
                    if let quit = settings.quitDate {
                        Text("Quit date \(DateHelpers.formattedDay(quit))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Text(smokeFreeStreak == 1
                         ? "1 smoke-free day in a row"
                         : "\(smokeFreeStreak) smoke-free days in a row")
                        .font(.subheadline.weight(.semibold))
                    if let moneySavedText {
                        Text(moneySavedText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Button {
                        urgeNote = ""
                        showUrgeSheet = true
                    } label: {
                        Label("Log urge", systemImage: "waveform.path.ecg")
                    }
                    .buttonStyle(.bordered)

                    if !log.cigaretteUrges.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Urges today")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                            ForEach(log.cigaretteUrges) { urge in
                                HabitLogRow(
                                    time: urge.timeLogged,
                                    label: urge.note.isEmpty ? "Urge logged" : urge.note,
                                    labelIsSecondary: true,
                                    lineLimit: 2,
                                    onEditTime: { editUrgeID = urge.id },
                                    onDelete: {
                                        log.removeUrge(id: urge.id)
                                        try? modelContext.save()
                                    }
                                )
                            }
                        }
                    }
                }
            }

            if onOpenSettings != nil {
                Button("Smoking settings…") {
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
                        Text("Log the urge even if you didn’t smoke.")
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
                            log.addUrge(note: urgeNote.trimmingCharacters(in: .whitespacesAndNewlines))
                            try? modelContext.save()
                            showUrgeSheet = false
                        }
                    }
                }
            }
            .presentationDetents([.medium])
        }
        .sheet(item: cigaretteEditBinding) { event in
            EditTimestampSheet(
                title: event.label,
                initialDate: event.timeLogged,
                includesDate: true
            ) { newDate in
                moveCigaretteEvent(id: event.id, to: newDate)
                editCigaretteID = nil
            }
        }
        .sheet(item: urgeEditBinding) { urge in
            EditTimestampSheet(
                title: urge.note.isEmpty ? "Urge" : urge.note,
                initialDate: urge.timeLogged,
                includesDate: true
            ) { newDate in
                moveCigaretteUrge(id: urge.id, to: newDate)
                editUrgeID = nil
            }
        }
    }

    private var cigaretteEditBinding: Binding<CigaretteEventRecord?> {
        Binding(
            get: {
                guard let id = editCigaretteID else { return nil }
                return log.cigaretteEvents.first { $0.id == id }
            },
            set: { if $0 == nil { editCigaretteID = nil } }
        )
    }

    private var urgeEditBinding: Binding<CigaretteUrgeRecord?> {
        Binding(
            get: {
                guard let id = editUrgeID else { return nil }
                return log.cigaretteUrges.first { $0.id == id }
            },
            set: { if $0 == nil { editUrgeID = nil } }
        )
    }

    private func moveCigaretteEvent(id: UUID, to newDate: Date) {
        let targetDay = DateHelpers.startOfDay(newDate)
        let sourceDay = DateHelpers.startOfDay(log.date)
        if targetDay == sourceDay {
            log.updateCigaretteEventTime(id: id, timeLogged: newDate)
        } else if var event = log.takeCigaretteEvent(id: id) {
            event.timeLogged = newDate
            let targetLog = DataStore.log(for: targetDay, in: modelContext, defaultGoal: settings.defaultProteinGoal)
            targetLog.insertCigaretteEvent(event)
        }
        try? modelContext.save()
    }

    private func moveCigaretteUrge(id: UUID, to newDate: Date) {
        let targetDay = DateHelpers.startOfDay(newDate)
        let sourceDay = DateHelpers.startOfDay(log.date)
        if targetDay == sourceDay {
            log.updateCigaretteUrgeTime(id: id, timeLogged: newDate)
        } else if var urge = log.takeCigaretteUrge(id: id) {
            urge.timeLogged = newDate
            let targetLog = DataStore.log(for: targetDay, in: modelContext, defaultGoal: settings.defaultProteinGoal)
            targetLog.insertCigaretteUrge(urge)
        }
        try? modelContext.save()
    }

    private func packChipLabel(_ packs: Double) -> String {
        if packs == 0.5 { return "½" }
        if abs(packs - 1.5) < 0.01 { return "1½" }
        if abs(packs - packs.rounded()) < 0.01 { return "\(Int(packs.rounded()))" }
        return String(format: "%.1f", packs)
    }

    @ViewBuilder
    private var reduceBudgetBlock: some View {
        let streakText = reduceStreak == 1
            ? "1 day at or under max"
            : "\(reduceStreak) days at or under max"
        if let limit, limit > 0 {
            let remaining = max(0, limit - log.cigarettesSmoked)
            let reference = HabitStreakMath.paceReferenceDate(for: log.date)
            HabitBudgetBlock(
                remaining: remaining,
                limit: limit,
                remainingFraction: min(1, Double(remaining) / Double(limit)),
                overLimit: overLimit,
                lastHourCount: HabitStreakMath.countInLastHour(
                    times: log.cigaretteEvents.map(\.timeLogged),
                    counts: log.cigaretteEvents.map(\.count),
                    referenceDate: reference
                ),
                dayAveragePerHour: HabitStreakMath.dayAveragePerHour(
                    totalCount: log.cigarettesSmoked,
                    firstEventTime: log.cigaretteEvents.first?.timeLogged,
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
        switch settings.smokingMode {
        case .off:
            return ""
        case .count:
            return "Tap the cigarette to ash one — each log gets a timestamp. Or add a pack below."
        case .reduce:
            return "Stay at or under your daily max. Tap the cig or add a pack."
        case .quit:
            return "Target is zero. Tap the cig for slips (timestamped) and log urges when cravings hit."
        }
    }

    private var countColor: Color {
        underLimit ? .primary : .orange
    }

    static func cigarettesAvoidedSinceQuit(
        quitDate: Date,
        through: Date,
        logs: [DailyLog],
        baselinePerDay: Int
    ) -> Int {
        let start = DateHelpers.startOfDay(quitDate)
        let end = DateHelpers.startOfDay(through)
        guard end >= start else { return 0 }
        let byDay = Dictionary(uniqueKeysWithValues: logs.map { (DateHelpers.startOfDay($0.date), $0) })
        var avoided = 0
        var cursor = start
        while cursor <= end {
            let smoked = byDay[cursor]?.cigarettesSmoked ?? 0
            avoided += max(0, baselinePerDay - smoked)
            guard let next = Calendar.current.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }
        return avoided
    }
}
