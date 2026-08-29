import Foundation

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

        if password == nil, urls.count == 1 {
            try runCompressionProcess(
                executable: "/usr/bin/ditto",
                arguments: ["-c", "-k", "--sequesterRsrc", urls[0].path, destURL.path])
            return
        }

        // `ditto -c` rejects multiple sources ("Can't archive multiple sources"), and a
        // password-protected archive needs `zip` regardless of count, so both cases go through
        // `zip -r` here. Sources aren't guaranteed to share a parent directory (or live inside
        // destinationFolder at all), so each item gets its own `zip -r` invocation with
        // currentDirectoryURL set to *that item's own parent* and only its lastPathComponent as
        // the argument — zip appends to an existing archive by default, so repeated calls build up
        // the same destURL. This is what actually preserves each item's internal folder structure
        // (recursing relative to its own parent, not flattened via -j) while still finding sources
        // that live outside destinationFolder or outside each other.
        for url in urls {
            var args = ["-r"]
            var environment: [String: String]?
            if let pwd = password, !pwd.isEmpty {
                if pwd.contains(where: \.isWhitespace) {
                    // `zip`'s ZIP env var can't quote a space, so a password containing one still
                    // has to go through argv (visible in `ps` for this process's lifetime).
                    args.append(contentsOf: ["-P", pwd])
                } else {
                    // Passing the password via the ZIP env var (an Info-Zip-documented mechanism,
                    // not a custom hack) keeps it out of argv entirely — `ps`/Activity Monitor show
                    // only argv, not another process's environment, to unprivileged local users.
                    environment = ProcessInfo.processInfo.environment
                    environment?["ZIP"] = "-P \(pwd)"
                }
            }
            args.append(contentsOf: [destURL.path, url.lastPathComponent])
            try runCompressionProcess(
                executable: "/usr/bin/zip", arguments: args,
                currentDirectoryURL: url.deletingLastPathComponent(), environment: environment)
        }
    }

    private static func uniqueZipDestination(for urls: [URL], in destinationFolder: URL) -> URL {
        let baseName = urls.count == 1 ? urls[0].deletingPathExtension().lastPathComponent : "Archive"
        let candidateURL = destinationFolder.appendingPathComponent("\(baseName).zip")
        return UniqueFileNaming.uniqueURL(for: candidateURL, in: destinationFolder, isDirectory: false)
    }

    private struct ProcessRunResult {
        let terminationStatus: Int32
        let standardOutput: Data
    }

    /// Runs a subprocess to completion and returns its exit status (and stdout, when
    /// `captureStandardOutput` is set). Blocks on `waitUntilExit()` — every caller
    /// (`AppState+Archive`) already runs this inside `Task.detached`, so it must never be called
    /// directly on the main actor. Only `process.run()` throws here; a non-zero exit is returned,
    /// not thrown, so each caller maps it to its own localized error (or, for the listing probe,
    /// treats it as "no collision").
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
        // Drain stderr continuously — an unread pipe fills its kernel buffer once the subprocess
        // writes enough to it, and the subprocess then blocks forever on write, hanging waitUntilExit().
        errorPipe.fileHandleForReading.readabilityHandler = { handle in _ = handle.availableData }

        let outputPipe = captureStandardOutput ? Pipe() : nil
        process.standardOutput = outputPipe

        try process.run()
        // Read stdout to EOF *before* waitUntilExit to avoid the same pipe-buffer deadlock.
        let output = outputPipe?.fileHandleForReading.readDataToEndOfFile() ?? Data()
        process.waitUntilExit()
        errorPipe.fileHandleForReading.readabilityHandler = nil
        return ProcessRunResult(terminationStatus: process.terminationStatus, standardOutput: output)
    }

    private static func runCompressionProcess(
        executable: String, arguments: [String], currentDirectoryURL: URL? = nil, environment: [String: String]? = nil) throws {
        let result = try runProcess(
            executable: executable, arguments: arguments,
            currentDirectoryURL: currentDirectoryURL, environment: environment)
        if result.terminationStatus != 0 {
            throw WilesError.localized(key: .archiveCompressionFailed, arguments: [])
        }
    }

    /// Blocks on `waitUntilExit()`; same off-main-thread requirement as `runCompressionProcess`,
    /// and every caller (`AppState+Archive`) already honors it via `Task.detached`.
    public static func extractArchive(archiveURL: URL, to destinationFolder: URL) throws {
        let name = archiveURL.lastPathComponent.lowercased()
        let ext = archiveURL.pathExtension.lowercased()

        // Extracting flat risks silently overwriting same-named existing files. Only when a real
        // collision is detected upfront does extraction redirect into a fresh, uniquely-named
        // subfolder instead — the common no-collision case still extracts flat, unchanged.
        let extractionFolder = collidesWithExisting(archiveURL: archiveURL, ext: ext, name: name, in: destinationFolder)
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
            throw WilesError.localized(key: .archiveExtractionFailed, arguments: [])
        }
    }

    /// Lists the archive's top-level entry names and checks whether any already exist in
    /// `destinationFolder` — a listing failure is treated as "no collision" (falls back to the
    /// prior flat-extraction behavior) rather than blocking extraction over a diagnostic-only step.
    private static func collidesWithExisting(archiveURL: URL, ext: String, name: String, in destinationFolder: URL) -> Bool {
        let executable: String
        let arguments: [String]
        if ext == "zip" {
            executable = "/usr/bin/unzip"
            arguments = ["-Z1", archiveURL.path]
        } else if isTarArchive(ext: ext, name: name) {
            executable = "/usr/bin/tar"
            arguments = ["-tf", archiveURL.path]
        } else {
            return false
        }
        guard let result = try? runProcess(executable: executable, arguments: arguments, captureStandardOutput: true),
              result.terminationStatus == 0,
              let listing = String(data: result.standardOutput, encoding: .utf8) else { return false }

        let topLevelEntryNames = Set(listing.split(separator: "\n").compactMap { $0.split(separator: "/").first.map(String.init) })
        let existingNames = (try? FileManager.default.contentsOfDirectory(atPath: destinationFolder.path)) ?? []
        return !topLevelEntryNames.isDisjoint(with: existingNames)
    }
}
