import Foundation

enum FastingPhase: Equatable {
    case off
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

    static func previousWindowEnd(
        previous: DailyLog?,
        settings: AppSettings,
        calendar: Calendar = .current
    ) -> Date? {
        if let end = previous?.eatingWindowEnd { return end }
        if let start = previous?.eatingWindowStart {
            return start.addingTimeInterval(settings.fastingEatHours * 3600)
        }
        if let previous {
            return typicalWindow(on: previous.date, settings: settings, calendar: calendar).end
        }
        return nil
    }

    static func phase(
        today: DailyLog?,
        previous: DailyLog?,
        settings: AppSettings,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> FastingPhase {
        guard settings.fastingEnabled else { return .off }
        let target = settings.fastingTargetHours * 3600
        if let start = today?.eatingWindowStart {
            let elapsed = (today?.eatingWindowEnd ?? now).timeIntervalSince(start)
            let remaining: TimeInterval?
            if today?.eatingWindowEnd == nil {
                remaining = max(0, settings.fastingEatHours * 3600 - now.timeIntervalSince(start))
            } else {
                remaining = nil
            }
            return .eating(
                elapsed: max(0, elapsed),
                remaining: remaining,
                started: start,
                ended: today?.eatingWindowEnd
            )
        }
        let anchor = previousWindowEnd(previous: previous, settings: settings, calendar: calendar)
            ?? typicalWindow(on: calendar.date(byAdding: .day, value: -1, to: now) ?? now, settings: settings, calendar: calendar).end
        let elapsed = now.timeIntervalSince(anchor)
        return .fasting(elapsed: max(0, elapsed), target: target)
    }

    static func overnightDuration(
        today: DailyLog,
        previous: DailyLog?,
        settings: AppSettings,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> TimeInterval? {
        let start = today.eatingWindowStart
        let endAnchor = previousWindowEnd(previous: previous, settings: settings, calendar: calendar)
        guard let endAnchor else { return nil }
        let close = start ?? now
        return max(0, close.timeIntervalSince(endAnchor))
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
            guard log.eatingWindowStart != nil || calendar.isDate(log.date, inSameDayAs: now) else { continue }
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

    static func formatClock(_ interval: TimeInterval) -> String {
        let total = max(0, Int(interval))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }

    static func snapshotBits(
        today: DailyLog?,
        previous: DailyLog?,
        logs: [DailyLog],
        settings: AppSettings,
        now: Date = Date()
    ) -> (enabled: Bool, start: Date?, end: Date?, hours: Double, streak: Int, line: String) {
        let enabled = settings.fastingEnabled
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
