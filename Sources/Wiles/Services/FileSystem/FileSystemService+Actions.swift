import Foundation
import GitBeacon

public extension FileSystemService {
    /// `onCollision` decides what happens when `targetFolder` already contains an item named the same
    /// as `url` — never a silent overwrite. Defaults to `.failIfExists` so a caller that doesn't
    /// think about collisions can't lose data; the interactive callers catch that and prompt the user.
    @discardableResult
    static func moveItem(
        at url: URL,
        toFolder targetFolder: URL,
        onCollision: MoveCollisionPolicy = .failIfExists) async throws -> URL {
        try await Task.detached(priority: .userInitiated) {
            let destURL = targetFolder.appendingPathComponent(url.lastPathComponent)

            // If the destination is the exact same path as the source (moving an item to the folder
            // it's already in), any "make room at the destination" branch below would act on the
            // source itself. Must check this before touching the filesystem at all, not after.
            guard url.standardizedFileURL != destURL.standardizedFileURL else {
                throw WilesError.itemAlreadyInDestination
            }

            // When the destination doesn't exist yet, there's nothing to resolve — a plain move.
            guard FileManager.default.fileExists(atPath: destURL.path) else {
                try FileManager.default.moveItem(at: url, to: destURL)
                return destURL
            }

            switch onCollision {
            case .failIfExists:
                throw WilesError.destinationExists(name: url.lastPathComponent)
            case .keepBoth:
                let freeURL = uniqueDestination(for: url.lastPathComponent, in: targetFolder)
                try FileManager.default.moveItem(at: url, to: freeURL)
                return freeURL
            case .replace:
                // Send the existing file to Trash (recoverable) before moving the source into place —
                // never obliterate it. If the move then fails, the source is still untouched and the
                // old file is in Trash, so nothing is destroyed.
                try FileManager.default.trashItem(at: destURL, resultingItemURL: nil)
                try FileManager.default.moveItem(at: url, to: destURL)
                return destURL
            }
        }.value
    }

    @discardableResult
    static func copyItem(at url: URL, toFolder targetFolder: URL) async throws -> URL {
        try await Task.detached(priority: .userInitiated) {
            let destURL = uniqueDestination(for: url.lastPathComponent, in: targetFolder)
            try FileManager.default.copyItem(at: url, to: destURL)
            return destURL
        }.value
    }

    /// Pasting a copy on top of a name that already exists in the destination should never fail
    /// with a "couldn't be copied" error — like Finder, it should just find a free name. Appends
    /// ` 2`, ` 3`, ... before the extension until the name is free (Finder's own convention, via
    /// the shared `UniqueFileNaming` utility).
    ///
    /// Internal (not `private`) so `PasteboardService.createFileFromPasteboardContent` can reuse
    /// the same free-name logic instead of duplicating it.
    static func uniqueDestination(for name: String, in folder: URL) -> URL {
        let candidateURL = folder.appendingPathComponent(name)
        return UniqueFileNaming.uniqueURL(for: candidateURL, in: folder, isDirectory: false)
    }

    @discardableResult
    static func moveToTrash(url: URL) async throws -> URL {
        try await Task.detached(priority: .userInitiated) {
            var trashedURL: NSURL?
            try FileManager.default.trashItem(at: url, resultingItemURL: &trashedURL)
            return (trashedURL as URL?) ?? url
        }.value
    }

    @discardableResult
    static func renameItem(at url: URL, newName: String) async throws -> URL {
        try await Task.detached(priority: .userInitiated) {
            let fm = FileManager.default
            let parent = url.deletingLastPathComponent()
            let destURL = parent.appendingPathComponent(newName)

            if url.standardizedFileURL == destURL.standardizedFileURL {
                return url
            }

            let caseOnlyChange = url.lastPathComponent.lowercased() == newName.lowercased()

            // A plain collision with a different item: surface the same explicit error the move flow
            // uses, not a raw NSFileWriteFileExistsError.
            if fm.fileExists(atPath: destURL.path), !caseOnlyChange {
                throw WilesError.destinationExists(name: newName)
            }

            if caseOnlyChange {
                // On a case-insensitive volume the destination path resolves to the source itself,
                // so a direct move can be rejected — rename via a temporary name.
                let tempURL = parent.appendingPathComponent(".wiles-rename-\(UUID().uuidString)")
                try fm.moveItem(at: url, to: tempURL)
                do {
                    try fm.moveItem(at: tempURL, to: destURL)
                } catch {
                    try? fm.moveItem(at: tempURL, to: url)
                    throw error
                }
                return destURL
            }

            try fm.moveItem(at: url, to: destURL)
            return destURL
        }.value
    }

    @discardableResult
    static func createDirectory(at parentURL: URL, name: String) async throws -> URL {
        try await Task.detached(priority: .userInitiated) {
            let newURL = parentURL.appendingPathComponent(name)
            try FileManager.default.createDirectory(at: newURL, withIntermediateDirectories: false)
            return newURL
        }.value
    }

    /// Like `createDirectory`, but appends " 2", " 3", ... to `baseName` until it finds a free
    /// name — for the "New Folder" action, which creates immediately instead of prompting first.
    @discardableResult
    static func createUniqueDirectory(at parentURL: URL, baseName: String) async throws -> URL {
        try await Task.detached(priority: .userInitiated) {
            let candidateURL = parentURL.appendingPathComponent(baseName)
            let uniqueURL = UniqueFileNaming.uniqueURL(for: candidateURL, in: parentURL, isDirectory: true)
            try FileManager.default.createDirectory(at: uniqueURL, withIntermediateDirectories: false)
            return uniqueURL
        }.value
    }
}
