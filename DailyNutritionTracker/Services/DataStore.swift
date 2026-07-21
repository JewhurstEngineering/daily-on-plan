import Foundation
import SwiftData

@MainActor
enum DataStore {
    static func makeContainer() -> ModelContainer {
        let schema = Schema([
            DailyLog.self,
            FeelingEntry.self,
            ProteinEntry.self,
            WorkoutEntry.self,
            WeightEntry.self,
            CustomFoodPreset.self,
            SavedMeal.self,
            AppSettings.self
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

    static func settings(in context: ModelContext) -> AppSettings {
        var descriptor = FetchDescriptor<AppSettings>()
        descriptor.fetchLimit = 1
        if let existing = try? context.fetch(descriptor).first {
            let before = existing.notificationsDefaultsVersionStored ?? 0
            existing.migrateNotificationDefaultsIfNeeded()
            if before < 4 {
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
        let start = DateHelpers.startOfDay(date)
        let end = Calendar.current.date(byAdding: .day, value: 1, to: start) ?? start
        var descriptor = FetchDescriptor<DailyLog>(
            predicate: #Predicate { log in
                log.date >= start && log.date < end
            }
        )
        descriptor.fetchLimit = 1
        if let existing = try? context.fetch(descriptor).first {
            return existing
        }
        let created = DailyLog(date: start, proteinGoal: defaultGoal)
        context.insert(created)
        try? context.save()
        return created
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
}
