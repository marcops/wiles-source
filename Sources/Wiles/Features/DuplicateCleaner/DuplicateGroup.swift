import Foundation

public struct DuplicateGroup: Identifiable, Sendable {
    public var id: String {
        hash
    }

    public let hash: String
    public let fileSize: Int64
    public var items: [FileItem]

    public var reclaimableBytes: Int64 {
        guard items.count > 1 else { return 0 }
        return fileSize * Int64(items.count - 1)
    }
}
