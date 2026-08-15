import Foundation

public struct FileOperationTask: Identifiable, Sendable {
    public let id: UUID
    public let title: String
    public var progress: Double
    public var bytesTransferred: Int64
    public var totalBytes: Int64
    public var isCancelled: Bool

    public init(
        id: UUID = UUID(),
        title: String,
        progress: Double = 0.0,
        bytesTransferred: Int64 = 0,
        totalBytes: Int64 = 0,
        isCancelled: Bool = false) {
        self.id = id
        self.title = title
        self.progress = progress
        self.bytesTransferred = bytesTransferred
        self.totalBytes = totalBytes
        self.isCancelled = isCancelled
    }
}
