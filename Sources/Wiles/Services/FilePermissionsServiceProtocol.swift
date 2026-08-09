import Foundation

public protocol FilePermissionsServiceProtocol: Sendable {
    static func getPermissions(for url: URL) -> POSIXPermissions?
    static func setPermissions(for url: URL, permissions: POSIXPermissions) throws
}
