import Foundation

public struct FileShredderService: Sendable {
    /// Direct immediate deletion bypassing Trash (Fast, no zeroing)
    public static func deletePermanently(urls: [URL]) throws {
        let fm = FileManager.default
        for url in urls where fm.fileExists(atPath: url.path) {
            try Task.checkCancellation()
            try fm.removeItem(at: url)
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
        resourceValuesProvider: @Sendable (URL) throws -> URLResourceValues = { try $0.resourceValues(forKeys: [.fileSizeKey, .isDirectoryKey]) }
    ) async throws {
        let fm = FileManager.default
        for url in urls {
            try Task.checkCancellation()
            guard fm.fileExists(atPath: url.path) else { continue }

            // Deliberately not `try?`: if we can't read the file's attributes, we don't know
            // whether it's a non-empty regular file that needs zero-overwriting. Silently falling
            // through to a plain `removeItem` would delete the file without zeroing it while the
            // caller still believes the secure shred succeeded. Abort this item and let the error
            // propagate so the caller can surface it to the user instead.
            let values = try resourceValuesProvider(url)
            if let isDir = values.isDirectory, !isDir,
               let fileSize = values.fileSize, fileSize > 0 {

                // Overwrite file with zero bytes in background
                if let handle = FileHandle(forWritingAtPath: url.path) {
                    let chunkSize = 1_048_576 // 1MB chunk
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
                    try? handle.synchronize()
                    try? handle.close()
                }
            }
            try fm.removeItem(at: url)
        }
    }
}
