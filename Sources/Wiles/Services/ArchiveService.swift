import Foundation
import GitBeacon

public final class ArchiveService: Sendable {
    public static func isArchive(url: URL) -> Bool {
        let ext = url.pathExtension.lowercased()
        let name = url.lastPathComponent.lowercased()
        return hasArchiveExtension(ext: ext, name: name)
    }

    /// True for `.zip`/`.tar`/`.tgz` by extension, or any `.tar.*` compound suffix (`.tar.gz`,
    /// `.tar.bz2`, `.tar.xz`) that `pathExtension` alone can't see since it only reports the last
    /// component. Shared by `isArchive` and `extractArchive`'s tar-vs-ditto dispatch.
    private static func hasArchiveExtension(ext: String, name: String) -> Bool {
        ext == "zip" || ext == "tar" || ext == "tgz" || isTarFamily(name: name)
    }

    private static func isTarFamily(name: String) -> Bool {
        name.hasSuffix(".tar.gz") || name.hasSuffix(".tar.bz2") || name.hasSuffix(".tar.xz")
    }

    private static func isTarArchive(ext: String, name: String) -> Bool {
        ext == "tar" || ext == "tgz" || isTarFamily(name: name)
    }

    public static func compressToZIP(urls: [URL], in destinationFolder: URL, password: String? = nil) throws {
        guard !urls.isEmpty else { return }
        let destURL = uniqueZipDestination(for: urls, in: destinationFolder)
        do {
            if password == nil, urls.count == 1 {
                try runCompressionProcess(
                    executable: "/usr/bin/ditto",
                    arguments: ["-c", "-k", "--sequesterRsrc", urls[0].path, destURL.path],
                    failureContext: "ditto -c of \(urls[0].lastPathComponent)")
            } else {
                try zipItemsIndividually(urls: urls, to: destURL, password: password)
            }
        } catch {
            // The half-written archive is our own incomplete artifact, never a user input — remove
            // it so a partial `.zip` isn't left behind and a retry starts clean.
            try? FileManager.default.removeItem(at: destURL)
            throw error
        }
    }

    /// `ditto -c` rejects multiple sources ("Can't archive multiple sources"), and a
    /// password-protected archive needs `zip` regardless of count, so both cases go through
    /// `zip -r` here. Sources aren't guaranteed to share a parent directory (or live inside
    /// destinationFolder at all), so each item gets its own `zip -r` invocation with
    /// currentDirectoryURL set to *that item's own parent* and only its lastPathComponent as
    /// the argument — zip appends to an existing archive by default, so repeated calls build up
    /// the same destURL. This is what actually preserves each item's internal folder structure
    /// (recursing relative to its own parent, not flattened via -j) while still finding sources
    /// that live outside destinationFolder or outside each other.
    private static func zipItemsIndividually(urls: [URL], to destURL: URL, password: String?) throws {
        for url in urls {
            var args = ["-r"]
            var environment: [String: String]?
            if let pwd = password, !pwd.isEmpty {
                environment = zipPasswordEnvironment(pwd)
            }
            args.append(contentsOf: [destURL.path, url.lastPathComponent])
            try runCompressionProcess(
                executable: "/usr/bin/zip", arguments: args,
                currentDirectoryURL: url.deletingLastPathComponent(), environment: environment,
                failureContext: "zip -r of \(url.lastPathComponent) into \(destURL.lastPathComponent)")
        }
    }

    /// The `zip` password goes through the `ZIP` env var for every password (no whitespace-based
    /// branching): argv is visible via `ps`/Activity Monitor to any local process, another process's
    /// environment is not. macOS's Info-ZIP won't read the password from stdin (`-e` demands a tty),
    /// so this is the one non-argv path available. The value is wrapped in double quotes with `\`
    /// and `"` escaped so `zip`'s own env tokenizer keeps spaces and quotes in the password intact.
    private static func zipPasswordEnvironment(_ password: String) -> [String: String] {
        let escaped = password
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        var environment = ProcessInfo.processInfo.environment
        environment["ZIP"] = "-P \"\(escaped)\""
        return environment
    }

    private static func uniqueZipDestination(for urls: [URL], in destinationFolder: URL) -> URL {
        let baseName = urls.count == 1 ? urls[0].deletingPathExtension().lastPathComponent : "Archive"
        let candidateURL = destinationFolder.appendingPathComponent("\(baseName).zip")
        return UniqueFileNaming.uniqueURL(for: candidateURL, in: destinationFolder, isDirectory: false)
    }

