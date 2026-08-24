import Foundation
import GitBeacon

public struct FileShredderService: Sendable {
    /// Chunk size used when zero-overwriting a file's bytes before secure deletion.
    private static let zeroOverwriteChunkSize = 1_048_576 // 1MB chunk

    /// Direct immediate deletion bypassing Trash. Continues past per-item failures and aggregates them.
    public static func deletePermanently(urls: [URL]) throws {
        let fm = FileManager.default
        var failures: [(url: URL, error: any Error)] = []
        for url in urls where fm.fileExists(atPath: url.path) {
            try Task.checkCancellation()
            do {
                try fm.removeItem(at: url)
            } catch {
                failures.append((url, error))
            }
        }
        if !failures.isEmpty {
            throw Self.summarizeFailures(failures, totalCount: urls.count)
        }
    }

    /// Secure shredding: Overwrites bytes with zeros before removing file
    /// - Parameter resourceValuesProvider: Reads the `.fileSizeKey`/`.isDirectoryKey` attributes used
    ///   to decide whether to zero-overwrite before deleting. Defaults to the real
    ///   `URL.resourceValues(forKeys:)`; tests can inject a throwing provider to deterministically
    ///   simulate an attribute-read failure (e.g. permission errors) without needing real filesystem
    ///   ACL manipulation. Production callers should never pass this.
    public static func shredFiles(
        urls: [URL],
        resourceValuesProvider: @Sendable (URL) throws
            -> URLResourceValues = { try $0.resourceValues(forKeys: [.fileSizeKey, .isDirectoryKey, .isSymbolicLinkKey]) }) async throws {
        let fm = FileManager.default
        var failures: [(url: URL, error: any Error)] = []
        for url in urls {
            try Task.checkCancellation()
            guard fm.fileExists(atPath: url.path) else { continue }
            do {
                try shredSingleFile(url, fm: fm, resourceValuesProvider: resourceValuesProvider)
            } catch is CancellationError {
                // Cancellation aborts the whole batch immediately — it isn't a per-item failure to
                // continue past.
                throw CancellationError()
            } catch {
                failures.append((url, error))
            }
        }
        if !failures.isEmpty {
            throw Self.summarizeFailures(failures, totalCount: urls.count)
        }
    }

    private static func shredSingleFile(
        _ url: URL,
        fm: FileManager,
        resourceValuesProvider: @Sendable (URL) throws -> URLResourceValues) throws {
        // Deliberately not `try?`: if we can't read the file's attributes, we don't know
        // whether it's a non-empty regular file that needs zero-overwriting. Silently falling
        // through to a plain `removeItem` would delete the file without zeroing it while the
        // caller still believes the secure shred succeeded. Abort this item and let the error
        // propagate so the caller can surface it to the user instead.
        let values = try resourceValuesProvider(url)
        // `FileHandle(forWritingAtPath:)` follows a symlink to its target — zero-overwriting one
        // would destroy the TARGET file's bytes elsewhere on disk. A symlink itself has no content
        // worth shredding, so just remove the link.
        if values.isSymbolicLink ?? false {
            try fm.removeItem(at: url)
            return
        }
        if let isDir = values.isDirectory, !isDir,
           let fileSize = values.fileSize, fileSize > 0 {
            // Overwrite file with zero bytes in background
            guard let handle = FileHandle(forWritingAtPath: url.path) else {
                // Never silently skip the zero-overwrite and delete anyway — that would leave
                // the caller believing the file was securely shredded when its bytes were
                // never actually zeroed. Abort this item and let the error propagate instead.
                throw WilesError.operationFailed(reason: "Could not open \(url.lastPathComponent) for secure overwrite.")
            }
            let chunkSize = Self.zeroOverwriteChunkSize
            let zeroBuffer = Data(count: chunkSize)
            var bytesWritten = 0

            while bytesWritten < fileSize {
                if Task.isCancelled {
                    try? handle.close()
                    throw CancellationError()
                }
                let toWrite = min(chunkSize, fileSize - bytesWritten)
                if toWrite == chunkSize {
                    handle.write(zeroBuffer)
                } else {
                    handle.write(Data(count: toWrite))
                }
                bytesWritten += toWrite
            }
            do {
                try handle.synchronize()
            } catch {
                ErrorReporter.report(error, context: "Synchronizing zero-overwrite for \(url.path)")
            }
            do {
                try handle.close()
            } catch {
                ErrorReporter.report(error, context: "Closing file handle after zero-overwrite for \(url.path)")
            }
        }
        try fm.removeItem(at: url)
    }

    /// A single-item batch surfaces its one error directly instead of a "0 of 1" summary.
    private static func summarizeFailures(_ failures: [(url: URL, error: any Error)], totalCount: Int) -> any Error {
        if totalCount == 1, let onlyFailure = failures.first {
            return onlyFailure.error
        }
        let succeededCount = totalCount - failures.count
        let detail = failures.map { "\($0.url.lastPathComponent): \($0.error.localizedDescription)" }.joined(separator: "; ")
        return WilesError.operationFailed(reason: "\(succeededCount) of \(totalCount) items completed. Failed — \(detail)")
    }
}
