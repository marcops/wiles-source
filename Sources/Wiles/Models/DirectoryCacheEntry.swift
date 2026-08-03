import Foundation

public final class DirectoryCacheEntry: NSObject {
    public let result: DirectoryLoadResult
    public let timestamp: Date

    public init(result: DirectoryLoadResult) {
        self.result = result
        self.timestamp = Date()
    }
}
