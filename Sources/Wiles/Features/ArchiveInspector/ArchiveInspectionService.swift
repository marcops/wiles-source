import Foundation
import AppKit

public final class ArchiveInspectionService: ArchiveInspectionServiceProtocol, Sendable {
    public static func listEntries(in archiveURL: URL) async -> [ArchiveEntryItem] {
        return await Task.detached(priority: .userInitiated) {
            // `unzip -Z1` mangles non-ASCII filenames (e.g. emoji) on this system: Apple's
            // bundled unzip lacks proper UTF-8 support and re-encodes names through the
            // process locale, even though tools like `ditto`/`zip` store genuine UTF-8 bytes
            // in the ZIP central directory. Parsing the central directory ourselves and
            // decoding names directly as UTF-8 sidesteps that mangling entirely.
            guard let data = try? Data(contentsOf: archiveURL, options: .mappedIfSafe) else { return [] }
            return ZIPCentralDirectoryReader.readEntryNames(from: data).map { ArchiveEntryItem(path: $0) }
        }.value
    }

    public static func extractSingleEntry(from archiveURL: URL, entryPath: String, to destinationFolder: URL) async throws -> URL {
        return try await Task.detached(priority: .userInitiated) {
            try extractSingleEntrySync(from: archiveURL, entryPath: entryPath, to: destinationFolder)
        }.value
    }

    private static func extractSingleEntrySync(from archiveURL: URL, entryPath: String, to destinationFolder: URL) throws -> URL {
        let entryName = (entryPath as NSString).lastPathComponent
        let destURL = destinationFolder.appendingPathComponent(entryName)

        // Extract into a temporary file first — never touch a pre-existing file at destURL
        // until extraction is confirmed successful. Truncating destURL up front (the old
        // behavior) permanently destroyed any existing file there the instant this ran, even
        // if extraction subsequently failed, since there was no way to restore the original
        // bytes afterward (AGENTS.md rule 35: never destroy user data before the constructive
        // half of the operation is confirmed to succeed).
        let tempURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("\(UUID().uuidString)_\(entryName)")

        FileManager.default.createFile(atPath: tempURL.path, contents: nil, attributes: nil)
        guard let fileHandle = try? FileHandle(forWritingTo: tempURL) else {
            throw NSError(domain: "ArchiveInspectionService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not create destination file."])
        }
        defer { try? fileHandle.close() }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        process.arguments = ["-p", archiveURL.path, entryPath]

        // Direct standardOutput directly into the FileHandle.
        // The OS streams the unzipped bytes straight to disk, never accumulating them in RAM.
        // This prevents an immediate Out-Of-Memory (OOM) crash when extracting massive files.
        process.standardOutput = fileHandle

        try process.run()
        process.waitUntilExit()

        if process.terminationStatus != 0 {
            try? FileManager.default.removeItem(at: tempURL)
            throw NSError(domain: "ArchiveInspectionService", code: Int(process.terminationStatus), userInfo: [NSLocalizedDescriptionKey: "Extraction process failed."])
        }

        // Extraction succeeded — only now is it safe to replace any pre-existing file at
        // destURL. `replaceItemAt` atomically swaps the temp file into place.
        try? fileHandle.close()
        do {
            _ = try FileManager.default.replaceItemAt(destURL, withItemAt: tempURL)
        } catch {
            try? FileManager.default.removeItem(at: tempURL)
            throw error
        }

        return destURL
    }
}
