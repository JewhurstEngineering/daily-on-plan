import Foundation
import HealthKit

@MainActor
final class HealthKitService: ObservableObject {
    static let shared = HealthKitService()

    private let store = HKHealthStore()
    @Published var isAuthorized = false

    private var waterType: HKQuantityType? {
        HKQuantityType.quantityType(forIdentifier: .dietaryWater)
    }

    private var bodyMassType: HKQuantityType? {
        HKQuantityType.quantityType(forIdentifier: .bodyMass)
    }

    var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    func requestAuthorization() async {
        guard isAvailable,
              let water = waterType,
              let mass = bodyMassType else { return }

        let share: Set<HKSampleType> = [water, mass, HKObjectType.workoutType()]
        let read: Set<HKObjectType> = [water, mass, HKObjectType.workoutType()]

        do {
            try await store.requestAuthorization(toShare: share, read: read)
            isAuthorized = true
        } catch {
            isAuthorized = false
        }
    }

    func writeWater(ounces: Int, on date: Date) async {
        guard let water = waterType else { return }
        await deleteSamples(of: water, on: date)
        guard ounces > 0 else { return }
        let liters = Double(ounces) * 0.0295735
        let quantity = HKQuantity(unit: .liter(), doubleValue: liters)
        let start = DateHelpers.startOfDay(date)
        let sample = HKQuantitySample(
            type: water,
            quantity: quantity,
            start: start,
            end: date
        )
        try? await store.save(sample)
    }

    func readWaterOunces(on date: Date) async -> Int? {
        guard let water = waterType else { return nil }
        let start = DateHelpers.startOfDay(date)
        let end = Calendar.current.date(byAdding: .day, value: 1, to: start) ?? start
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end)

        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: water,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, stats, _ in
                let liters = stats?.sumQuantity()?.doubleValue(for: .liter()) ?? 0
                let oz = Int((liters / 0.0295735).rounded())
                continuation.resume(returning: oz)
            }
            store.execute(query)
        }
    }

    func writeBodyMass(pounds: Double, on date: Date) async {
        guard let mass = bodyMassType, pounds > 0 else { return }
        await deleteSamples(of: mass, on: date)
        let quantity = HKQuantity(unit: .pound(), doubleValue: pounds)
        let start = DateHelpers.startOfDay(date)
        let sample = HKQuantitySample(type: mass, quantity: quantity, start: start, end: date)
        try? await store.save(sample)
    }

    func readBodyMassPounds(on date: Date) async -> Double? {
        guard let mass = bodyMassType else { return nil }
        let start = DateHelpers.startOfDay(date)
        let end = Calendar.current.date(byAdding: .day, value: 1, to: start) ?? start
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end)

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: mass,
                predicate: predicate,
                limit: 1,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)]
            ) { _, samples, _ in
                let value = (samples?.first as? HKQuantitySample)?
                    .quantity.doubleValue(for: .pound())
                continuation.resume(returning: value)
            }
            store.execute(query)
        }
    }

    func writeWorkout(name: String, durationMinutes: Int, on date: Date) async {
        guard durationMinutes > 0 else { return }
        let end = date
        let start = date.addingTimeInterval(-Double(durationMinutes) * 60)
        let workout = HKWorkout(
            activityType: .other,
            start: start,
            end: end,
            duration: Double(durationMinutes) * 60,
            totalEnergyBurned: nil,
            totalDistance: nil,
            metadata: [HKMetadataKeyWorkoutBrandName: name]
        )
        try? await store.save(workout)
    }

    private func deleteSamples(of type: HKQuantityType, on date: Date) async {
        let start = DateHelpers.startOfDay(date)
        let end = Calendar.current.date(byAdding: .day, value: 1, to: start) ?? start
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end)

        let samples: [HKSample] = await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: type,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: nil
            ) { _, samples, _ in
                continuation.resume(returning: samples ?? [])
            }
            store.execute(query)
        }

        // Only delete samples sourced from this app when possible
        let ours = samples.filter { $0.sourceRevision.source == HKSource.default() }
        guard !ours.isEmpty else { return }
        try? await store.delete(ours)
    }
}
