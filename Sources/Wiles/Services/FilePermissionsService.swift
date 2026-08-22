import AppKit
import Foundation

public enum FilePermissionsService: Sendable {
    public static func getPermissions(for url: URL) -> POSIXPermissions? {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
              let posix = attrs[.posixPermissions] as? NSNumber else { return nil }
        return POSIXPermissions(posixPermissions: posix.int16Value)
    }

    public static func setPermissions(for url: URL, permissions: POSIXPermissions) throws {
        let attrs: [FileAttributeKey: Any] = [.posixPermissions: NSNumber(value: permissions.octalInt)]
        try FileManager.default.setAttributes(attrs, ofItemAtPath: url.path)
    }
}
