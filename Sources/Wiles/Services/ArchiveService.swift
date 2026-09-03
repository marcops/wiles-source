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

    /// Newline/NUL in a password would be silently truncated or mangled by Info-ZIP's `ZIP` env-var
    /// tokenizer, producing an archive whose real password differs from what the user typed — the
    /// user only finds out when they can't open it. Rejected up front here (the one service entry
    /// point) so every caller is covered, not just the compress sheet.
    private static let forbiddenPasswordCharacters = CharacterSet(charactersIn: "\n\r\u{0}")

    public static func passwordHasForbiddenCharacters(_ password: String) -> Bool {
        password.rangeOfCharacter(from: forbiddenPasswordCharacters) != nil
    }

    public static func compressToZIP(urls: [URL], in destinationFolder: URL, password: String? = nil) throws {
        guard !urls.isEmpty else { return }
        if let password, passwordHasForbiddenCharacters(password) {
            throw WilesError.localized(key: .archivePasswordInvalidCharacters, arguments: [])
        }
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
        var stagingDir: URL?
        defer {
            if let stagingDir {
                try? FileManager.default.removeItem(at: stagingDir)
            }
        }

        var nameCounts: [String: Int] = [:]
        for url in urls {
            let name = url.lastPathComponent
            let occurrence = (nameCounts[name] ?? 0) + 1
            nameCounts[name] = occurrence

            // Two sources with the same last path component would otherwise be added as the same
            // top-level zip entry — the second silently overwrites the first inside the archive.
            // Stage the later ones under a `" N"` name so the zip keeps every file.
            let source = occurrence == 1 ? url : try stageUnderUniqueName(url, occurrence: occurrence, stagingDir: &stagingDir)

            var args = ["-r"]
            var environment: [String: String]?
            if let pwd = password, !pwd.isEmpty {
                environment = zipPasswordEnvironment(pwd)
            }
            args.append(contentsOf: [destURL.path, source.lastPathComponent])
            try runCompressionProcess(
                executable: "/usr/bin/zip", arguments: args,
                currentDirectoryURL: source.deletingLastPathComponent(), environment: environment,
                failureContext: "zip -r of \(name) into \(destURL.lastPathComponent)")
        }
    }

    private static func stageUnderUniqueName(_ url: URL, occurrence: Int, stagingDir: inout URL?) throws -> URL {
        let dir: URL
        if let stagingDir {
            dir = stagingDir
        } else {
            dir = FileManager.default.temporaryDirectory.appendingPathComponent("wiles-zip-stage-\(UUID().uuidString)", isDirectory: true)
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            stagingDir = dir
        }
        let name = url.lastPathComponent
        let base = (name as NSString).deletingPathExtension
        let ext = (name as NSString).pathExtension
        let uniqueName = ext.isEmpty ? "\(base) \(occurrence)" : "\(base) \(occurrence).\(ext)"
        let staged = dir.appendingPathComponent(uniqueName)
        try FileManager.default.copyItem(at: url, to: staged)
        return staged
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
        /// `true` when stdout hit `maxCapturedStdoutBytes` and the subprocess was killed — the
        /// captured `standardOutput` is a prefix, not the full output.
        var stdoutTruncated = false
    }

    /// Cap on subprocess stdout captured into RAM. `listArchiveEntries` runs `unzip -Z1` / `tar -tf`
    /// as a pre-extraction safety probe for *every* archive opened, and a crafted archive can carry
    /// a central directory of millions of entries — reading stdout to EOF without a bound would pull
    /// all of that text into memory. Past the cap the read stops, the process is terminated, and
    /// the caller treats the archive as "not listable".
    private static let maxCapturedStdoutBytes = 8 * 1024 * 1024

    /// Accumulates subprocess stderr up to `capacity` bytes so a chatty tool can't grow it without
    /// bound; anything past the cap is dropped. Thread-safe — `readabilityHandler` fires on an
    /// arbitrary queue while the main flow reads `text` after the process exits.
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
    /// `captureStandardOutput` is set) and a bounded capture of stderr. Blocks until the subprocess exits —
    /// every caller (`AppState+Archive`) already runs this inside `Task.detached`, so it must never
    /// be called directly on the main actor. Only `process.run()` throws here; a non-zero exit is
    /// returned, not thrown, so each caller maps it to its own localized error (or, for the listing
    /// probe, treats it as "no collision").
    @discardableResult
    private nonisolated static func runProcess(
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
        // Read stdout *before* waitUntilExit to avoid the same pipe-buffer deadlock, bounded so a
        // huge listing can't OOM the app.
        let (output, truncated) = outputPipe.map {
            readStdout(from: $0.fileHandleForReading, cap: maxCapturedStdoutBytes, terminating: process)
        } ?? (Data(), false)
        // Poll instead of a bare `waitUntilExit()` so cancelling the operation (the ✕ in the
        // operations popover) actually SIGTERMs the `ditto`/`zip`/`tar` subprocess instead of
        // letting it run to completion for a bar that "won't cancel" (finding MM-104). This runs in
        // a `Task.detached`, so `Task.isCancelled` reflects the forwarded cancellation.
        while process.isRunning {
            if Task.isCancelled {
                process.terminate()
                break
            }
            Thread.sleep(forTimeInterval: cancellationPollInterval)
        }
        process.waitUntilExit()
        errorPipe.fileHandleForReading.readabilityHandler = nil
        if Task.isCancelled {
            throw CancellationError()
        }
        return ProcessRunResult(
            terminationStatus: process.terminationStatus, standardOutput: output,
            standardError: stderrBuffer.text, stdoutTruncated: truncated)
    }

    /// How often `runProcess` (and `waitForExitOrCancel`) checks for cancellation while a subprocess
    /// is running.
    static let cancellationPollInterval: TimeInterval = 0.1

    /// Blocks until `process` exits, but polls `Task.isCancelled` every `cancellationPollInterval`
    /// and `terminate()`s the subprocess + throws `CancellationError` when the calling task is
    /// cancelled. For subprocess waits that don't go through `runProcess` (e.g.
    /// `ArchiveInspectionService`'s single-entry `ditto`/`unzip` extraction) so closing the sheet
    /// actually stops the tool instead of letting it run to completion (MM-078). Must be called
    /// inside a `Task.detached` — same off-main requirement as `runProcess`.
    nonisolated static func waitForExitOrCancel(_ process: Process) throws {
        while process.isRunning {
            if Task.isCancelled {
                process.terminate()
                break
            }
            Thread.sleep(forTimeInterval: cancellationPollInterval)
        }
        process.waitUntilExit()
        try Task.checkCancellation()
    }

    /// Reads to EOF, or stops at `cap` bytes and kills the subprocess (then drains the pipe so the
    /// dying process doesn't block on a full buffer). Returns the bytes read and whether it capped.
    private static func readStdout(from handle: FileHandle, cap: Int, terminating process: Process) -> (Data, truncated: Bool) {
        var buffer = Data()
        while true {
            if Task.isCancelled {
                process.terminate()
                while !handle.readData(ofLength: 64 * 1024).isEmpty { }
                return (buffer, true)
            }
            let chunk = handle.readData(ofLength: 64 * 1024)
            if chunk.isEmpty {
                return (buffer, false)
            }
            buffer.append(chunk)
            if buffer.count >= cap {
                process.terminate()
                while !handle.readData(ofLength: 64 * 1024).isEmpty { }
                return (buffer, true)
            }
        }
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

        // Extracting flat risks silently overwriting same-named existing files. Extract flat ONLY
        // when the archive's contents were actually verified (`entries != nil`) AND that listing
        // showed no name collision at the destination. When the archive isn't listable here
        // (`entries == nil` — a non-.zip/.tar type routed to the `ditto` fallback, or a listing
        // probe that failed / was truncated) a collision can't be ruled out, so extraction goes
        // into a fresh uniquely-named subfolder rather than letting `ditto`/`tar` overwrite whatever
        // already exists at the destination (BA-279).
        let canExtractFlat = entries != nil && !collidesWithExisting(entries: entries, in: destinationFolder)
        let extractionFolder = canExtractFlat
            ? destinationFolder
            : UniqueFileNaming.uniqueURL(
                for: destinationFolder.appendingPathComponent(archiveURL.deletingPathExtension().lastPathComponent),
                in: destinationFolder, isDirectory: true)
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

        let result: ProcessRunResult
        do {
            result = try runProcess(executable: executable, arguments: arguments)
        } catch {
            // Cancelled (or `run()` failed) mid-extraction: drop the half-written unique subfolder
            // we just created — but never `destinationFolder` itself, which was already there and
            // may hold the user's other files (MM-104).
            if extractionFolder != destinationFolder {
                try? FileManager.default.removeItem(at: extractionFolder)
            }
            throw error
        }
        if result.terminationStatus != 0 {
            if extractionFolder != destinationFolder {
                try? FileManager.default.removeItem(at: extractionFolder)
            }
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
              !result.stdoutTruncated,
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

    /// `true` when an archive entry name would write outside the destination via a `..` component or
    /// an absolute path. `internal` (not `private`) so `ArchiveInspectionService.extractSingleEntry`
    /// runs the same check on the single entry it extracts (HH-234).
    static func entryEscapesDestination(_ entry: String) -> Bool {
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
        // Case-insensitive both ways (conservative): on a case-insensitive volume a zip's `Foo` vs an
        // on-disk `foo` IS a collision, and `ditto -x -k` would overwrite it with no Trash safety net.
        let topLevelEntryNames = Set(entries.compactMap { $0.split(separator: "/").first.map { String($0).lowercased() } })
        let existingNames = Set(((try? FileManager.default.contentsOfDirectory(atPath: destinationFolder.path)) ?? []).map { $0.lowercased() })
        return !topLevelEntryNames.isDisjoint(with: existingNames)
    }
}
