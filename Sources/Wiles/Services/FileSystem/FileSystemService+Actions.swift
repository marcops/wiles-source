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

        // When the destination doesn't exist yet, there's nothing to replace — a plain move
        // is correct and matches prior behavior.
        guard FileManager.default.fileExists(atPath: destURL.path) else {
            try FileManager.default.moveItem(at: url, to: destURL)
            return destURL
        }

        // When the destination already exists, `replaceItemAt` performs an atomic overwrite-move:
        // the source only replaces the destination's contents once the operation is guaranteed to
        // succeed. Unlike remove-then-move, a failure here (permissions, disk full, source vanishing
        // mid-operation) can never leave the destination half-deleted with nothing to replace it.
        var resultingURL: NSURL?
        try FileManager.default.replaceItem(
            at: destURL,
            withItemAt: url,
            backupItemName: nil,
            options: [],
            resultingItemURL: &resultingURL
        )
        return (resultingURL as URL?) ?? destURL
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
    ///
    /// Internal (not `private`) so `PasteboardService.createFileFromPasteboardContent` can reuse
    /// the same free-name logic instead of duplicating it.
    static func uniqueDestination(for name: String, in folder: URL) -> URL {
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

    static func compressToZIP(urls: [URL], in destinationFolder: URL) throws {
        try ArchiveService.compressToZIP(urls: urls, in: destinationFolder)
    }

    static func extractZIP(archiveURL: URL, to destinationFolder: URL) throws {
        try ArchiveService.extractZIP(archiveURL: archiveURL, to: destinationFolder)
    }
}
