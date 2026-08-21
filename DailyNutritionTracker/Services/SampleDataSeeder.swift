#if DEBUG
import Foundation
import SwiftData

/// Fills an empty journal with a month of plausible days so the Trends charts can be
/// looked at during development. DEBUG only, opt-in, and it refuses to touch a journal
/// that already has anything in it.
///
/// Run with:  `xcrun simctl launch <device> com.dailyonplan.tracker -dop.seedSampleData YES`
/// Delete this file freely — nothing in the shipping app depends on it.
@MainActor
enum SampleDataSeeder {
    static var isRequested: Bool {
        UserDefaults.standard.bool(forKey: "dop.seedSampleData")
    }

    static func seedIfRequested(in context: ModelContext) {
        guard isRequested else { return }
        guard !DataStore.hasAnyJournalData(in: context) else { return }

        let calendar = Calendar.current
        let today = DateHelpers.startOfDay(Date())
        let settings = DataStore.settings(in: context)
        settings.defaultProteinGoal = 1210
        settings.hydrationTargetOz = 175
        settings.goalWeightLbs = 225
        settings.heightInches = 70

        // A slow, noisy downward trend — the shape a real cut actually makes.
        var weight = 363.2
        let proteinByDay = [1240, 1008, 1310, 980, 1150, 1210, 1042, 1288, 902, 1176,
                            1225, 1090, 1160, 1008, 1272, 1140, 996, 1218, 1305, 1064,
                            1188, 1232, 940, 1120, 1256, 1082, 1198, 1244, 1030, 1008]
        let waterByDay = [176, 120, 188, 96, 142, 175, 108, 181, 88, 150,
                          178, 124, 160, 178, 190, 132, 104, 175, 186, 116,
                          154, 180, 92, 138, 182, 126, 166, 184, 110, 178]

        for offset in stride(from: 29, through: 0, by: -1) {
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { continue }
            let index = 29 - offset

            let log = DailyLog(date: day, proteinGoal: 1210)
            log.followedPlan = index % 10 != 3
            log.ketosis = index % 3 != 0
            context.insert(log)

            // Split the day's calories over two or three entries so the protein log
            // and the "what I've been eating" report have something to show.
            let total = proteinByDay[index]
            let names = ["Ready to Drink Shake", "Ground turkey (85% lean)", "Dinner Franks 1/4 Lb"]
            var remaining = total
            for (slot, name) in names.enumerated() {
                let calories = slot == names.count - 1 ? remaining : total / 3
                remaining -= calories
                guard calories > 0 else { continue }
                let entry = ProteinEntry(
                    name: name,
                    time: calendar.date(byAdding: .hour, value: 8 + slot * 5, to: day) ?? day,
                    servingSize: "1 serving",
                    calories: calories,
                    proteinCategory: ProteinCategory.other.rawValue,
                    servings: 1
                )
                context.insert(entry)
                log.proteins.append(entry)
            }

            // Pour the day's water in bottle-sized measures, electrolytes twice a week.
            var poured = 0
            let bottle = 16.9
            while Double(waterByDay[index] - poured) >= bottle {
                let kind: HydrationDrinkKind = (poured == 0 && index % 3 == 0) ? .electrolyte : .water
                log.fillNextWaterSlot(oz: bottle, ensuringMinimumSlots: 11, kind: kind)
                poured += Int(bottle)
            }

            weight -= Double.random(in: 0.4...1.4)
            if index % 4 == 0 { weight += Double.random(in: 0.2...0.8) }
            context.insert(WeightEntry(date: day, weightLbs: (weight * 10).rounded() / 10))
        }

        try? context.save()
    }
}
#endif
