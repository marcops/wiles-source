import Foundation
import AppKit

extension FileSystemService {
    public static func moveItem(at url: URL, toFolder targetFolder: URL) throws {
        let destURL = targetFolder.appendingPathComponent(url.lastPathComponent)
        if FileManager.default.fileExists(atPath: destURL.path) {
            try FileManager.default.removeItem(at: destURL)
        }
        try FileManager.default.moveItem(at: url, to: destURL)
    }
    
    public static func copyItem(at url: URL, toFolder targetFolder: URL) throws {
        let destURL = targetFolder.appendingPathComponent(url.lastPathComponent)
        try FileManager.default.copyItem(at: url, to: destURL)
    }
    
    public static func moveToTrash(url: URL) throws {
        try FileManager.default.trashItem(at: url, resultingItemURL: nil)
    }
    
    public static func renameItem(at url: URL, newName: String) throws -> URL {
        let destURL = url.deletingLastPathComponent().appendingPathComponent(newName)
        try FileManager.default.moveItem(at: url, to: destURL)
        return destURL
    }
    
    public static func createDirectory(at parentURL: URL, name: String) throws {
        let newURL = parentURL.appendingPathComponent(name)
        try FileManager.default.createDirectory(at: newURL, withIntermediateDirectories: false)
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
        guard let values = try? url.resourceValues(forKeys: [.fileSizeKey]),
              let size = values.fileSize, size < 10_000_000,
              let content = try? String(contentsOf: url) else {
            return
        }
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(content, forType: .string)
    }
    
    public static func compressToZIP(urls: [URL], in destinationFolder: URL) throws {
        try ZipArchiveService.compressToZIP(urls: urls, in: destinationFolder)
    }
    
    public static func extractZIP(archiveURL: URL, to destinationFolder: URL) throws {
        try ZipArchiveService.extractZIP(archiveURL: archiveURL, to: destinationFolder)
    }
}
