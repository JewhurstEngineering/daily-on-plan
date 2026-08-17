import Foundation

enum FastingPhase: Equatable {
    case off
    /// Fasting is on, but nothing has started yet — don’t invent yesterday’s typical close.
    case idle
    case fasting(elapsed: TimeInterval, target: TimeInterval)
    case eating(elapsed: TimeInterval, remaining: TimeInterval?, started: Date, ended: Date?)

    var isFasting: Bool {
        if case .fasting = self { return true }
        return false
    }

    var isEating: Bool {
        if case .eating = self { return true }
        return false
    }
}

struct FastingDayRecord: Identifiable, Equatable {
    var date: Date
    var duration: TimeInterval
    var hit: Bool

    var id: Date { date }
}

enum FastingMath {
    static func typicalWindow(on day: Date, settings: AppSettings, calendar: Calendar = .current) -> (start: Date, end: Date) {
        let startOfDay = calendar.startOfDay(for: day)
        let start = calendar.date(
            bySettingHour: settings.fastingEatStartHour,
            minute: settings.fastingEatStartMinute,
            second: 0,
            of: startOfDay
        ) ?? startOfDay
        let end = start.addingTimeInterval(settings.fastingEatHours * 3600)
        return (start, end)
    }

    static func applyTypicalWindow(to log: DailyLog, settings: AppSettings, now: Date = Date(), calendar: Calendar = .current) {
        let window = typicalWindow(on: log.date, settings: settings, calendar: calendar)
        if now < window.start {
            log.eatingWindowStart = nil
            log.eatingWindowEnd = nil
        } else if now < window.end {
            log.eatingWindowStart = window.start
            log.eatingWindowEnd = nil
        } else {
            log.eatingWindowStart = window.start
            log.eatingWindowEnd = window.end
        }
    }

    /// Last meal end, if one was actually logged. Never fills in a typical time.
    static func previousWindowEnd(
        previous: DailyLog?,
        settings: AppSettings,
        calendar: Calendar = .current
    ) -> Date? {
        if let end = previous?.eatingWindowEnd { return end }
        if let start = previous?.eatingWindowStart {
            return start.addingTimeInterval(settings.fastingEatHours * 3600)
        }
        return nil
    }

    /// When you tap Start Fast with no prior close, we stamp `today.eatingWindowEnd`
    /// (start stays nil) so the clock begins at now.
    static func startFast(today: DailyLog, now: Date = Date()) {
        guard today.eatingWindowStart == nil else { return }
        today.eatingWindowEnd = now
    }

    static func beginEating(today: DailyLog, previous: DailyLog?, now: Date = Date()) {
        if today.eatingWindowStart == nil, let stamp = today.eatingWindowEnd, let previous {
            if previous.eatingWindowEnd == nil {
                previous.eatingWindowEnd = stamp
            }
        }
        today.eatingWindowStart = now
        today.eatingWindowEnd = nil
    }

