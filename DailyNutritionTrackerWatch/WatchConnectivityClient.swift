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
            lastError = "Open Daily On Plan on iPhone to sync."
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
