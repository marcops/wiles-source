import Foundation

@MainActor
public protocol CopyPathServiceProtocol: Sendable {
    static func copy(urls: [URL], variant: PathCopyVariant, relativeTo base: URL?)
}
