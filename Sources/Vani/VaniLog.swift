import Foundation

/// Append-only debug log at ~/Library/Application Support/Vani/debug.log.
/// The app's NSLog output doesn't surface through `log show` reliably, so
/// pipeline diagnostics (chunk decodes, timings, fallbacks) go here where
/// they can actually be read after a bad dictation. Cheap: a few lines per
/// dictation, truncated when it grows past ~1 MB.
enum VaniLog {
    private static let url: URL = {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Vani", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let file = dir.appendingPathComponent("debug.log")
        if let size = try? file.resourceValues(forKeys: [.fileSizeKey]).fileSize, size > 1_000_000 {
            try? FileManager.default.removeItem(at: file)
        }
        return file
    }()

    private static let stamp: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss.SSS"
        return f
    }()

    static func log(_ message: String) {
        NSLog("Vani: %@", message)
        let line = "\(stamp.string(from: Date())) \(message)\n"
        guard let data = line.data(using: .utf8) else { return }
        if let handle = try? FileHandle(forWritingTo: url) {
            defer { try? handle.close() }
            _ = try? handle.seekToEnd()
            try? handle.write(contentsOf: data)
        } else {
            try? data.write(to: url)
        }
    }
}
