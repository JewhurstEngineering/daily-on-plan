import SwiftUI

/// Shared pure-function math for Smoking/Drinking — the two sections track different fields on
/// `DailyLog` (cigarettes vs drinks) but ran byte-identical streak/pace algorithms independently.
/// See docs/DESIGN_IMPROVEMENT_PLAN.md §5.3 — one algorithm, not two that can drift.
enum HabitStreakMath {
    /// Trailing consecutive days at or under `limit`, counting backward from `day`.
    static func trailingUnderLimitDays(from day: Date, logs: [DailyLog], limit: Int, count: (DailyLog) -> Int) -> Int {
        let byDay = Dictionary(uniqueKeysWithValues: logs.map { (DateHelpers.startOfDay($0.date), $0) })
        var cursor = DateHelpers.startOfDay(day)
        var streak = 0
        while let entry = byDay[cursor] {
            if count(entry) > limit { break }
            streak += 1
            guard let previous = Calendar.current.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }
        if streak == 0, (byDay[DateHelpers.startOfDay(day)].map(count) ?? 0) <= limit {
            return 1
        }
        return streak
    }

    /// Trailing consecutive zero-count days, honoring an optional "since quit" lower bound.
    static func trailingZeroDays(from day: Date, logs: [DailyLog], since startBound: Date?, count: (DailyLog) -> Int) -> Int {
        let bound = startBound.map { DateHelpers.startOfDay($0) }
        let byDay = Dictionary(uniqueKeysWithValues: logs.map { (DateHelpers.startOfDay($0.date), $0) })
        var cursor = DateHelpers.startOfDay(day)
        var streak = 0
        while true {
            if let bound, cursor < bound { break }
            if (byDay[cursor].map(count) ?? 0) > 0 { break }
            streak += 1
            guard let previous = Calendar.current.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
            if bound == nil, byDay[cursor] == nil, streak > 0 {
                let hasAnyEarlier = byDay.keys.contains { $0 < cursor }
                if !hasAnyEarlier { break }
            }
        }
        return streak
    }

    /// "Now" for a past day's pace math falls back to the end of that day rather than the live clock.
    static func paceReferenceDate(for day: Date) -> Date {
        if Calendar.current.isDateInToday(day) { return Date() }
        return Calendar.current.date(byAdding: .day, value: 1, to: DateHelpers.startOfDay(day)) ?? day
    }

    static func countInLastHour(times: [Date], counts: [Int], referenceDate: Date) -> Int {
        let cutoff = referenceDate.addingTimeInterval(-3600)
        return zip(times, counts)
            .filter { $0.0 >= cutoff && $0.0 <= referenceDate }
            .reduce(0) { $0 + $1.1 }
    }

    static func dayAveragePerHour(totalCount: Int, firstEventTime: Date?, referenceDate: Date) -> Double? {
        guard totalCount > 0, let firstEventTime else { return nil }
        let hours = max(referenceDate.timeIntervalSince(firstEventTime) / 3600.0, 1.0 / 60.0)
        return Double(totalCount) / hours
    }

    static func rateLabel(_ count: Int) -> String {
        count == 1 ? "1 / hr" : "\(count) / hr"
    }
}

/// One timestamped log row — Smoking's cigarette/urge events and Drinking's drink/urge events
/// rendered through the same row instead of four hand-rolled `HStack`s.
struct HabitLogRow: View {
    let time: Date
    let label: String
    var labelIsSecondary: Bool = false
    var lineLimit: Int? = nil
    let onEditTime: () -> Void
    let onDelete: () -> Void
    @Environment(\.accentPrimary) private var accentPrimary

    var body: some View {
        HStack {
            Button(DateHelpers.formattedTime(time), action: onEditTime)
                .font(.caption.weight(.semibold).monospacedDigit())
                .foregroundStyle(accentPrimary)
                .buttonStyle(.plain)
            Text(label)
                .font(.caption)
                .foregroundStyle(labelIsSecondary ? .secondary : .primary)
                .lineLimit(lineLimit)
            Spacer()
            Button(role: .destructive, action: onDelete) {
                Image(systemName: "trash")
                    .font(.caption)
            }
            .buttonStyle(.plain)
        }
    }
}

/// A collapsible "Log (N)" list of `HabitLogRow`s — the event history under Smoking/Drinking.
struct HabitEventRow: Identifiable {
    let id: UUID
    let time: Date
    let label: String
}

struct HabitEventLogDisclosure: View {
    let rows: [HabitEventRow]
    @Binding var isExpanded: Bool
    let onEdit: (UUID) -> Void
    let onDelete: (UUID) -> Void

    var body: some View {
        if !rows.isEmpty {
            DisclosureGroup("Log (\(rows.count))", isExpanded: $isExpanded) {
                ForEach(rows) { row in
                    HabitLogRow(
                        time: row.time,
                        label: row.label,
                        onEditTime: { onEdit(row.id) },
                        onDelete: { onDelete(row.id) }
                    )
                }
            }
            .font(.caption)
        }
    }
}

/// The "Budget left" progress bar + last-hour/avg-today stats shown under Smoking/Drinking when
/// in reduce mode with a nonzero limit — identical layout, only the numbers differed.
struct HabitBudgetBlock: View {
    let remaining: Int
    let limit: Int
    let remainingFraction: Double
    let overLimit: Bool
    let lastHourCount: Int
    let dayAveragePerHour: Double?
    let streakText: String

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            HStack {
                Text("Budget left")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(remaining) of \(limit)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(overLimit ? .orange : .secondary)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color(.tertiarySystemFill))
                    Capsule()
                        .fill(overLimit ? Color.orange : Color.accentColor)
                        .frame(width: max(4, geo.size.width * remainingFraction))
                }
            }
            .frame(height: 10)

            HStack(spacing: Spacing.l) {
                HabitRateStat(value: HabitStreakMath.rateLabel(lastHourCount), caption: "Last hour")
                HabitRateStat(
                    value: dayAveragePerHour.map { String(format: "%.1f / hr", $0) } ?? "—",
                    caption: "Avg today"
                )
            }

            Text(streakText)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 4)
    }
}

private struct HabitRateStat: View {
    let value: String
    let caption: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.subheadline.weight(.semibold).monospacedDigit())
            Text(caption)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
