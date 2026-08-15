import Foundation
import SwiftData

@MainActor
enum DataStore {
    static func makeContainer() -> ModelContainer {
        do {
            return try SharedModelContainer.shared()
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

    static func settings(in context: ModelContext) -> AppSettings {
        if let existing = existingSettings(in: context) {
            let before = existing.notificationsDefaultsVersionStored ?? 0
            existing.migrateNotificationDefaultsIfNeeded()
            existing.migrateClinicSupplementNamesIfNeeded()
            migrateChecklistSplitIfNeeded(in: context)
            if before < 5 {
                try? context.save()
            }
            return existing
        }
        let created = AppSettings()
        context.insert(created)
        try? context.save()
        return created
    }

    static func log(for date: Date, in context: ModelContext, defaultGoal: Int = 500) -> DailyLog {
        if let existing = existingLog(for: date, in: context) {
            return existing
        }
        let start = DateHelpers.startOfDay(date)
        let created = DailyLog(date: start, proteinGoal: defaultGoal)
        context.insert(created)
        try? context.save()
        return created
    }

    /// Returns an existing day log without creating one.
    /// If CloudKit has more than one row for the same calendar day (Mac used to
    /// insert an empty "today"), pick the row with the most activity.
    static func existingLog(for date: Date, in context: ModelContext) -> DailyLog? {
        let start = DateHelpers.startOfDay(date)
        let end = Calendar.current.date(byAdding: .day, value: 1, to: start) ?? start
        let descriptor = FetchDescriptor<DailyLog>(
            predicate: #Predicate { log in
                log.date >= start && log.date < end
            }
        )
        let logs = (try? context.fetch(descriptor)) ?? []
        guard let log = logs.max(by: { activityScore($0) < activityScore($1) }) else { return nil }
        var changed = false
        for other in logs where other.id != log.id {
            if log.eatingWindowStart == nil, let start = other.eatingWindowStart {
                log.eatingWindowStart = start
                changed = true
            }
            if log.eatingWindowEnd == nil, let end = other.eatingWindowEnd {
                log.eatingWindowEnd = end
                changed = true
            }
        }
        if changed {
            try? context.save()
        }
        #if !WIDGET_EXTENSION
        ChecklistStorage.migrateFatsSplit(on: log)
        #endif
        return log
    }

    /// Returns an existing settings row without creating one.
    /// Multiple AppSettings rows show up when Mac opened before iCloud arrived.
    static func existingSettings(in context: ModelContext) -> AppSettings? {
        let all = (try? context.fetch(FetchDescriptor<AppSettings>())) ?? []
        guard let settings = all.max(by: { settingsScore($0) < settingsScore($1) }) else { return nil }
        var changed = false
        for other in all where other.id != settings.id {
            if !settings.fastingEnabled, other.fastingEnabled {
                settings.fastingEnabled = true
                settings.fastingPreset = other.fastingPreset
                settings.fastingCustomFastHours = other.fastingCustomFastHours
                settings.fastingEatStartHour = other.fastingEatStartHour
                settings.fastingEatStartMinute = other.fastingEatStartMinute
                settings.fastingNotifyOpenEnabled = other.fastingNotifyOpenEnabled
                settings.fastingNotifyOpenMinutes = other.fastingNotifyOpenMinutes
                settings.fastingNotifyCloseEnabled = other.fastingNotifyCloseEnabled
                settings.fastingNotifyCloseMinutes = other.fastingNotifyCloseMinutes
                settings.fastingNotifyOvertimeEnabled = other.fastingNotifyOvertimeEnabled
                changed = true
            }
        }
        if changed {
            try? context.save()
        }
        return settings
    }

    private static func activityScore(_ log: DailyLog) -> Int {
        var score = log.proteins.count * 10
            + log.totalProteinCalories
            + log.slotWaterOz
            + log.cigarettesSmoked
            + log.drinksLogged
            + log.urineCount
            + log.stoolCount
        if log.eatingWindowStart != nil { score += 40 }
        if log.eatingWindowEnd != nil { score += 40 }
        if log.ketoneMmol != nil { score += 5 }
        if !log.notes.isEmpty { score += 2 }
        return score
    }

    private static func settingsScore(_ settings: AppSettings) -> Int {
        var score = settings.defaultProteinGoal / 25
        if settings.fastingEnabled { score += 80 }
        if settings.smokingMode.showsSection { score += 8 }
        if settings.drinkingMode.showsSection { score += 8 }
        if settings.showBathroomSection { score += 2 }
        return score
    }

    static func migrateChecklistSplitIfNeeded(in context: ModelContext) {
        #if WIDGET_EXTENSION
        return
        #else
        let logs = (try? context.fetch(FetchDescriptor<DailyLog>())) ?? []
        var changed = false
        for log in logs {
            let beforeFats = log.checkedFats.count
            let beforeVeg = log.checkedFatsAndVeggies.count
            ChecklistStorage.migrateFatsSplit(on: log)
            if log.checkedFats.count != beforeFats || log.checkedFatsAndVeggies.count != beforeVeg {
                changed = true
            }
        }
        if changed {
            try? context.save()
        }
        #endif
    }

    static func weight(for date: Date, in context: ModelContext) -> WeightEntry? {
        let start = DateHelpers.startOfDay(date)
        let end = Calendar.current.date(byAdding: .day, value: 1, to: start) ?? start
        var descriptor = FetchDescriptor<WeightEntry>(
            predicate: #Predicate { entry in
                entry.date >= start && entry.date < end
            }
        )
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }

