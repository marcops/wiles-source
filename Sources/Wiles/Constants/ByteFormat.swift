import Foundation

/// One shared `ByteCountFormatter` for the whole app. `ByteCountFormatter.string(fromByteCount:
/// countStyle:)` builds a throwaway formatter on every call — cheap once, but it's read per row
/// per render in the file list, disk-usage sidebar, footer, tooltips, etc. Same lock-guarded
/// shared-formatter pattern as `FileItem.dateFormatterCache`.
enum ByteFormat {
    private static let lock = NSLock()
    private nonisolated(unsafe) static let formatter: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter
    }()

    static func fileSize(_ byteCount: Int64) -> String {
        lock.lock()
        defer { lock.unlock() }
        return formatter.string(fromByteCount: byteCount)
    }
}
