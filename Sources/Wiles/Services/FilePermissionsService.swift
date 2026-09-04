import AppKit
import Foundation
import GitBeacon

public enum FilePermissionsService: Sendable {
    /// Owner name, group name, and POSIX permissions for one item — any of them `nil` when the OS
    /// doesn't report it (or on a read failure).
    public struct FileOwnership: Sendable {
        public let owner: String?
        public let group: String?
        public let permissions: POSIXPermissions?
    }

    /// The single `attributesOfItem` read for owner, group, and POSIX permissions together — the
    /// one place these three are pulled (previously each of `FileItem`, `FileMetadataService`, and
    /// `getPermissions` did its own call). A genuine I/O failure is reported and everything is `nil`.
    public static func ownership(of url: URL) -> FileOwnership {
        do {
            let attrs = try FileManager.default.attributesOfItem(atPath: url.path)
            return FileOwnership(
                owner: attrs[.ownerAccountName] as? String,
                group: attrs[.groupOwnerAccountName] as? String,
                permissions: (attrs[.posixPermissions] as? NSNumber).map { POSIXPermissions(posixPermissions: $0.int16Value) })
        } catch {
            // Every file has POSIX permissions, so a thrown error here is always a genuine I/O failure.
            ErrorReporter.report(error, context: "Reading ownership/permissions for \(url.path)")
            return FileOwnership(owner: nil, group: nil, permissions: nil)
        }
    }

    public static func getPermissions(for url: URL) -> POSIXPermissions? {
        ownership(of: url).permissions
    }

    public static func setPermissions(for url: URL, permissions: POSIXPermissions) throws {
        let attrs: [FileAttributeKey: Any] = [.posixPermissions: NSNumber(value: permissions.octalInt)]
        try FileManager.default.setAttributes(attrs, ofItemAtPath: url.path)
    }

    /// Applies `permissions` to `url` and every item nested inside it (Finder "apply to enclosed
    /// items" behavior). Continues past individual failures and returns them all rather than
    /// aborting partway, since a partially-applied recursive change is still useful to know about.
    /// `applied` is the count of items whose permissions were set successfully (for user feedback).
    ///
    /// Directories get `permissions.directoryTraversable` instead of the raw value: applying e.g.
    /// `0o644` recursively would otherwise strip every subfolder's execute bit and lock the user
    /// out of their own tree.
    /// `async` and `nonisolated`, so a `@MainActor` caller can't block the UI on a deep tree even
    /// without its own `Task` wrapper — the body runs off the main actor.
    public static func setPermissionsRecursively(
        for url: URL, permissions: POSIXPermissions) async -> (applied: Int, errors: [any Error]) {
        var errors: [any Error] = []
        var applied = 0

        func apply(to itemURL: URL) {
            let isDir = (try? itemURL.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
            do {
                try setPermissions(for: itemURL, permissions: isDir ? permissions.directoryTraversable : permissions)
                applied += 1
            } catch {
                errors.append(error)
            }
        }

        apply(to: url)
        guard let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey],
            // Skip an unreadable subdirectory and keep applying to the rest — without this the walk
            // aborts at the first protected folder and silently leaves half the tree unchanged while
            // `applied` just looks partial. R1.
            errorHandler: { _, _ in true }) else {
            return (applied, errors)
        }
        // `while`/`nextObject()` rather than `for…in`: the enumerator's iterator is unavailable in
        // an async context. Deep trees can take seconds; stop as soon as the caller's task is
        // cancelled — and yield periodically so a cancellation from the sheet's `.onDisappear`
        // actually lands mid-walk instead of only being seen after it finishes.
        var processed = 0
        while let childURL = enumerator.nextObject() as? URL {
            if Task.isCancelled {
                break
            }
            apply(to: childURL)
            processed += 1
            if processed % 200 == 0 {
                await Task.yield()
            }
        }
        return (applied, errors)
    }
}
