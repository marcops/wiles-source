import Foundation

public struct FileShredderService: Sendable {
    /// Direct immediate deletion bypassing Trash. Continues past per-item failures and aggregates them.
    ///
    /// There is no "secure"/zero-overwrite variant: Wiles runs only on macOS 14+, i.e. exclusively
    /// SSD-backed APFS volumes, where overwriting a file's logical bytes does not overwrite the
    /// physical flash cells (copy-on-write + wear-leveling relocate the write). Apple removed
    /// "Secure Empty Trash" for the same reason. FileVault is the real at-rest protection.
    public static func deletePermanently(urls: [URL]) throws {
        let fm = FileManager.default
        var failures: [(url: URL, error: any Error)] = []
        var deletedCount = 0
        for url in urls where fm.fileExists(atPath: url.path) {
            do {
                try Task.checkCancellation()
            } catch {
                // Cancelled mid-batch: what's deleted is permanently gone, so surface a real error
                // instead of the CancellationError `runDetachedFileOperation` swallows.
                throw Self.cancelledPartialError(deletedCount: deletedCount, totalCount: urls.count) ?? error
            }
            do {
                try fm.removeItem(at: url)
                deletedCount += 1
            } catch {
                failures.append((url, error))
            }
        }
        if !failures.isEmpty {
            throw Self.summarizeFailures(failures, totalCount: urls.count)
        }
    }

    /// Error to surface when a shred is cancelled after `deletedCount` of `totalCount` were removed.
    /// `nil` when nothing was deleted yet — a bare `CancellationError` propagates fine then.
    static func cancelledPartialError(deletedCount: Int, totalCount: Int) -> (any Error)? {
        guard deletedCount > 0 else { return nil }
        return WilesError.localized(
            key: .fileShredderCancelledPartial, arguments: ["\(deletedCount)", "\(totalCount)"])
    }

    /// A single-item batch surfaces its one error directly instead of a "0 of 1" summary.
    private static func summarizeFailures(_ failures: [(url: URL, error: any Error)], totalCount: Int) -> any Error {
        if totalCount == 1, let onlyFailure = failures.first {
            return onlyFailure.error
        }
        let succeededCount = totalCount - failures.count
        let detail = failures.map { "\($0.url.lastPathComponent): \($0.error.localizedDescription)" }.joined(separator: "; ")
        return WilesError.localized(
            key: .fileShredderPartialFailure, arguments: ["\(succeededCount)", "\(totalCount)", detail])
    }
}