    private struct ProcessRunResult {
        let terminationStatus: Int32
        let standardOutput: Data
        let standardError: String
    }

    /// Accumulates subprocess stderr up to `capacity` bytes so a chatty tool can't grow it without
    /// bound; anything past the cap is dropped. Thread-safe — `readabilityHandler` fires on an
    /// arbitrary queue while the main flow reads `text` after `waitUntilExit()`.
    private final class BoundedStderr: @unchecked Sendable {
        private let capacity = 16 * 1024
        private let lock = NSLock()
        private var data = Data()

        func append(_ chunk: Data) {
            guard !chunk.isEmpty else { return }
            lock.lock()
            defer { lock.unlock() }
            let room = capacity - data.count
            guard room > 0 else { return }
            data.append(chunk.prefix(room))
        }

        var text: String {
            lock.lock()
            defer { lock.unlock() }
            return String(bytes: data, encoding: .utf8) ?? ""
        }
    }

    /// Runs a subprocess to completion and returns its exit status, stdout (when
    /// `captureStandardOutput` is set) and a bounded capture of stderr. Blocks on `waitUntilExit()` —
    /// every caller (`AppState+Archive`) already runs this inside `Task.detached`, so it must never
    /// be called directly on the main actor. Only `process.run()` throws here; a non-zero exit is
    /// returned, not thrown, so each caller maps it to its own localized error (or, for the listing
    /// probe, treats it as "no collision").
    @discardableResult
    private static func runProcess(
        executable: String, arguments: [String], currentDirectoryURL: URL? = nil,
        environment: [String: String]? = nil, captureStandardOutput: Bool = false) throws -> ProcessRunResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.currentDirectoryURL = currentDirectoryURL
        process.environment = environment

        let errorPipe = Pipe()
        process.standardError = errorPipe
        // Capture stderr into a bounded buffer rather than discarding it — the tool's own message is
        // the only diagnostic on a failure. Draining continuously also stops a full kernel pipe
        // buffer from blocking the subprocess forever on write, which would hang waitUntilExit().
        let stderrBuffer = BoundedStderr()
        errorPipe.fileHandleForReading.readabilityHandler = { handle in stderrBuffer.append(handle.availableData) }

        let outputPipe = captureStandardOutput ? Pipe() : nil
        process.standardOutput = outputPipe

