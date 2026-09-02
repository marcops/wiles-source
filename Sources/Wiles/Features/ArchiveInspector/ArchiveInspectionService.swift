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
        // `entryPath` is the raw central-directory name — attacker-controlled. A `..`/absolute name
        // would make the `ditto` fallback's `stagingDir.appendingPathComponent(entryPath)` resolve
        // OUTSIDE `stagingDir`, and the subsequent `moveItem` would then relocate an arbitrary
        // readable file (SSH keys, credentials). Same guard `ArchiveService.extractArchive` already
        // runs on every entry (HH-234).
        guard !ArchiveService.entryEscapesDestination(entryPath) else {
            throw WilesError.localized(key: .archiveExtractionFailed, arguments: [])
        }
        let entryName = (entryPath as NSString).lastPathComponent
        var destIsDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: destinationFolder.path, isDirectory: &destIsDirectory),
              destIsDirectory.boolValue else {
            throw WilesError.localized(key: .archiveCouldNotCreateDestinationFile, arguments: [])
        }
        // A guaranteed-free name (Finder's " 2"/" 3" convention) — extracting `foo.txt` into a
        // folder that already has `foo.txt` keeps both, never destroys the existing file
        // (DEV_RULES.md "Destination-Collision Handling Must Be Explicit and Non-Destructive").
        let destURL = FileSystemService.uniqueDestination(for: entryName, in: destinationFolder)

        // Fast path: `unzip -p` streams just this one entry to stdout — no whole-archive stage. Only
        // for a plain ASCII name with no `unzip` glob metacharacters: a non-ASCII name gets
        // re-encoded through the process locale and never matches, and a `[`/`*`/`?` would glob-match
        // a *different* entry. Everything else falls through to the `ditto` whole-archive path.
        if canUseUnzipPipe(for: entryPath),
           try extractSingleEntryViaUnzipPipe(archiveURL: archiveURL, entryPath: entryPath, to: destURL) {
            return destURL
        }

        // Stage the whole archive with `ditto`, which round-trips real UTF-8 entry names. `ditto`
        // streams to disk — entry bytes are never buffered in RAM. Staged inside `destinationFolder`
        // so the final move is a same-volume rename (no EXDEV); nothing lands at `destURL` until
        // extraction succeeded.
        let stagingDir = destinationFolder.appendingPathComponent(".\(UUID().uuidString)_unzip", isDirectory: true)
        try FileManager.default.createDirectory(at: stagingDir, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: stagingDir) }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        process.arguments = ["-x", "-k", archiveURL.path, stagingDir.path]
        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            throw WilesError.localized(key: .archiveExtractionFailed, arguments: [])
        }

        let extractedURL = stagingDir.appendingPathComponent(entryPath)
        // Defense in depth on top of the `entryEscapesDestination` gate above: confirm the resolved
        // path is still inside the staging dir before touching it, so a symlink planted by the
        // archive can't redirect the read/move either (HH-234).
        guard extractedURL.resolvingSymlinksInPath().isDescendantOrSelf(of: stagingDir.resolvingSymlinksInPath()) else {
            throw WilesError.localized(key: .archiveExtractionFailed, arguments: [])
        }
        guard FileManager.default.fileExists(atPath: extractedURL.path) else {
            throw WilesError.localized(key: .archiveExtractionFailed, arguments: [])
        }

        // `destURL` is a free name from `uniqueDestination`, so a plain move never clobbers
        // anything; if a race created a file there in the meantime, the move throws and the temp
        // staging dir is cleaned up by the `defer` above rather than overwriting.
        try FileManager.default.moveItem(at: extractedURL, to: destURL)
        return destURL
    }

    private static func canUseUnzipPipe(for entryPath: String) -> Bool {
        entryPath.allSatisfy(\.isASCII) && !entryPath.contains(where: { "[]*?\\".contains($0) })
    }

    /// Streams one entry via `unzip -p archive entry > destURL`. Returns `true` on success, `false`
    /// when `unzip` couldn't match the entry (so the caller uses the whole-archive `ditto` path).
    private static func extractSingleEntryViaUnzipPipe(archiveURL: URL, entryPath: String, to destURL: URL) throws -> Bool {
        FileManager.default.createFile(atPath: destURL.path, contents: nil)
        guard let sink = try? FileHandle(forWritingTo: destURL) else { return false }
        defer { try? sink.close() }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        process.arguments = ["-p", archiveURL.path, entryPath]
        process.standardOutput = sink
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
        } catch {
            try? FileManager.default.removeItem(at: destURL)
            return false
        }
        process.waitUntilExit()

        let writtenSize = (try? FileManager.default.attributesOfItem(atPath: destURL.path))?[.size] as? Int ?? 0
        let wroteSomething = writtenSize > 0
        // `unzip -p` exits 0 and writes the bytes on success; 11 = "no matching files" (non-ASCII
        // name, or a genuinely empty entry we can't tell apart — fall back to be safe).
        guard process.terminationStatus == 0, wroteSomething else {
            try? FileManager.default.removeItem(at: destURL)
            return false
        }
        return true
    }
}
