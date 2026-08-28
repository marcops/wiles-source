import AppKit
import Foundation
import GitBeacon

public enum FilePermissionsService: Sendable {
    public static func getPermissions(for url: URL) -> POSIXPermissions? {
        do {
            let attrs = try FileManager.default.attributesOfItem(atPath: url.path)
            guard let posix = attrs[.posixPermissions] as? NSNumber else { return nil }
            return POSIXPermissions(posixPermissions: posix.int16Value)
        } catch {
            // Every file has POSIX permissions, so a thrown error here is always a genuine I/O failure.
            ErrorReporter.report(error, context: "Reading POSIX permissions for \(url.path)")
            return nil
        }
    }

    public static func setPermissions(for url: URL, permissions: POSIXPermissions) throws {
        let attrs: [FileAttributeKey: Any] = [.posixPermissions: NSNumber(value: permissions.octalInt)]
        try FileManager.default.setAttributes(attrs, ofItemAtPath: url.path)
    }

    /// Applies `permissions` to `url` and every item nested inside it (Finder "apply to enclosed
    /// items" behavior). Continues past individual failures and returns them all rather than
    /// aborting partway, since a partially-applied recursive change is still useful to know about.
    /// `applied` is the count of items whose permissions were set successfully (for user feedback).
    public static func setPermissionsRecursively(
        for url: URL, permissions: POSIXPermissions) -> (applied: Int, errors: [any Error]) {
        var errors: [any Error] = []
        var applied = 0
        do {
            try setPermissions(for: url, permissions: permissions)
            applied += 1
        } catch {
            errors.append(error)
        }
        guard let enumerator = FileManager.default.enumerator(at: url, includingPropertiesForKeys: nil) else {
            return (applied, errors)
        }
        for case let childURL as URL in enumerator {
            // Deep trees can take seconds; stop as soon as the caller's task is cancelled
            // (e.g. the properties sheet was dismissed) instead of running on invisibly.
            if Task.isCancelled {
                break
            }
            do {
                try setPermissions(for: childURL, permissions: permissions)
                applied += 1
            } catch {
                errors.append(error)
            }
        }
        return (applied, errors)
    }
}
