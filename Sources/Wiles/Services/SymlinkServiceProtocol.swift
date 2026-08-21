import Foundation

public protocol SymlinkServiceProtocol: Sendable {
    static func createSymlink(
        targetURL: URL,
        destinationFolder: URL,
        symlinkName: String,
        mode: SymlinkMode) throws -> URL
}
