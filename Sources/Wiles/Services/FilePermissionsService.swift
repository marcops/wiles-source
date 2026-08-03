import Foundation
import AppKit

public struct POSIXPermissions: Sendable, Equatable {
    public var ownerRead: Bool
    public var ownerWrite: Bool
    public var ownerExecute: Bool
    
    public var groupRead: Bool
    public var groupWrite: Bool
    public var groupExecute: Bool
    
    public var othersRead: Bool
    public var othersWrite: Bool
    public var othersExecute: Bool
    
    public var octalString: String {
        let owner = (ownerRead ? 4 : 0) + (ownerWrite ? 2 : 0) + (ownerExecute ? 1 : 0)
        let group = (groupRead ? 4 : 0) + (groupWrite ? 2 : 0) + (groupExecute ? 1 : 0)
        let others = (othersRead ? 4 : 0) + (othersWrite ? 2 : 0) + (othersExecute ? 1 : 0)
        return String(format: "%04o", (owner << 6) | (group << 3) | others)
    }

    public init(posixPermissions: Int16) {
        let octal = Int(posixPermissions)
        self.ownerRead = (octal & 0o400) != 0
        self.ownerWrite = (octal & 0o200) != 0
        self.ownerExecute = (octal & 0o100) != 0
        
        self.groupRead = (octal & 0o040) != 0
        self.groupWrite = (octal & 0o020) != 0
        self.groupExecute = (octal & 0o010) != 0
        
        self.othersRead = (octal & 0o004) != 0
        self.othersWrite = (octal & 0o002) != 0
        self.othersExecute = (octal & 0o001) != 0
    }
    
    public var octalInt: Int16 {
        let owner = (ownerRead ? 4 : 0) + (ownerWrite ? 2 : 0) + (ownerExecute ? 1 : 0)
        let group = (groupRead ? 4 : 0) + (groupWrite ? 2 : 0) + (groupExecute ? 1 : 0)
        let others = (othersRead ? 4 : 0) + (othersWrite ? 2 : 0) + (othersExecute ? 1 : 0)
        return Int16((owner << 6) | (group << 3) | others)
    }
}

public protocol FilePermissionsServiceProtocol: Sendable {
    static func getPermissions(for url: URL) -> POSIXPermissions?
    static func setPermissions(for url: URL, permissions: POSIXPermissions) throws
}

public final class FilePermissionsService: FilePermissionsServiceProtocol, Sendable {
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
