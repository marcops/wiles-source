import Foundation

public protocol ExifMetadataServiceProtocol: Sendable {
    static func extractExif(from url: URL) -> ExifMetadata?
}
