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
            case .failIfExists, .replace:
                // `.replace` never reaches here in production — the interactive collision path calls
                // `moveItemReplacing`, which reports the displaced file's Trash URL so a `.trash`
                // undo can be recorded. Treating a stray `.replace` as fail keeps this path from
                // Trashing a file with no undo entry.
                throw WilesError.destinationExists(name: url.lastPathComponent)
            case .keepBoth:
                let freeURL = uniqueDestination(for: url.lastPathComponent, in: targetFolder)
                try FileManager.default.moveItem(at: url, to: freeURL)
                return freeURL
            }
        }.value
    }

    /// A `.replace` move that also reports where the displaced file landed in the Trash, so the
    /// caller can register a `.trash` undo step for it. `displacedTrashedURL` is `nil` when nothing
    /// was actually at the destination.
    ///
    /// Staged, not destroy-then-move: any existing file at the destination is first renamed aside to
    /// a hidden sibling; only after the incoming move actually succeeds is that staged file sent to
    /// the Trash. If the move fails, the staged file is restored to its original name and the error
    /// is rethrown — nothing ever reaches the Trash unless the constructive half happened (HM-110).
    @discardableResult
    static func moveItemReplacing(
        at url: URL, toFolder targetFolder: URL) async throws -> (destination: URL, displacedTrashedURL: URL?) {
        try await Task.detached(priority: .userInitiated) {
            try moveItemReplacingSync(at: url, toFolder: targetFolder)
        }.value
    }

    private nonisolated static func moveItemReplacingSync(
        at url: URL, toFolder targetFolder: URL) throws -> (destination: URL, displacedTrashedURL: URL?) {
        let fm = FileManager.default
        let destURL = targetFolder.appendingPathComponent(url.lastPathComponent)
        guard url.standardizedFileURL != destURL.standardizedFileURL else {
            throw WilesError.itemAlreadyInDestination
        }

        var stagedURL: URL?
        if fm.fileExists(atPath: destURL.path) {
            let staged = targetFolder.appendingPathComponent(".wiles-replace-\(UUID().uuidString)")
            try fm.moveItem(at: destURL, to: staged)
            stagedURL = staged
        }

        do {
            try fm.moveItem(at: url, to: destURL)
        } catch {
            if let stagedURL {
                try? fm.moveItem(at: stagedURL, to: destURL)
            }
            throw error
        }

        guard let stagedURL else { return (destURL, nil) }
        var trashedURL: NSURL?
        do {
            try fm.trashItem(at: stagedURL, resultingItemURL: &trashedURL)
        } catch {
            // Move already succeeded; the displaced file is safe under its hidden sibling name.
            // Report that as the recoverable location instead of failing the whole operation.
            return (destURL, stagedURL)
        }
        return (destURL, trashedURL as URL?)
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
            case .failIfExists, .replace:
                // `.replace` has no production caller here; fold it into fail so a stray one can't
                // Trash the existing file with no undo record (use `moveItemReplacing` for that).
                if FileManager.default.fileExists(atPath: namedDestURL.path) {
                    throw WilesError.destinationExists(name: url.lastPathComponent)
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
            return resolveTrashedItemURL(named: url.lastPathComponent, in: trashDirectory)
        }.value
    }

    /// The trashed item's real location. `trashItem` succeeded (this is only reached when it did),
    /// so the item IS in the Trash — the job here is only to point at it:
    /// - `trashDirectory/<name>` when it's there under its original name, else
    /// - the most-recently-added Trash entry whose name is `<stem>`/`<stem> …<ext>` — `trashItem`
    ///   renames on a name collision inside the Trash (`note 2.txt`, `note 10-30-45.txt`), else
    /// - `trashDirectory/<name>` as a last resort (a possibly-stale path still beats reporting a
    ///   false "couldn't move to Trash" failure and dropping the `.trash` undo — finding MM-150).
    nonisolated static func resolveTrashedItemURL(named name: String, in trashDirectory: URL) -> URL {
        let fm = FileManager.default
        let expected = trashDirectory.appendingPathComponent(name)
        if fm.fileExists(atPath: expected.path) {
            return expected
        }
        let stem = (name as NSString).deletingPathExtension
        let ext = (name as NSString).pathExtension
        let dateKeys: [URLResourceKey] = [.addedToDirectoryDateKey, .contentModificationDateKey]
        let entries = (try? fm.contentsOfDirectory(
            at: trashDirectory, includingPropertiesForKeys: dateKeys, options: [.skipsHiddenFiles])) ?? []
        let matches = entries.filter { entry in
            let entryName = entry.lastPathComponent
            guard (entryName as NSString).pathExtension == ext else { return false }
            let entryStem = (entryName as NSString).deletingPathExtension
            return entryStem == stem || entryStem.hasPrefix(stem + " ")
        }
        let newest = matches.max { lhs, rhs in
            trashEntryOrderingDate(lhs) < trashEntryOrderingDate(rhs)
        }
        return newest ?? expected
    }

    private nonisolated static func trashEntryOrderingDate(_ url: URL) -> Date {
        let values = try? url.resourceValues(forKeys: [.addedToDirectoryDateKey, .contentModificationDateKey])
        return values?.addedToDirectoryDate ?? values?.contentModificationDate ?? .distantPast
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
            case .failIfExists, .replace:
                // `.replace` has no production caller for rename; fold it into fail so a stray one
                // can't Trash the occupant with no undo record.
                throw WilesError.destinationExists(name: newName)
            case .keepBoth:
                destURL = uniqueDestination(for: newName, in: parent)
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
