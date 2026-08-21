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
            if let pwd = password, !pwd.isEmpty {
                args.append(contentsOf: ["-P", pwd])
            }
            args.append(contentsOf: [destURL.path, url.lastPathComponent])
            try runCompressionProcess(executable: "/usr/bin/zip", arguments: args, currentDirectoryURL: url.deletingLastPathComponent())
        }
    }

    private static func uniqueZipDestination(for urls: [URL], in destinationFolder: URL) -> URL {
        let baseName = urls.count == 1 ? urls[0].deletingPathExtension().lastPathComponent : "Archive"
        var destURL = destinationFolder.appendingPathComponent("\(baseName).zip")
        var counter = 2
        while FileManager.default.fileExists(atPath: destURL.path) {
            destURL = destinationFolder.appendingPathComponent("\(baseName) \(counter).zip")
            counter += 1
        }
        return destURL
    }

    private static func runCompressionProcess(executable: String, arguments: [String], currentDirectoryURL: URL? = nil) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.currentDirectoryURL = currentDirectoryURL
        try process.run()
        process.waitUntilExit()
        if process.terminationStatus != 0 {
            throw NSError(
                domain: "ArchiveService", code: Int(process.terminationStatus),
                userInfo: [NSLocalizedDescriptionKey: L10n.string(.archiveCompressionFailed, lang: .system)])
        }
    }

    public static func extractArchive(archiveURL: URL, to destinationFolder: URL) throws {
        let name = archiveURL.lastPathComponent.lowercased()
        let ext = archiveURL.pathExtension.lowercased()

        let process = Process()
        if ext == "zip" {
            process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
            process.arguments = ["-x", "-k", archiveURL.path, destinationFolder.path]
        } else if ext == "tar" || ext == "tgz" || isTarFamily(name: name) {
            process.executableURL = URL(fileURLWithPath: "/usr/bin/tar")
            process.arguments = ["-xf", archiveURL.path, "-C", destinationFolder.path]
        } else {
            process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
            process.arguments = ["-x", "-k", archiveURL.path, destinationFolder.path]
        }
        process.standardError = Pipe()
        try process.run()
        process.waitUntilExit()
        if process.terminationStatus != 0 {
            throw NSError(
                domain: "ArchiveService", code: Int(process.terminationStatus),
                userInfo: [NSLocalizedDescriptionKey: L10n.string(.archiveExtractionFailed, lang: .system)])
        }
    }

    public static func extractZIP(archiveURL: URL, to destinationFolder: URL) throws {
        try extractArchive(archiveURL: archiveURL, to: destinationFolder)
    }
}
