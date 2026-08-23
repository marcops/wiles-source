import Foundation

public struct DirectoryLoadResult: Sendable {
    public let items: [FileItem]

    public init(items: [FileItem]) {
        self.items = items
    }
}
