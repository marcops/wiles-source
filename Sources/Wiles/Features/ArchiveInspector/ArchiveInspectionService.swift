import AppKit
import Foundation
import GitBeacon

public enum ArchiveInspectionService: ArchiveInspectionServiceProtocol, Sendable {
    public static func listEntries(in archiveURL: URL) async throws -> [ArchiveEntryItem] {
        try await Task.detached(priority: .userInitiated) {
            // `unzip -Z1` mangles non-ASCII filenames (e.g. emoji) on this system: Apple's
            // bundled unzip lacks proper UTF-8 support and re-encodes names through the
            // process locale, even though tools like `ditto`/`zip` store genuine UTF-8 bytes
            // in the ZIP central directory. Parsing the central directory ourselves and
            // decoding names directly as UTF-8 sidesteps that mangling entirely.
            let data: Data
            do {
                data = try Data(contentsOf: archiveURL, options: .mappedIfSafe)
            } catch {
                // Can't read the archive at all — surface it instead of showing "no entries".
                throw WilesError.localized(key: .archiveExtractionFailed, arguments: [])
            }
            return ZIPCentralDirectoryReader.readEntryNames(from: data).map { ArchiveEntryItem(path: $0) }
        }.value
    }

    public static func extractSingleEntry(from archiveURL: URL, entryPath: String, to destinationFolder: URL) async throws -> URL {
        try await Task.detached(priority: .userInitiated) {
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
        // bytes afterward (DEV_RULES.md "Never Destroy User Data").
        // Staged in destinationFolder itself, not system temp — replaceItemAt() below is an atomic
        // move, which fails with EXDEV if the temp file and destURL are on different volumes.
        let tempURL = destinationFolder
            .appendingPathComponent(".\(UUID().uuidString)_\(entryName)")

        FileManager.default.createFile(atPath: tempURL.path, contents: nil, attributes: nil)
        guard let fileHandle = try? FileHandle(forWritingTo: tempURL) else {
            throw WilesError.localized(key: .archiveCouldNotCreateDestinationFile, arguments: [])
        }
        defer { try? fileHandle.close() }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        // `unzip` treats its file-spec argument as a shell-style glob, so an entry literally named
        // e.g. `foo[1].txt` would match `foo1.txt` instead. Backslash-escape its wildcard chars.
        process.arguments = ["-p", archiveURL.path, unzipLiteralPattern(entryPath)]

        // Direct standardOutput directly into the FileHandle.
        // The OS streams the unzipped bytes straight to disk, never accumulating them in RAM.
        // This prevents an immediate Out-Of-Memory (OOM) crash when extracting massive files.
        process.standardOutput = fileHandle

        try process.run()
        process.waitUntilExit()

        if process.terminationStatus != 0 {
            try? FileManager.default.removeItem(at: tempURL)
            throw WilesError.localized(key: .archiveExtractionFailed, arguments: [])
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

    /// Escapes `unzip`'s wildcard metacharacters so `entryPath` is matched literally. Backslash
    /// must be escaped first, before the characters it will be used to escape.
    static func unzipLiteralPattern(_ entryPath: String) -> String {
        var result = entryPath.replacingOccurrences(of: "\\", with: "\\\\")
        for wildcard in ["[", "]", "?", "*"] {
            result = result.replacingOccurrences(of: wildcard, with: "\\" + wildcard)
        }
        return result
    }
}
