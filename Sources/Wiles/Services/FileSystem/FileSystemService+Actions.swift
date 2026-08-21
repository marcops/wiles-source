import AppKit
import Foundation
import GitBeacon

public extension FileSystemService {
    @discardableResult
    static func moveItem(at url: URL, toFolder targetFolder: URL) throws -> URL {
        let destURL = targetFolder.appendingPathComponent(url.lastPathComponent)

        // If the destination is the exact same path as the source (moving an item to the folder
        // it's already in), the "remove existing destination before moving" branch below would
        // delete destURL — which IS the source — before the subsequent moveItem() ever runs,
        // permanently destroying the item and leaving nothing for moveItem() to move. Must check
        // this before touching the filesystem at all, not after.
        guard url.standardizedFileURL != destURL.standardizedFileURL else {
            throw WilesError.itemAlreadyInDestination
        }

        if FileManager.default.fileExists(atPath: destURL.path) {
            try FileManager.default.removeItem(at: destURL)
        }
        try FileManager.default.moveItem(at: url, to: destURL)
        return destURL
    }

    @discardableResult
    static func copyItem(at url: URL, toFolder targetFolder: URL) throws -> URL {
        let destURL = uniqueDestination(for: url.lastPathComponent, in: targetFolder)
        try FileManager.default.copyItem(at: url, to: destURL)
        return destURL
    }

    /// Pasting a copy on top of a name that already exists in the destination should never fail
    /// with a "couldn't be copied" error — like Finder, it should just find a free name. Appends
    /// `_1`, `_2`, ... before the extension until the name is free.
    private static func uniqueDestination(for name: String, in folder: URL) -> URL {
        var destURL = folder.appendingPathComponent(name)
        guard FileManager.default.fileExists(atPath: destURL.path) else { return destURL }

        let ext = (name as NSString).pathExtension
        let base = (name as NSString).deletingPathExtension
        var counter = 1
        repeat {
            let candidateName = ext.isEmpty ? "\(base)_\(counter)" : "\(base)_\(counter).\(ext)"
            destURL = folder.appendingPathComponent(candidateName)
            counter += 1
        } while FileManager.default.fileExists(atPath: destURL.path)
        return destURL
    }

    @discardableResult
    static func moveToTrash(url: URL) throws -> URL {
        var trashedURL: NSURL?
        try FileManager.default.trashItem(at: url, resultingItemURL: &trashedURL)
        return (trashedURL as URL?) ?? url
    }

    @discardableResult
    static func renameItem(at url: URL, newName: String) throws -> URL {
        let destURL = url.deletingLastPathComponent().appendingPathComponent(newName)
        try FileManager.default.moveItem(at: url, to: destURL)
        return destURL
    }

    @discardableResult
    static func createDirectory(at parentURL: URL, name: String) throws -> URL {
        let newURL = parentURL.appendingPathComponent(name)
        try FileManager.default.createDirectory(at: newURL, withIntermediateDirectories: false)
        return newURL
    }

    /// Like `createDirectory`, but appends " 2", " 3", ... to `baseName` until it finds a free
    /// name — for the "New Folder" action, which creates immediately instead of prompting first.
    @discardableResult
    static func createUniqueDirectory(at parentURL: URL, baseName: String) throws -> URL {
        var candidate = parentURL.appendingPathComponent(baseName)
        var counter = 2
        while FileManager.default.fileExists(atPath: candidate.path) {
            candidate = parentURL.appendingPathComponent("\(baseName) \(counter)")
            counter += 1
        }
        try FileManager.default.createDirectory(at: candidate, withIntermediateDirectories: false)
        return candidate
    }

    static func writeToPasteboard(urls: [URL]) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.writeObjects(urls as [NSURL])
    }

    static func readFromPasteboard() -> [URL]? {
        let pb = NSPasteboard.general
        return pb.readObjects(forClasses: [NSURL.self], options: nil) as? [URL]
    }

    /// Pasting with nothing "file-shaped" on the pasteboard (no dragged/copied files) still does
    /// something useful, matching Finder's "New Item from Clipboard": a copied screenshot or image
    /// becomes a new `.png`, and copied text becomes a new `.txt`, right in the current folder.
    /// Checked in that order since some image sources also expose a redundant string
    /// representation on the same pasteboard. Returns `nil` only when there's genuinely nothing
    /// pasteable; a disk write failure once content was found instead throws, so the caller can
    /// surface it instead of it disappearing silently.
    @discardableResult
    static func createFileFromPasteboardContent(in folder: URL) throws -> URL? {
        let pb = NSPasteboard.general
        if let image = pb.readObjects(forClasses: [NSImage.self], options: nil)?.first as? NSImage,
           let pngData = pngData(for: image) {
            let destURL = uniqueDestination(for: "Pasted Image.png", in: folder)
            try pngData.write(to: destURL)
            return destURL
        }
        if let text = pb.string(forType: .string), !text.isEmpty {
            let destURL = uniqueDestination(for: "Pasted Text.txt", in: folder)
            try text.write(to: destURL, atomically: true, encoding: .utf8)
            return destURL
        }
        return nil
    }

    private static func pngData(for image: NSImage) -> Data? {
        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData) else { return nil }
        return bitmap.representation(using: .png, properties: [:])
    }

    static func copyFileContentToClipboard(url: URL) {
        // Reading the file (up to 10MB) can stall for seconds on a slow or stalled
        // network/SMB mount. Perform the read off the main actor and round-trip only the
        // resulting string back, mirroring the /Volumes slow-mount pattern used by
        // AppState+Navigation.swift's navigateTo. The signature stays synchronous to satisfy
        // FileSystemServiceProtocol; the heavy work is dispatched internally instead.
        Task.detached(priority: .userInitiated) {
            do {
                let values = try url.resourceValues(forKeys: [.fileSizeKey])
                guard let size = values.fileSize, size < 10_000_000 else { return }
                let content = try String(contentsOf: url)
                await copyToClipboard(content)
            } catch {
                ErrorReporter.report(error, context: "Copying file content to clipboard for \(url.path)")
            }
        }
    }

    private static func copyToClipboard(_ content: String) async {
        await MainActor.run {
            let pb = NSPasteboard.general
            pb.clearContents()
            pb.setString(content, forType: .string)
        }
    }

    static func compressToZIP(urls: [URL], in destinationFolder: URL) throws {
        try ArchiveService.compressToZIP(urls: urls, in: destinationFolder)
    }

    static func extractZIP(archiveURL: URL, to destinationFolder: URL) throws {
        try ArchiveService.extractZIP(archiveURL: archiveURL, to: destinationFolder)
    }
}
