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

    /// A `.replace` move that also reports where the displaced file landed in the Trash, so the
    /// caller can register a `.trash` undo step for it. `displacedTrashedURL` is `nil` when nothing
    /// was actually at the destination.
    @discardableResult
    static func moveItemReplacing(
        at url: URL, toFolder targetFolder: URL) async throws -> (destination: URL, displacedTrashedURL: URL?) {
        try await Task.detached(priority: .userInitiated) {
            let destURL = targetFolder.appendingPathComponent(url.lastPathComponent)
            guard url.standardizedFileURL != destURL.standardizedFileURL else {
                throw WilesError.itemAlreadyInDestination
            }
            var displaced: URL?
            if FileManager.default.fileExists(atPath: destURL.path) {
                var trashedURL: NSURL?
                try FileManager.default.trashItem(at: destURL, resultingItemURL: &trashedURL)
                displaced = trashedURL as URL?
            }
            try FileManager.default.moveItem(at: url, to: destURL)
            return (destURL, displaced)
        }.value
    }

    /// Symmetric with `moveItem`'s `onCollision`. Defaults to `.keepBoth` (the historical behavior:
    /// paste-a-copy never fails on a name clash, it finds a free name), but an interactive caller
    /// can pass `.replace` (existing → Trash first, never obliterated) or `.failIfExists`.
    @discardableResult
    static func copyItem(
        at url: URL,
        toFolder targetFolder: URL,
        onCollision: MoveCollisionPolicy = .keepBoth) async throws -> URL {
        try await Task.detached(priority: .userInitiated) {
            let namedDestURL = targetFolder.appendingPathComponent(url.lastPathComponent)
            switch onCollision {
            case .keepBoth:
                let destURL = uniqueDestination(for: url.lastPathComponent, in: targetFolder)
                try FileManager.default.copyItem(at: url, to: destURL)
                return destURL
            case .failIfExists:
                if FileManager.default.fileExists(atPath: namedDestURL.path) {
                    throw WilesError.destinationExists(name: url.lastPathComponent)
                }
                try FileManager.default.copyItem(at: url, to: namedDestURL)
                return namedDestURL
            case .replace:
                if FileManager.default.fileExists(atPath: namedDestURL.path) {
                    try FileManager.default.trashItem(at: namedDestURL, resultingItemURL: nil)
                }
                try FileManager.default.copyItem(at: url, to: namedDestURL)
                return namedDestURL
            }
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
            if let trashedURL = trashedURL as URL? {
                return trashedURL
            }
            // `trashItem` succeeded but didn't report where the item landed — reconstruct it from
            // the volume's Trash so callers never get the now-nonexistent source path back (a
            // `.trash` undo on `originalURL == trashedURL` would fail with `itemAlreadyInDestination`).
            let trashDirectory = try FileManager.default.url(
                for: .trashDirectory, in: .userDomainMask, appropriateFor: url, create: false)
            return try resolveTrashedItemURL(named: url.lastPathComponent, in: trashDirectory)
        }.value
    }

    /// The trashed item's real location: `trashDirectory/<name>` when it exists there, otherwise a
    /// thrown error — the item is safely in the Trash, we just can't point at it, which beats
    /// handing back a stale path a later undo/reveal would choke on.
    nonisolated static func resolveTrashedItemURL(named name: String, in trashDirectory: URL) throws -> URL {
        let expected = trashDirectory.appendingPathComponent(name)
        guard FileManager.default.fileExists(atPath: expected.path) else {
            throw WilesError.operationFailed(reason: name)
        }
        return expected
    }

    @discardableResult
    static func renameItem(at url: URL, newName: String, onCollision: MoveCollisionPolicy = .failIfExists) async throws -> URL {
        try await Task.detached(priority: .userInitiated) {
            try performRenameOnDisk(at: url, newName: newName, onCollision: onCollision)
        }.value
    }

    private nonisolated static func performRenameOnDisk(at url: URL, newName: String, onCollision: MoveCollisionPolicy) throws -> URL {
        let fm = FileManager.default
        let parent = url.deletingLastPathComponent()
        var destURL = parent.appendingPathComponent(newName)

        if url.standardizedFileURL == destURL.standardizedFileURL {
            return url
        }

        let caseOnlyChange = url.lastPathComponent.lowercased() == newName.lowercased()

        // A plain collision with a different item: resolve per `onCollision` instead of a raw
        // NSFileWriteFileExistsError.
        if fm.fileExists(atPath: destURL.path), !caseOnlyChange {
            switch onCollision {
            case .failIfExists:
                throw WilesError.destinationExists(name: newName)
            case .keepBoth:
                destURL = uniqueDestination(for: newName, in: parent)
            case .replace:
                try fm.trashItem(at: destURL, resultingItemURL: nil)
            }
        }

        if caseOnlyChange {
            // On a case-insensitive volume the destination path resolves to the source itself,
            // so a direct move can be rejected — rename via a temporary name.
            sweepStaleRenameTemps(in: parent)
            let tempURL = parent.appendingPathComponent("\(renameTempPrefix)\(UUID().uuidString)")
            try fm.moveItem(at: url, to: tempURL)
            do {
                try fm.moveItem(at: tempURL, to: destURL)
            } catch {
                do {
                    try fm.moveItem(at: tempURL, to: url)
                } catch let rollbackError {
                    // Rename failed AND we couldn't restore the original name — the file is stranded
                    // under the temp name. Report the exact path and name it in the thrown error.
                    ErrorReporter.report(rollbackError, context: "Rename rollback failed; \(url.lastPathComponent) is stranded at \(tempURL.path)")
                    throw WilesError.operationFailed(reason: "\(url.lastPathComponent) → \(tempURL.lastPathComponent)")
                }
                throw error
            }
            return destURL
        }

        try fm.moveItem(at: url, to: destURL)
        return destURL
    }

    /// Prefix for the throwaway name a case-only rename hops through (see `performRenameOnDisk`).
    static let renameTempPrefix = ".wiles-rename-"
    /// A live case-only rename holds its temp for milliseconds; anything older is a leftover from a
    /// run that crashed between the two moves.
    static let staleRenameTempMaxAge: TimeInterval = 60

    /// Removes rename temps left stranded in `directory` by a prior crashed case-only rename, so the
    /// dot-prefixed file can't linger forever with no cleanup path. Best-effort.
    nonisolated static func sweepStaleRenameTemps(
        in directory: URL, olderThan maxAge: TimeInterval = staleRenameTempMaxAge, fileManager fm: FileManager = .default) {
        guard let entries = try? fm.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: [.contentModificationDateKey], options: []) else { return }
        let now = Date()
        for entry in entries where entry.lastPathComponent.hasPrefix(renameTempPrefix) {
            let mtime = (try? entry.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
            guard let mtime, now.timeIntervalSince(mtime) > maxAge else { continue }
            do {
                try fm.removeItem(at: entry)
            } catch {
                ErrorReporter.report(error, context: "Sweeping stale rename temp \(entry.lastPathComponent)")
            }
        }
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
