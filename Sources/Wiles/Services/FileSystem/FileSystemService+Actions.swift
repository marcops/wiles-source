import Foundation
import AppKit

extension FileSystemService {
    @discardableResult
    public static func moveItem(at url: URL, toFolder targetFolder: URL) throws -> URL {
        let destURL = targetFolder.appendingPathComponent(url.lastPathComponent)
        if FileManager.default.fileExists(atPath: destURL.path) {
            try FileManager.default.removeItem(at: destURL)
        }
        try FileManager.default.moveItem(at: url, to: destURL)
        return destURL
    }

    @discardableResult
    public static func copyItem(at url: URL, toFolder targetFolder: URL) throws -> URL {
        let destURL = targetFolder.appendingPathComponent(url.lastPathComponent)
        try FileManager.default.copyItem(at: url, to: destURL)
        return destURL
    }

    @discardableResult
    public static func moveToTrash(url: URL) throws -> URL {
        var trashedURL: NSURL?
        try FileManager.default.trashItem(at: url, resultingItemURL: &trashedURL)
        return (trashedURL as URL?) ?? url
    }

    @discardableResult
    public static func renameItem(at url: URL, newName: String) throws -> URL {
        let destURL = url.deletingLastPathComponent().appendingPathComponent(newName)
        try FileManager.default.moveItem(at: url, to: destURL)
        return destURL
    }

    @discardableResult
    public static func createDirectory(at parentURL: URL, name: String) throws -> URL {
        let newURL = parentURL.appendingPathComponent(name)
        try FileManager.default.createDirectory(at: newURL, withIntermediateDirectories: false)
        return newURL
    }

    public static func writeToPasteboard(urls: [URL]) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.writeObjects(urls as [NSURL])
    }

    public static func readFromPasteboard() -> [URL]? {
        let pb = NSPasteboard.general
        return pb.readObjects(forClasses: [NSURL.self], options: nil) as? [URL]
    }

    public static func copyFileContentToClipboard(url: URL) {
        // Reading the file (up to 10MB) can stall for seconds on a slow or stalled
        // network/SMB mount. Perform the read off the main actor and round-trip only the
        // resulting string back, mirroring the /Volumes slow-mount pattern used by
        // AppState+Navigation.swift's navigateTo. The signature stays synchronous to satisfy
        // FileSystemServiceProtocol; the heavy work is dispatched internally instead.
        Task.detached(priority: .userInitiated) {
            guard let values = try? url.resourceValues(forKeys: [.fileSizeKey]),
                  let size = values.fileSize, size < 10_000_000,
                  let content = try? String(contentsOf: url) else {
                return
            }
            await MainActor.run {
                let pb = NSPasteboard.general
                pb.clearContents()
                pb.setString(content, forType: .string)
            }
        }
    }

    public static func compressToZIP(urls: [URL], in destinationFolder: URL) throws {
        try ZipArchiveService.compressToZIP(urls: urls, in: destinationFolder)
    }

    public static func extractZIP(archiveURL: URL, to destinationFolder: URL) throws {
        try ZipArchiveService.extractZIP(archiveURL: archiveURL, to: destinationFolder)
    }
}
