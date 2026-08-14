import Foundation
import SwiftData
import OnPlanCore
import os.log

enum SharedModelContainer {
    private static var cached: ModelContainer?
    private static let log = Logger(subsystem: "com.dailyonplan", category: "CloudKit")

    private(set) static var usesCloudKit = false
    private(set) static var cloudKitError: String?

    @MainActor
    static func reset() {
        cached = nil
        usesCloudKit = false
        cloudKitError = nil
    }

    @MainActor
    static func reopen() throws -> ModelContainer {
        reset()
        return try shared()
    }

    @MainActor
    static func shared() throws -> ModelContainer {
        if let cached { return cached }

        let container: ModelContainer
        #if WIDGET_EXTENSION
        container = try AppGroupStore.makeContainer(cloudKit: .none)
        usesCloudKit = false
        #else
        container = try openJournal()
        #endif
        cached = container
        return container
    }

    #if !WIDGET_EXTENSION
    @MainActor
    private static func openJournal() throws -> ModelContainer {
        var lastError: Error?
        for style in [AppGroupStore.CloudKitStyle.automatic, .appGroupPrivate] {
            do {
                let container = try AppGroupStore.makeContainer(cloudKit: style)
                usesCloudKit = true
                cloudKitError = nil
                log.info("Opened journal with CloudKit (\(style.label, privacy: .public)) \(AppGroupIDs.cloudKitContainer, privacy: .public)")
                return container
            } catch {
                lastError = error
                log.error("CloudKit \(style.label, privacy: .public) failed: \(describe(error), privacy: .public)")
            }
        }
        cloudKitError = lastError.map(describe) ?? "Couldn’t open the iCloud journal"
        usesCloudKit = false
        return try AppGroupStore.makeContainer(cloudKit: .none)
    }
    #endif

    static func describe(_ error: Error) -> String {
        func flatten(_ error: Error) -> [String] {
            let ns = error as NSError
            var parts: [String] = []
            if let reason = ns.localizedFailureReason, !reason.isEmpty {
                parts.append(reason)
            }
            if !ns.localizedDescription.isEmpty {
                parts.append(ns.localizedDescription)
            }
            if let underlying = ns.userInfo[NSUnderlyingErrorKey] as? Error {
                parts.append(contentsOf: flatten(underlying))
            }
            return parts
        }
        let parts = flatten(error)
        if let useful = parts.first(where: {
            $0.localizedCaseInsensitiveContains("CloudKit")
                || $0.localizedCaseInsensitiveContains("optional")
                || $0.localizedCaseInsensitiveContains("default")
                || $0.localizedCaseInsensitiveContains("iCloud")
        }) {
            return useful
        }
        let text = error.localizedDescription
        if text.contains("SwiftDataError") {
            return "Couldn’t open the iCloud journal"
        }
        return text
    }
}