        try process.run()
        // Read stdout to EOF *before* waitUntilExit to avoid the same pipe-buffer deadlock.
        let output = outputPipe?.fileHandleForReading.readDataToEndOfFile() ?? Data()
        process.waitUntilExit()
        errorPipe.fileHandleForReading.readabilityHandler = nil
        return ProcessRunResult(
            terminationStatus: process.terminationStatus, standardOutput: output, standardError: stderrBuffer.text)
    }

    private static func runCompressionProcess(
        executable: String, arguments: [String], currentDirectoryURL: URL? = nil,
        environment: [String: String]? = nil, failureContext: String) throws {
        let result = try runProcess(
            executable: executable, arguments: arguments,
            currentDirectoryURL: currentDirectoryURL, environment: environment)
        guard result.terminationStatus != 0 else { return }
        let failure = WilesError.localized(key: .archiveCompressionFailed, arguments: [])
        ErrorReporter.report(failure, context: diagnosticContext(failureContext, result))
        throw failure
    }

    /// Diagnostic-only string for `ErrorReporter` — carries the failing item and the tool's captured
    /// stderr. Never shown to the user (the thrown `WilesError` stays the user-facing message).
    private static func diagnosticContext(_ prefix: String, _ result: ProcessRunResult) -> String {
        let trimmed = result.standardError.trimmingCharacters(in: .whitespacesAndNewlines)
        return "\(prefix) - exit \(result.terminationStatus): \(trimmed.isEmpty ? "(no stderr)" : trimmed)"
    }

    /// Blocks on `waitUntilExit()`; same off-main-thread requirement as `runCompressionProcess`,
    /// and every caller (`AppState+Archive`) already honors it via `Task.detached`.
    public static func extractArchive(archiveURL: URL, to destinationFolder: URL) throws {
        let name = archiveURL.lastPathComponent.lowercased()
        let ext = archiveURL.pathExtension.lowercased()

        // One listing pass feeds both the traversal check and the collision check.
        let entries = listArchiveEntries(archiveURL: archiveURL, ext: ext, name: name)

        // Defense in depth: refuse the whole archive upfront if any entry would escape the
        // destination, before invoking the extraction tool at all.
        try rejectUnsafeEntries(entries)

        // Extracting flat risks silently overwriting same-named existing files. Only when a real
        // collision is detected upfront does extraction redirect into a fresh, uniquely-named
        // subfolder instead — the common no-collision case still extracts flat, unchanged.
        let extractionFolder = collidesWithExisting(entries: entries, in: destinationFolder)
            ? UniqueFileNaming.uniqueURL(
                for: destinationFolder.appendingPathComponent(archiveURL.deletingPathExtension().lastPathComponent),
                in: destinationFolder, isDirectory: true)
            : destinationFolder
        try FileManager.default.createDirectory(at: extractionFolder, withIntermediateDirectories: true)

        let executable: String
        let arguments: [String]
        if isTarArchive(ext: ext, name: name) {
            executable = "/usr/bin/tar"
            arguments = ["-xf", archiveURL.path, "-C", extractionFolder.path]
        } else {
            // `.zip` and everything else fall back to ditto's zip extraction.
            executable = "/usr/bin/ditto"
            arguments = ["-x", "-k", archiveURL.path, extractionFolder.path]
        }

        let result = try runProcess(executable: executable, arguments: arguments)
        if result.terminationStatus != 0 {
            let failure = WilesError.localized(key: .archiveExtractionFailed, arguments: [])
            ErrorReporter.report(
                failure, context: diagnosticContext("\(executable) extraction of \(archiveURL.lastPathComponent)", result))
            throw failure
        }
    }

    /// Lists the archive's entry paths via the same tool used elsewhere (`unzip -Z1` / `tar -tf`),
    /// one per line. Returns `nil` when the type isn't listable here or the listing tool fails, so
    /// callers fall back to their own safe default rather than blocking on a diagnostic-only step.
    private static func listArchiveEntries(archiveURL: URL, ext: String, name: String) -> [String]? {
        let executable: String
        let arguments: [String]
        if ext == "zip" {
            executable = "/usr/bin/unzip"
            arguments = ["-Z1", archiveURL.path]
        } else if isTarArchive(ext: ext, name: name) {
            executable = "/usr/bin/tar"
            arguments = ["-tf", archiveURL.path]
        } else {
            return nil
        }
        guard let result = try? runProcess(executable: executable, arguments: arguments, captureStandardOutput: true),
              result.terminationStatus == 0,
              let listing = String(bytes: result.standardOutput, encoding: .utf8) else { return nil }
        return listing.split(separator: "\n").map(String.init)
    }

    /// Defense in depth ([L34]): `bsdtar`/`ditto` normally refuse to write outside the destination,
    /// but reject the whole extraction upfront if any listed entry escapes via a `..` component or
    /// an absolute path rather than trusting the tool. A non-listable archive (`nil` entries) falls
    /// through to the tool's own guard.
    private static func rejectUnsafeEntries(_ entries: [String]?) throws {
        guard let entries, entries.contains(where: entryEscapesDestination) else { return }
        throw WilesError.localized(key: .archiveExtractionFailed, arguments: [])
    }

    private static func entryEscapesDestination(_ entry: String) -> Bool {
        let normalized = entry.replacingOccurrences(of: "\\", with: "/")
        if normalized.hasPrefix("/") {
            return true
        }
        return normalized.split(separator: "/", omittingEmptySubsequences: false).contains("..")
    }

    /// Checks whether any of the archive's top-level entry names already exists in
    /// `destinationFolder` — `nil` entries (listing unavailable) is treated as "no collision"
    /// (falls back to the prior flat-extraction behavior).
    private static func collidesWithExisting(entries: [String]?, in destinationFolder: URL) -> Bool {
        guard let entries else { return false }
        let topLevelEntryNames = Set(entries.compactMap { $0.split(separator: "/").first.map(String.init) })
        let existingNames = (try? FileManager.default.contentsOfDirectory(atPath: destinationFolder.path)) ?? []
        return !topLevelEntryNames.isDisjoint(with: existingNames)
    }
}