    static func fastAnchor(
        today: DailyLog?,
        previous: DailyLog?,
        settings: AppSettings,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> Date? {
        if let today, today.eatingWindowStart == nil, let stamp = today.eatingWindowEnd {
            return stamp
        }
        if let today, let end = today.eatingWindowEnd, today.eatingWindowStart != nil, now >= end {
            return end
        }
        return previousWindowEnd(previous: previous, settings: settings, calendar: calendar)
    }

    static func phase(
        today: DailyLog?,
        previous: DailyLog?,
        settings: AppSettings,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> FastingPhase {
        if !settings.fastingEnabled {
            let hasWindow = today?.eatingWindowStart != nil || today?.eatingWindowEnd != nil
            if !hasWindow { return .off }
        }
        let target = settings.fastingTargetHours * 3600
        if let start = today?.eatingWindowStart, today?.eatingWindowEnd == nil {
            let elapsed = now.timeIntervalSince(start)
            let remaining = max(0, settings.fastingEatHours * 3600 - elapsed)
            return .eating(
                elapsed: max(0, elapsed),
                remaining: remaining,
                started: start,
                ended: nil
            )
        }
        if let start = today?.eatingWindowStart, let end = today?.eatingWindowEnd, now < end {
            return .eating(
                elapsed: max(0, end.timeIntervalSince(start)),
                remaining: nil,
                started: start,
                ended: end
            )
        }
        if let anchor = fastAnchor(today: today, previous: previous, settings: settings, now: now, calendar: calendar) {
            return .fasting(elapsed: max(0, now.timeIntervalSince(anchor)), target: target)
        }
        return .idle
    }

    static func overnightDuration(
        today: DailyLog,
        previous: DailyLog?,
        settings: AppSettings,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> TimeInterval? {
        let close = today.eatingWindowStart ?? now
        if let endAnchor = previousWindowEnd(previous: previous, settings: settings, calendar: calendar) {
            return max(0, close.timeIntervalSince(endAnchor))
        }
        if today.eatingWindowStart == nil, let stamp = today.eatingWindowEnd {
            return max(0, close.timeIntervalSince(stamp))
        }
        return nil
    }

    static func hitTarget(
        today: DailyLog,
        previous: DailyLog?,
        settings: AppSettings,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> Bool {
        guard let duration = overnightDuration(
            today: today,
            previous: previous,
            settings: settings,
            now: now,
            calendar: calendar
        ) else { return false }
        return duration + 60 >= settings.fastingTargetHours * 3600
    }

    static func history(
        logs: [DailyLog],
        settings: AppSettings,
        now: Date = Date(),
        calendar: Calendar = .current,
        limit: Int = 14
    ) -> [FastingDayRecord] {
        let sorted = logs.sorted { $0.date < $1.date }
        var records: [FastingDayRecord] = []
        for (index, log) in sorted.enumerated() {
            let previous = index > 0 ? sorted[index - 1] : nil
            guard log.eatingWindowStart != nil else { continue }
            guard let duration = overnightDuration(
                today: log,
                previous: previous,
                settings: settings,
                now: now,
                calendar: calendar
            ) else { continue }
            records.append(
                FastingDayRecord(
                    date: log.date,
                    duration: duration,
                    hit: duration + 60 >= settings.fastingTargetHours * 3600
                )
            )
        }
        return Array(records.suffix(limit))
    }

    static func streak(
        logs: [DailyLog],
        settings: AppSettings,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> Int {
        let records = history(logs: logs, settings: settings, now: now, calendar: calendar, limit: 60)
        guard !records.isEmpty else { return 0 }
        let sorted = records.sorted { $0.date > $1.date }
        var count = 0
        var cursor = calendar.startOfDay(for: now)
        let yesterday = calendar.date(byAdding: .day, value: -1, to: cursor) ?? cursor
        if let first = sorted.first, !calendar.isDate(first.date, inSameDayAs: cursor) {
            if calendar.isDate(first.date, inSameDayAs: yesterday) {
                cursor = yesterday
            } else {
                return 0
            }
        }
        for record in sorted {
            guard calendar.isDate(record.date, inSameDayAs: cursor) else { break }
            guard record.hit else { break }
            count += 1
            cursor = calendar.date(byAdding: .day, value: -1, to: cursor) ?? cursor
        }
        return count
    }

    static func formatDuration(_ interval: TimeInterval) -> String {
        let total = max(0, Int(interval.rounded()))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }

    static func formatClock(_ interval: TimeInterval, seconds: Bool = true) -> String {
        let total = max(0, Int(interval))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        if seconds {
            return String(format: "%02d:%02d:%02d", hours, minutes, total % 60)
        }
        return String(format: "%02d:%02d", hours, minutes)
    }

    static func snapshotBits(
        today: DailyLog?,
        previous: DailyLog?,
        logs: [DailyLog],
        settings: AppSettings,
        now: Date = Date()
    ) -> (enabled: Bool, start: Date?, end: Date?, hours: Double, streak: Int, line: String) {
        let enabled = settings.fastingEnabled
            || today?.eatingWindowStart != nil
            || today?.eatingWindowEnd != nil
        return (
            enabled,
            today?.eatingWindowStart,
            today?.eatingWindowEnd,
            settings.fastingTargetHours,
            enabled ? streak(logs: logs, settings: settings, now: now) : 0,
            enabled ? statusLine(today: today, previous: previous, settings: settings, now: now) : ""
        )
    }

    static func statusLine(
        today: DailyLog?,
        previous: DailyLog?,
        settings: AppSettings,
        now: Date = Date()
    ) -> String {
        switch phase(today: today, previous: previous, settings: settings, now: now) {
        case .off:
            return "Fasting off"
        case .idle:
            return "Ready — start when you stop eating"
        case .fasting(let elapsed, let target):
            let remaining = max(0, target - elapsed)
            if remaining > 0 {
                return "Fasting \(formatDuration(elapsed)) · \(formatDuration(remaining)) to eat"
            }
            return "Fasting \(formatDuration(elapsed)) · target hit"
        case .eating(let elapsed, let remaining, _, let ended):
            if ended != nil {
                return "Window closed · ate \(formatDuration(elapsed))"
            }
            if let remaining, remaining > 0 {
                return "Eating \(formatDuration(elapsed)) · \(formatDuration(remaining)) left"
            }
            return "Eating \(formatDuration(elapsed)) · past window"
        }
    }
}
