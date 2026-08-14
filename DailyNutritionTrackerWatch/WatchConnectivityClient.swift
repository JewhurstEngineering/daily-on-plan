import Foundation
import WatchConnectivity
import Combine
import WidgetKit

@MainActor
final class WatchConnectivityClient: NSObject, ObservableObject {
    static let shared = WatchConnectivityClient()

    @Published private(set) var snapshot: WatchDaySnapshot = WatchSnapshotCache.load()
    @Published private(set) var isReachable = false
    @Published private(set) var lastError: String?
    @Published private(set) var isSending = false

    private var session: WCSession?

    private override init() {
        super.init()
    }

    func activate() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()
        self.session = session
        snapshot = WatchSnapshotCache.load()
    }

    func requestSnapshot() {
        send(action: .requestSnapshot)
    }

    func addWater() {
        send(action: .addWater)
    }

    func addHydration(ounces: Double, electrolyte: Bool) {
        send(action: .addHydration, extras: [
            WatchConnectivityKeys.ounces: ounces,
            WatchConnectivityKeys.electrolyte: electrolyte
        ])
    }

    func addCigarette() {
        send(action: .addCigarette)
    }

    func addDrink() {
        send(action: .addDrink)
    }

    func addBathroomUrine() {
        send(action: .addBathroomUrine)
    }

    func addBathroomStool() {
        send(action: .addBathroomStool)
    }

    func startEating() {
        send(action: .startEating)
    }

    func endEating() {
        send(action: .endEating)
    }

    private func send(action: WatchConnectivityKeys.Action, extras: [String: Any] = [:]) {
        guard let session else {
            lastError = "WatchConnectivity unavailable."
            return
        }
        guard session.activationState == .activated else {
            lastError = "Not connected to iPhone yet."
            return
        }
        guard session.isReachable else {
            WatchActionQueue.enqueue(action: action, extras: extras)
            lastError = WatchActionQueue.pendingCount == 1
                ? "Queued — will send when iPhone is nearby."
                : "Queued \(WatchActionQueue.pendingCount) actions for iPhone."
            return
        }

        isSending = true
        lastError = nil
        var message: [String: Any] = [WatchConnectivityKeys.action: action.rawValue]
        extras.forEach { message[$0.key] = $0.value }
        session.sendMessage(message, replyHandler: { [weak self] reply in
            Task { @MainActor in
                self?.isSending = false
                if let ok = reply[WatchConnectivityKeys.ok] as? Bool, !ok {
                    self?.lastError = reply[WatchConnectivityKeys.error] as? String ?? "Request failed."
                    return
                }
                if let snapshot = WatchSnapshotCache.snapshot(from: reply) {
                    self?.apply(snapshot)
                }
            }
        }, errorHandler: { [weak self] error in
            Task { @MainActor in
                self?.isSending = false
                self?.lastError = error.localizedDescription
            }
        })
    }

    private func flushQueueIfNeeded() {
        guard session?.isReachable == true else { return }
        let pending = WatchActionQueue.drain()
        for item in pending {
            guard let action = WatchConnectivityKeys.Action(rawValue: item.action) else { continue }
            var extras: [String: Any] = [:]
            if let ounces = item.ounces {
                extras[WatchConnectivityKeys.ounces] = ounces
            }
            if let electrolyte = item.electrolyte {
                extras[WatchConnectivityKeys.electrolyte] = electrolyte
            }
            send(action: action, extras: extras)
        }
    }

    private func apply(_ snapshot: WatchDaySnapshot) {
        self.snapshot = snapshot
        WatchSnapshotCache.save(snapshot)
        WidgetCenter.shared.reloadAllTimelines()
    }
}

extension WatchConnectivityClient: WCSessionDelegate {
    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        Task { @MainActor in
            self.isReachable = session.isReachable
            if let error {
                self.lastError = error.localizedDescription
            }
            if activationState == .activated, session.isReachable {
                self.requestSnapshot()
                self.flushQueueIfNeeded()
            }
        }
    }

    #if os(iOS)
    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}
    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }
    #endif

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in
            self.isReachable = session.isReachable
            if session.isReachable {
                self.requestSnapshot()
                self.flushQueueIfNeeded()
            }
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        Task { @MainActor in
            if let snapshot = WatchSnapshotCache.snapshot(from: applicationContext) {
                self.apply(snapshot)
            }
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        Task { @MainActor in
            if let snapshot = WatchSnapshotCache.snapshot(from: message) {
                self.apply(snapshot)
            }
        }
    }
}
