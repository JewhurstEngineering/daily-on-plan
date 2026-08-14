import Foundation

enum ExportFileStore {
    static func exportsDirectory() throws -> URL {
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let dir = base.appendingPathComponent("Exports", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    static func uniqueURL(stem: String, ext: String) throws -> URL {
        let stamp = Int(Date().timeIntervalSince1970)
        return try exportsDirectory().appendingPathComponent("\(stem)-\(stamp).\(ext)")
    }
}
