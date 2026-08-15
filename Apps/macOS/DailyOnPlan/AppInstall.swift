import AppKit

/// Copies the running app into `/Applications` and registers the desktop widget.
/// Store / Release builds omit the spawn path — App Store installs already live in Applications.
enum AppInstall {
    static var allowsSelfInstall: Bool {
        #if DEBUG
        true
        #else
        false
        #endif
    }

    static var applicationsURL: URL {
        FileManager.default.urls(for: .applicationDirectory, in: .localDomainMask).first
            ?? URL(fileURLWithPath: "/Applications")
    }

    static var installedAppURL: URL {
        applicationsURL.appendingPathComponent("Daily On Plan.app", isDirectory: true)
    }

    static func copyRunningAppToApplications() throws -> URL {
        #if DEBUG
        let src = Bundle.main.bundleURL
        let dest = installedAppURL
        guard src.standardizedFileURL != dest.standardizedFileURL else {
            registerLaunchServices(at: dest)
            return dest
        }

        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        task.arguments = [src.path, dest.path]
        let err = Pipe()
        task.standardError = err
        try task.run()
        task.waitUntilExit()
        guard task.terminationStatus == 0 else {
            let message = String(data: err.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            throw NSError(
                domain: "AppInstall",
                code: Int(task.terminationStatus),
                userInfo: [
                    NSLocalizedDescriptionKey: message?.isEmpty == false
                        ? message!
                        : "Copy to Applications failed (ditto \(task.terminationStatus)).",
                ]
            )
        }
        registerLaunchServices(at: dest)
        return dest
        #else
        throw NSError(
            domain: "AppInstall",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: "Self-install is only available in local Debug builds."]
        )
        #endif
    }

    static func launchInstalledAndTerminate() {
        #if DEBUG
        let dest = installedAppURL.path
        let escaped = dest.replacingOccurrences(of: "'", with: "'\\''")
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/zsh")
        task.arguments = ["-c", "((sleep 1.2; /usr/bin/open -n '\(escaped)') &)"]
        task.standardInput = FileHandle.nullDevice
        task.standardOutput = FileHandle.nullDevice
        task.standardError = FileHandle.nullDevice
        try? task.run()
        NSApp.terminate(nil)
        #endif
    }

    static func registerEmbeddedWidget() {
        #if DEBUG
        registerLaunchServices(at: Bundle.main.bundleURL)
        #endif
    }

    #if DEBUG
    private static func registerLaunchServices(at appURL: URL) {
        let plugin = appURL
            .appendingPathComponent("Contents/PlugIns/DailyOnPlanWidgets.appex", isDirectory: true)
        let lsregister = "/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
        _ = run("/usr/bin/xattr", ["-cr", appURL.path])
        _ = run(lsregister, ["-f", appURL.path])
        if FileManager.default.fileExists(atPath: plugin.path) {
            _ = run("/usr/bin/pluginkit", ["-a", plugin.path])
            _ = run("/usr/bin/pluginkit", ["-e", "use", "-i", "com.dailyonplan.macos.widgets"])
        }
    }

    @discardableResult
    private static func run(_ launchPath: String, _ arguments: [String]) -> Int32 {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: launchPath)
        task.arguments = arguments
        task.standardOutput = FileHandle.nullDevice
        task.standardError = FileHandle.nullDevice
        do {
            try task.run()
            task.waitUntilExit()
            return task.terminationStatus
        } catch {
            return -1
        }
    }
    #endif
}
