import Foundation

public final class DirectoryCacheEntry: NSObject {
    /// Any folder except the one currently under FSEvents monitoring can go stale without notice.
    private static let maxAge: TimeInterval = 30

    public let result: DirectoryLoadResult
    public let timestamp: Date

    public var isStale: Bool {
        Date().timeIntervalSince(timestamp) > Self.maxAge
    }

    public init(result: DirectoryLoadResult) {
        self.result = result
        timestamp = Date()
    }
}
