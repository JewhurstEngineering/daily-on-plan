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

    private var limit: Int? { settings.effectiveDailyCigaretteLimit }

    private var underLimit: Bool {
        guard let limit else { return true }
        return log.cigarettesSmoked <= limit
    }

    private var smokeFreeStreak: Int {
        Self.trailingSmokeFreeDays(from: log.date, logs: recentLogs, quitDate: settings.quitDate)
    }

    private var reduceStreak: Int {
        guard let limit else { return 0 }
        return Self.trailingUnderLimitDays(from: log.date, logs: recentLogs, limit: limit)
    }

    private var moneySavedText: String? {
        guard settings.smokingMode == .quit,
              let quit = settings.quitDate,
              let price = settings.cigarettePackPrice else { return nil }
        let avoided = Self.cigarettesAvoidedSinceQuit(
            quitDate: quit,
            through: log.date,
            logs: recentLogs,
            baselinePerDay: max(settings.dailyCigaretteLimit, 1)
        )
        guard let saved = settings.estimatedMoneySaved(cigarettesAvoided: avoided), saved > 0 else { return nil }
        return String(format: "Est. $%.2f saved", saved)
    }

    var body: some View {
        SectionCard(
            title: "Smoking",
            systemImage: "smoke",
            isCollapsed: settings.sectionCollapsedBinding(.smoking, context: modelContext),
            collapsedMessage: DaySectionID.smoking.collapsedMessage
        ) {
            Text(modeBlurb)
                .font(.footnote)
                .foregroundStyle(.secondary)

            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Today")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(log.cigarettesSmoked)")
                        .font(.largeTitle.bold().monospacedDigit())
                        .foregroundStyle(countColor)
                    if let limit {
                        Text(limit == 0 ? "Target: 0" : "\(log.cigarettesSmoked) / \(limit) max")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                HStack(spacing: 12) {
                    Button {
                        log.removeCigarette()
                        try? modelContext.save()
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .font(.title)
                    }
                    .disabled(log.cigarettesSmoked <= 0)
                    .accessibilityLabel("Remove cigarette")

                    Button {
                        log.addCigarette()
                        try? modelContext.save()
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title)
                    }
                    .accessibilityLabel("Add cigarette")
                }
                .buttonStyle(.plain)
            }

            if settings.smokingMode == .reduce {
                Text(reduceStreak == 1
                     ? "1 day at or under max"
                     : "\(reduceStreak) days at or under max")
                    .font(.caption)
                    .foregroundStyle(.secondary)
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
                                HStack {
                                    Text(DateHelpers.formattedTime(urge.timeLogged))
                                        .font(.caption.monospacedDigit())
                                    Text(urge.note.isEmpty ? "Urge logged" : urge.note)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                    Spacer()
                                    Button(role: .destructive) {
                                        log.removeUrge(id: urge.id)
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
    }

    private var modeBlurb: String {
        switch settings.smokingMode {
        case .off:
            return ""
        case .count:
            return "Tap + when you smoke. Neutral count only."
        case .reduce:
            return "Stay at or under your daily max. + / − adjusts today’s count."
        case .quit:
            return "Target is zero. Log slips with + and urges when you want to track cravings."
        }
    }

    private var countColor: Color {
        guard let limit else { return .primary }
        return underLimit ? .primary : .orange
    }

    /// Consecutive days ending at `from` with smoked == 0 (and on/after quit date if set).
    static func trailingSmokeFreeDays(from day: Date, logs: [DailyLog], quitDate: Date?) -> Int {
        let startBound = quitDate.map { DateHelpers.startOfDay($0) }
        let byDay = Dictionary(uniqueKeysWithValues: logs.map { (DateHelpers.startOfDay($0.date), $0) })
        var cursor = DateHelpers.startOfDay(day)
        var streak = 0
        while true {
            if let startBound, cursor < startBound { break }
            let smoked = byDay[cursor]?.cigarettesSmoked ?? 0
            if smoked > 0 { break }
            streak += 1
            guard let previous = Calendar.current.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
            // Don't invent infinite history before any logs / quit date.
            if startBound == nil, byDay[cursor] == nil, streak > 0 {
                // Allow one gap only if we already counted today; stop when we leave logged range without quit date.
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
            if entry.cigarettesSmoked > limit { break }
            streak += 1
            guard let previous = Calendar.current.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }
        // Today with no prior log still counts if under limit.
        if streak == 0, (byDay[DateHelpers.startOfDay(day)]?.cigarettesSmoked ?? 0) <= limit {
            return 1
        }
        return streak
    }

    /// Rough avoided count: baselinePerDay for each calendar day from quit…through minus actual smoked.
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
