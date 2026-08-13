import Foundation
import WatchConnectivity

/// iPhone ↔ Watch bridge. Phone is source of truth for SwiftData.
@MainActor
final class PhoneWatchBridge: NSObject, ObservableObject {
    static let shared = PhoneWatchBridge()

    @Published private(set) var isWatchReachable = false
    @Published private(set) var lastError: String?

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
    }

    func pushSnapshot() {
        guard let session, session.activationState == .activated else { return }
        // Avoid WCErrorCodeWatchAppNotInstalled spam when the companion isn't on the Watch yet.
        guard session.isPaired, session.isWatchAppInstalled else {
            return
        }
        let snapshot = QuickAddService.makeWatchSnapshot()
        let payload = WatchSnapshotCache.dictionary(from: snapshot)
        do {
            try session.updateApplicationContext(payload)
            if session.isReachable {
                session.sendMessage(payload, replyHandler: nil) { [weak self] error in
                    Task { @MainActor in
                        self?.lastError = error.localizedDescription
                    }
                }
            }
        } catch {
            let nsError = error as NSError
            if nsError.domain == WCErrorDomain,
               nsError.code == WCError.Code.watchAppNotInstalled.rawValue
                || nsError.code == WCError.Code.notReachable.rawValue {
                return
            }
            lastError = error.localizedDescription
        }
    }

    private func handleMessage(_ message: [String: Any]) -> [String: Any] {
        let actionRaw = message[WatchConnectivityKeys.action] as? String ?? ""
        let action = WatchConnectivityKeys.Action(rawValue: actionRaw)

        let result: QuickAddService.Result
        switch action {
        case .addWater:
            result = QuickAddService.addWaterBottle()
        case .addHydration:
            let oz = message[WatchConnectivityKeys.ounces] as? Double
            let electrolyte = message[WatchConnectivityKeys.electrolyte] as? Bool ?? false
            result = QuickAddService.addHydration(oz: oz, electrolyte: electrolyte)
        case .addCigarette:
            result = QuickAddService.addCigarette()
        case .addDrink:
            result = QuickAddService.addDrinks(1)
        case .addBathroomUrine:
            result = QuickAddService.addBathroom(kind: .urine)
        case .addBathroomStool:
            result = QuickAddService.addBathroom(kind: .stool)
        case .requestSnapshot, .none:
            let snapshot = QuickAddService.makeWatchSnapshot()
            var reply = WatchSnapshotCache.dictionary(from: snapshot)
            reply[WatchConnectivityKeys.ok] = true
            return reply
        }

        switch result {
        case .success:
            let snapshot = QuickAddService.makeWatchSnapshot()
            var reply = WatchSnapshotCache.dictionary(from: snapshot)
            reply[WatchConnectivityKeys.ok] = true
            pushSnapshot()
            return reply
        case .failure(let message):
            return [
                WatchConnectivityKeys.ok: false,
                WatchConnectivityKeys.error: message
            ]
        }
    }
}

extension PhoneWatchBridge: WCSessionDelegate {
    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        Task { @MainActor in
            self.isWatchReachable = session.isReachable
            if let error {
                self.lastError = error.localizedDescription
            }
            if activationState == .activated {
                self.pushSnapshot()
            }
        }
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in
            self.isWatchReachable = session.isReachable
            if session.isReachable {
                self.pushSnapshot()
            }
        }
    }

    nonisolated func sessionWatchStateDidChange(_ session: WCSession) {
        Task { @MainActor in
            if session.isWatchAppInstalled {
                self.pushSnapshot()
            }
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        Task { @MainActor in
            _ = self.handleMessage(message)
        }
    }

    nonisolated func session(
        _ session: WCSession,
        didReceiveMessage message: [String: Any],
        replyHandler: @escaping ([String: Any]) -> Void
    ) {
        Task { @MainActor in
            let reply = self.handleMessage(message)
            replyHandler(reply)
        }
    }
}
