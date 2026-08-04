import Foundation

public final class ArchiveService: Sendable {
    public static func isArchive(url: URL) -> Bool {
        let ext = url.pathExtension.lowercased()
        let name = url.lastPathComponent.lowercased()
        return ext == "zip" || ext == "tar" || ext == "tgz" || name.hasSuffix(".tar.gz") || name.hasSuffix(".tar.bz2") || name.hasSuffix(".tar.xz")
    }

    public static func compressToZIP(urls: [URL], in destinationFolder: URL, password: String? = nil) throws {
        guard !urls.isEmpty else { return }

        let zipName: String
        if urls.count == 1 {
            let baseName = urls[0].deletingPathExtension().lastPathComponent
            zipName = "\(baseName).zip"
        } else {
            zipName = "Archive.zip"
        }

        var destURL = destinationFolder.appendingPathComponent(zipName)
        var counter = 2
        while FileManager.default.fileExists(atPath: destURL.path) {
            let baseName = urls.count == 1 ? urls[0].deletingPathExtension().lastPathComponent : "Archive"
            destURL = destinationFolder.appendingPathComponent("\(baseName) \(counter).zip")
            counter += 1
        }

        let process = Process()
        if let pwd = password, !pwd.isEmpty {
            process.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
            process.currentDirectoryURL = destinationFolder
            var args = ["-r", "-P", pwd, destURL.path]
            args.append(contentsOf: urls.map { $0.lastPathComponent })
            process.arguments = args
        } else if urls.count == 1 {
            process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
            process.arguments = ["-c", "-k", "--sequesterRsrc", urls[0].path, destURL.path]
        } else {
            // `ditto -c` rejects multiple sources ("Can't archive multiple sources"),
            // so multi-file archives are built with `zip` instead.
            process.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
            process.currentDirectoryURL = destinationFolder
            var args = ["-r", destURL.path]
            args.append(contentsOf: urls.map { $0.lastPathComponent })
            process.arguments = args
        }
        try process.run()
        process.waitUntilExit()
        if process.terminationStatus != 0 {
            throw NSError(domain: "ArchiveService", code: Int(process.terminationStatus), userInfo: [NSLocalizedDescriptionKey: "Compression process failed."])
        }
    }

    public static func extractArchive(archiveURL: URL, to destinationFolder: URL) throws {
        let name = archiveURL.lastPathComponent.lowercased()
        let ext = archiveURL.pathExtension.lowercased()

        let process = Process()
        if ext == "zip" {
            process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
            process.arguments = ["-x", "-k", archiveURL.path, destinationFolder.path]
        } else if ext == "tar" || ext == "tgz" || name.hasSuffix(".tar.gz") || name.hasSuffix(".tar.bz2") || name.hasSuffix(".tar.xz") {
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
            throw NSError(domain: "ArchiveService", code: Int(process.terminationStatus), userInfo: [NSLocalizedDescriptionKey: "Extraction process failed."])
        }
    }

    public static func extractZIP(archiveURL: URL, to destinationFolder: URL) throws {
        try extractArchive(archiveURL: archiveURL, to: destinationFolder)
    }
}

public typealias ZipArchiveService = ArchiveService