    static func recentWeights(limit: Int = 14, in context: ModelContext) -> [WeightEntry] {
        var descriptor = FetchDescriptor<WeightEntry>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        return (try? context.fetch(descriptor)) ?? []
    }

    static func weights(from start: Date, to end: Date, in context: ModelContext) -> [WeightEntry] {
        let startDay = DateHelpers.startOfDay(start)
        let endExclusive = Calendar.current.date(byAdding: .day, value: 1, to: DateHelpers.startOfDay(end)) ?? end
        let descriptor = FetchDescriptor<WeightEntry>(
            predicate: #Predicate { entry in
                entry.date >= startDay && entry.date < endExclusive
            },
            sortBy: [SortDescriptor(\.date, order: .forward)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    static func logs(from start: Date, to end: Date, in context: ModelContext) -> [DailyLog] {
        let startDay = DateHelpers.startOfDay(start)
        let endDay = DateHelpers.startOfDay(end)
        let descriptor = FetchDescriptor<DailyLog>(
            predicate: #Predicate { log in
                log.date >= startDay && log.date <= endDay
            },
            sortBy: [SortDescriptor(\.date, order: .forward)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    static func bodyCompositions(from start: Date, to end: Date, in context: ModelContext) -> [BodyCompositionReading] {
        let startDay = DateHelpers.startOfDay(start)
        let endExclusive = Calendar.current.date(byAdding: .day, value: 1, to: DateHelpers.startOfDay(end)) ?? end
        let descriptor = FetchDescriptor<BodyCompositionReading>(
            predicate: #Predicate { entry in
                entry.date >= startDay && entry.date < endExclusive
            },
            sortBy: [SortDescriptor(\.date, order: .forward)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    static func allBodyCompositions(in context: ModelContext) -> [BodyCompositionReading] {
        let descriptor = FetchDescriptor<BodyCompositionReading>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    static func latestBodyComposition(in context: ModelContext) -> BodyCompositionReading? {
        var descriptor = FetchDescriptor<BodyCompositionReading>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }

    static func bodyMeasurements(from start: Date, to end: Date, in context: ModelContext) -> [BodyMeasurementEntry] {
        let startDay = DateHelpers.startOfDay(start)
        let endExclusive = Calendar.current.date(byAdding: .day, value: 1, to: DateHelpers.startOfDay(end)) ?? end
        let descriptor = FetchDescriptor<BodyMeasurementEntry>(
            predicate: #Predicate { entry in
                entry.date >= startDay && entry.date < endExclusive
            },
            sortBy: [SortDescriptor(\.date, order: .forward)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    static func allBodyMeasurements(in context: ModelContext) -> [BodyMeasurementEntry] {
        let descriptor = FetchDescriptor<BodyMeasurementEntry>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    static func hasAnyJournalData(in context: ModelContext) -> Bool {
        var logs = FetchDescriptor<DailyLog>()
        logs.fetchLimit = 1
        if let found = try? context.fetch(logs), !found.isEmpty { return true }
        var weights = FetchDescriptor<WeightEntry>()
        weights.fetchLimit = 1
        if let found = try? context.fetch(weights), !found.isEmpty { return true }
        return false
    }
}
