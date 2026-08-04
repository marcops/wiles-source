import Foundation

public struct FileShredderService: Sendable {
    /// Direct immediate deletion bypassing Trash (Fast, no zeroing)
    public static func deletePermanently(urls: [URL]) throws {
        let fm = FileManager.default
        for url in urls where fm.fileExists(atPath: url.path) {
            try fm.removeItem(at: url)
        }
    }

    /// Secure shredding: Overwrites bytes with zeros before removing file
    public static func shredFiles(urls: [URL]) async throws {
        let fm = FileManager.default
        for url in urls {
            guard fm.fileExists(atPath: url.path) else { continue }

            if let values = try? url.resourceValues(forKeys: [.fileSizeKey, .isDirectoryKey]),
               let isDir = values.isDirectory, !isDir,
               let fileSize = values.fileSize, fileSize > 0 {

                // Overwrite file with zero bytes in background
                if let handle = FileHandle(forWritingAtPath: url.path) {
                    let chunkSize = 1_048_576 // 1MB chunk
                    let zeroBuffer = Data(count: chunkSize)
                    var bytesWritten = 0

                    while bytesWritten < fileSize {
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
