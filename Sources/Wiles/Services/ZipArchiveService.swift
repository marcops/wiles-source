import Foundation

public final class ArchiveService: Sendable {
    public static func isArchive(url: URL) -> Bool {
        let ext = url.pathExtension.lowercased()
        let name = url.lastPathComponent.lowercased()
        return ext == "zip" || ext == "tar" || ext == "tgz" || name.hasSuffix(".tar.gz") || name.hasSuffix(".tar.bz2") || name.hasSuffix(".tar.xz")
    }
    
    public static func compressToZIP(urls: [URL], in destinationFolder: URL) throws {
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
        process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        var args = ["-c", "-k", "--sequesterRsrc"]
        args.append(contentsOf: urls.map { $0.path })
        args.append(destURL.path)
        process.arguments = args
        try process.run()
        process.waitUntilExit()
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
        try process.run()
        process.waitUntilExit()
    }
    
    public static func extractZIP(archiveURL: URL, to destinationFolder: URL) throws {
        try extractArchive(archiveURL: archiveURL, to: destinationFolder)
    }
}

public typealias ZipArchiveService = ArchiveService
