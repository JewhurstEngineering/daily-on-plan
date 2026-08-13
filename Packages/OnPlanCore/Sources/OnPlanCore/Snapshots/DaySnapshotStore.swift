import Foundation

public enum ChromeSnapshotStore {
    public static let filename = "day-snapshot.json"
    public static let defaultsKey = "daySnapshotJSON"
    public static let watchTransferKey = "daySnapshotJSON"

    private static var groupIDs: [String] {
        #if os(iOS)
        [AppGroupIDs.iOS]
        #elseif os(watchOS)
        [AppGroupIDs.watch]
        #else
        [AppGroupIDs.macOS, AppGroupIDs.iOS]
        #endif
    }

    public static func write(_ snapshot: ChromeSnapshot) throws {
        let data = try JSONEncoder().encode(snapshot)
        #if os(watchOS)
        writeWatchData(data)
        return
        #endif

        for id in groupIDs {
            UserDefaults(suiteName: id)?.set(data, forKey: defaultsKey)
        }

        var lastError: Error?
        var wrote = false
        for url in candidateFiles {
            do {
                try FileManager.default.createDirectory(
                    at: url.deletingLastPathComponent(),
                    withIntermediateDirectories: true
                )
                try data.write(to: url, options: .atomic)
                wrote = true
            } catch {
                lastError = error
            }
        }
        if !wrote, let lastError { throw lastError }
    }

    public static func writeWatchLocal(_ snapshot: ChromeSnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        writeWatchData(data)
    }

    public static func read() -> ChromeSnapshot? {
        #if os(watchOS)
        return readWatchLocal()
        #endif
        for id in groupIDs {
            if let data = UserDefaults(suiteName: id)?.data(forKey: defaultsKey),
               let snap = decode(data) {
                return snap
            }
        }
        for url in candidateFiles {
            guard let data = try? Data(contentsOf: url), let snap = decode(data) else { continue }
            return snap
        }
        return nil
    }

    public static func readWatchLocal() -> ChromeSnapshot? {
        if let data = UserDefaults(suiteName: AppGroupIDs.watch)?.data(forKey: defaultsKey),
           let snap = decode(data) {
            return snap
        }
        if let data = UserDefaults.standard.data(forKey: defaultsKey), let snap = decode(data) {
            return snap
        }
        return nil
    }

    private static func decode(_ data: Data) -> ChromeSnapshot? {
        try? JSONDecoder().decode(ChromeSnapshot.self, from: data)
    }

    private static func writeWatchData(_ data: Data) {
        UserDefaults(suiteName: AppGroupIDs.watch)?.set(data, forKey: defaultsKey)
        UserDefaults.standard.set(data, forKey: defaultsKey)
    }

    private static var candidateFiles: [URL] {
        var urls: [URL] = []
        for id in groupIDs {
            if let root = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: id) {
                urls.append(
                    root
                        .appendingPathComponent("Library", isDirectory: true)
                        .appendingPathComponent("Application Support", isDirectory: true)
                        .appendingPathComponent("DailyOnPlan", isDirectory: true)
                        .appendingPathComponent(filename)
                )
            }
        }
        return urls
    }
}
