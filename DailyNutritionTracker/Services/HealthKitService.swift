import Foundation
import HealthKit
import UIKit

enum HealthKitAuthStatus: Equatable {
    case unavailable
    case notDetermined
    case sharingDenied
    case sharingAuthorized

    var title: String {
        switch self {
        case .unavailable: return "Apple Health unavailable"
        case .notDetermined: return "Not connected yet"
        case .sharingDenied: return "Access denied or limited"
        case .sharingAuthorized: return "Connected"
        }
    }
}

@MainActor
final class HealthKitService: ObservableObject {
    static let shared = HealthKitService()

    private let store = HKHealthStore()
    @Published var isAuthorized = false
    @Published var authStatus: HealthKitAuthStatus = .notDetermined
    @Published var lastMessage: String?

    private var waterType: HKQuantityType? {
        HKQuantityType.quantityType(forIdentifier: .dietaryWater)
    }

    private var bodyMassType: HKQuantityType? {
        HKQuantityType.quantityType(forIdentifier: .bodyMass)
    }

    private var alcoholType: HKQuantityType? {
        HKQuantityType.quantityType(forIdentifier: .numberOfAlcoholicBeverages)
    }

    var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    func refreshStatus() {
        guard isAvailable,
              let water = waterType,
              let mass = bodyMassType else {
            authStatus = .unavailable
            isAuthorized = false
            return
        }
        let waterStatus = store.authorizationStatus(for: water)
        let massStatus = store.authorizationStatus(for: mass)
        let alcoholStatus = alcoholType.map { store.authorizationStatus(for: $0) } ?? .notDetermined

        if waterStatus == .notDetermined && massStatus == .notDetermined && alcoholStatus == .notDetermined {
            authStatus = .notDetermined
            isAuthorized = false
        } else if waterStatus == .sharingAuthorized || massStatus == .sharingAuthorized || alcoholStatus == .sharingAuthorized {
            authStatus = .sharingAuthorized
            isAuthorized = true
        } else {
            authStatus = .sharingDenied
            isAuthorized = false
        }
    }

    func requestAuthorization() async {
        guard isAvailable,
              let water = waterType,
              let mass = bodyMassType else {
            authStatus = .unavailable
            lastMessage = "Apple Health isn’t available on this device."
            return
        }

        var share: Set<HKSampleType> = [water, mass, HKObjectType.workoutType()]
        var read: Set<HKObjectType> = [water, mass, HKObjectType.workoutType()]
        if let alcohol = alcoholType {
            share.insert(alcohol)
            read.insert(alcohol)
        }

        do {
            try await store.requestAuthorization(toShare: share, read: read)
            refreshStatus()
            switch authStatus {
            case .sharingAuthorized:
                lastMessage = "Apple Health connected. Water, weight, workouts, and drinks can sync."
            case .sharingDenied:
                lastMessage = "Permissions look limited. Open the Health app → Sharing → Apps to allow \(AppIdentity.displayName)."
            case .notDetermined:
                lastMessage = "Health didn’t return a clear status. Try again, or open Health settings."
            case .unavailable:
                lastMessage = "Apple Health isn’t available."
            }
        } catch {
            isAuthorized = false
            refreshStatus()
            lastMessage = error.localizedDescription
        }
    }

    func openHealthOrSystemSettings() {
        // Prefer Health app; fall back to app settings.
        if let healthURL = URL(string: "x-apple-health://"), UIApplication.shared.canOpenURL(healthURL) {
            UIApplication.shared.open(healthURL)
        } else if let settings = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(settings)
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

    func writeAlcoholicDrinks(count: Int, on date: Date) async {
        guard let alcohol = alcoholType else { return }
        await deleteSamples(of: alcohol, on: date)
        guard count > 0 else { return }
        let quantity = HKQuantity(unit: .count(), doubleValue: Double(count))
        let sample = HKQuantitySample(
            type: alcohol,
            quantity: quantity,
            start: date,
            end: date
        )
        try? await store.save(sample)
    }

    func readAlcoholicDrinks(on date: Date) async -> Int? {
        guard let alcohol = alcoholType else { return nil }
        let start = DateHelpers.startOfDay(date)
        let end = Calendar.current.date(byAdding: .day, value: 1, to: start) ?? start
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end)

        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: alcohol,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, stats, _ in
                let value = stats?.sumQuantity()?.doubleValue(for: .count()) ?? 0
                continuation.resume(returning: Int(value.rounded()))
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

        let ours = samples.filter { $0.sourceRevision.source == HKSource.default() }
        guard !ours.isEmpty else { return }
        try? await store.delete(ours)
    }
}
